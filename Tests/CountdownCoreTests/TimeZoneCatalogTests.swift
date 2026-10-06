import Foundation
import Testing
@testable import CountdownCore

struct TimeZoneCatalogTests {
    private let winter = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 UTC
    private let summer = Date(timeIntervalSince1970: 1_782_864_000) // 2026-07-01 UTC
    private let locale = Locale(identifier: "en_US")
    private let pacificCities = ["America/Los_Angeles", "America/Vancouver", "America/Tijuana", "PST8PDT"]

    @Test func explicitAbbreviationsNeverReturnTheirOtherSeason() throws {
        for date in [winter, summer] {
            let options = TimeZoneCatalog.options(at: date, locale: locale)
            for (query, abbreviation, offset) in [("PST", "PST", -28_800), (" pdt ", "PDT", -25_200),
                                                  ("est", "EST", -18_000), ("EDT", "EDT", -14_400)] {
                let result = try #require(TimeZoneCatalog.search(query, in: options).only)
                #expect(result.abbreviation == abbreviation)
                #expect(result.secondsFromGMT == offset)
            }
        }
    }

    @Test func citySearchOffersBothSeasonsWithoutDuplicateCities() {
        let options = TimeZoneCatalog.options(at: summer, identifiers: pacificCities, locale: locale)
        #expect(options.count == 2)
        for city in ["Los Angeles", "Vancouver", "Tijuana", "America/Los_Angeles"] {
            let results = TimeZoneCatalog.search(city, in: options)
            #expect(Set(results.map(\.abbreviation)) == ["PST", "PDT"])
        }
        #expect(TimeZoneCatalog.search("Pacific Standard Time", in: options).map(\.abbreviation) == ["PST"])
        #expect(TimeZoneCatalog.search("Pacific Daylight Time", in: options).map(\.abbreviation) == ["PDT"])
        #expect(options.allSatisfy { $0.identifiers.contains("America/Los_Angeles") && $0.identifiers.contains("America/Vancouver") })
        #expect(options.allSatisfy { $0.citySummary(matching: "Vancouver", limit: 1).hasPrefix("Vancouver +") })
    }

    @Test func choosingPSTUsesEightHoursInSummerAndWinter() throws {
        let options = TimeZoneCatalog.options(at: summer, identifiers: pacificCities, locale: locale)
        let pst = try #require(TimeZoneCatalog.search("PST", in: options).only)
        let pdt = try #require(TimeZoneCatalog.search("PDT", in: options).only)
        let pstZone = try #require(pst.selection.timeZone)
        let pdtZone = try #require(pdt.selection.timeZone)
        for date in [winter, summer] {
            #expect(pstZone.secondsFromGMT(for: date) == -28_800)
            #expect(pdtZone.secondsFromGMT(for: date) == -25_200)
            let utc = try #require(TimeZone(secondsFromGMT: 0))
            let standardDue = try #require(EventTime.changingTimeZone(of: date, from: utc, to: pstZone))
            let daylightDue = try #require(EventTime.changingTimeZone(of: date, from: utc, to: pdtZone))
            #expect(standardDue.timeIntervalSince(daylightDue) == 3_600)
        }
        #expect(pst.selection.name == "PST")
        #expect(pst.selection.offsetLabel(at: summer) == "UTC-08:00 · Fixed offset")
    }

    @Test func fixedChoiceAndLabelSurviveSavingAndReopening() throws {
        let options = TimeZoneCatalog.options(at: summer, identifiers: pacificCities, locale: locale)
        let selected = try #require(TimeZoneCatalog.search("PST", in: options).only).selection
        let event = CountdownEvent(title: "Summer deadline in PST", date: summer,
                                   timeZoneIdentifier: selected.identifier, timeZoneAbbreviation: selected.abbreviation)
        let saved = try JSONEncoder().encode(SavedCountdowns(events: [event]))
        let restored = try #require(JSONDecoder().decode(SavedCountdowns.self, from: saved).events.first)
        #expect(restored == event)
        #expect(restored.dateLabel().hasSuffix(" · PST"))
        #expect(restored.timeZone.secondsFromGMT(for: summer) == -28_800)
        #expect(restored.eventCalendar().timeZone.secondsFromGMT(for: summer) == -28_800)
        let reopened = TimeZoneSelection(identifier: restored.timeZone.identifier, abbreviation: restored.timeZoneAbbreviation)
        #expect(reopened == selected)
        #expect(try #require(TimeZoneCatalog.search("PST", in: options).only).isSelected(reopened, at: summer))
    }

    @Test func existingCityEventsKeepTheirSeasonalRules() throws {
        let event = CountdownEvent(title: "Existing", date: summer, timeZoneIdentifier: "America/Los_Angeles")
        let data = try JSONEncoder().encode(event) // No new abbreviation field in legacy city records.
        let restored = try JSONDecoder().decode(CountdownEvent.self, from: data)
        #expect(restored.timeZoneAbbreviation == nil)
        #expect(restored.date == summer)
        #expect(restored.timeZone.secondsFromGMT(for: winter) == -28_800)
        #expect(restored.timeZone.secondsFromGMT(for: summer) == -25_200)
        let options = TimeZoneCatalog.options(at: summer, identifiers: pacificCities, locale: locale)
        let selection = TimeZoneSelection(identifier: "America/Los_Angeles")
        #expect(options.filter { $0.isSelected(selection, at: summer) }.map(\.abbreviation) == ["PDT"])
    }

    @Test func citiesWithoutDaylightSavingDoNotGainDaylightOptions() {
        let options = TimeZoneCatalog.options(at: summer,
                                             identifiers: ["America/Phoenix", "America/Denver"], locale: locale)
        #expect(TimeZoneCatalog.search("Phoenix", in: options).map(\.abbreviation) == ["MST"])
        #expect(Set(TimeZoneCatalog.search("Denver", in: options).map(\.abbreviation)) == ["MST", "MDT"])
    }

    @Test func offsetAndPartialCitySearchRemainAvailable() throws {
        let options = TimeZoneCatalog.options(at: summer,
                                             identifiers: ["America/New_York", "Australia/Perth", "Asia/Kolkata"], locale: locale)
        #expect(TimeZoneCatalog.search("EST", in: options).count == 1)
        #expect(TimeZoneCatalog.search("UTC+5:30", in: options).first?.secondsFromGMT == 19_800)
        #expect(TimeZoneCatalog.search("UTC+05:30", in: options).first?.secondsFromGMT == 19_800)
        #expect(TimeZoneCatalog.search("UTC−04:00", in: options).first?.abbreviation == "EDT")
        #expect(Set(TimeZoneCatalog.search("new y", in: options).map(\.abbreviation)) == ["EST", "EDT"])
        #expect(TimeZoneCatalog.search("not a time zone", in: options).isEmpty)
    }

    @Test func savedFixedChoiceRemainsAvailableWithoutItsCities() throws {
        let saved = TimeZoneSelection(identifier: "GMT-0800", abbreviation: "PST")
        let options = TimeZoneCatalog.options(at: summer, including: saved, identifiers: ["UTC"], locale: locale)
        let pst = try #require(TimeZoneCatalog.search("PST", in: options).only)
        #expect(pst.selection == saved)
    }
}

private extension Array {
    var only: Element? { count == 1 ? self[0] : nil }
}
