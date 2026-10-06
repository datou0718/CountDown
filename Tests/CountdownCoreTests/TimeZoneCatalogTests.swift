import Foundation
import Testing
@testable import CountdownCore

struct TimeZoneCatalogTests {
    private let winter = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 UTC
    private let summer = Date(timeIntervalSince1970: 1_782_864_000) // 2026-07-01 UTC
    private let locale = Locale(identifier: "en_US")

    @Test func easternCitiesAndAbbreviationsFindOneEntryInEitherSeason() throws {
        let cities = ["America/New_York", "America/Toronto", "America/Detroit", "America/Indiana/Indianapolis"]
        for date in [winter, summer] {
            let groups = TimeZoneCatalog.groups(at: date, identifiers: cities, locale: locale)
            #expect(groups.count == 1)
            let eastern = try #require(groups.first)
            #expect(eastern.name == "Eastern Time")
            for query in ["Eastern", "Eastern Standard Time", "Eastern Daylight Time", "EST", "EDT",
                          "New York", "Toronto", "Detroit", "Indianapolis", "america/new_york", "  new y  "] {
                #expect(groups.filter { $0.matches(query) }.count == 1)
            }
        }
    }

    @Test func citySearchRetainsThatCityAndNamedSelectionPreservesExistingCity() throws {
        let groups = TimeZoneCatalog.groups(at: summer,
                                           identifiers: ["America/Detroit", "America/New_York", "America/Toronto"], locale: locale)
        let eastern = try #require(groups.first)
        #expect(eastern.identifier(preferred: "America/New_York", matching: "Toronto") == "America/Toronto")
        #expect(eastern.identifier(preferred: "America/New_York", matching: "EDT") == "America/New_York")
        #expect(eastern.identifier(preferred: "America/New_York", matching: "America") == "America/New_York")
        #expect(eastern.citySummary(matching: "Toronto", limit: 1) == "Toronto +2")
        #expect(eastern.identifier(preferred: "Asia/Taipei", matching: "Detroit") == "America/Detroit")
    }

    @Test func equalWinterOffsetsWithDifferentDaylightRulesRemainSeparate() throws {
        let identifiers = ["America/Denver", "America/Phoenix", "America/Chicago", "America/Mexico_City"]
        let groups = TimeZoneCatalog.groups(at: winter, identifiers: identifiers, locale: locale)
        #expect(groups.count == 4)
        #expect(groups.filter { $0.matches("CDT") }.count == 1)
        #expect(groups.filter { $0.matches("CDT") }.first?.contains("America/Chicago") == true)
        #expect(groups.filter { $0.matches("MDT") }.first?.contains("America/Denver") == true)
    }

    @Test func abbreviationsDoNotMatchUnrelatedWordsAndOffsetsSupportFractionalHours() {
        let groups = TimeZoneCatalog.groups(at: summer,
                                           identifiers: ["America/New_York", "Australia/Perth", "Asia/Kolkata"], locale: locale)
        #expect(groups.filter { $0.matches("EST") }.count == 1)
        #expect(groups.filter { $0.matches("UTC+5:30") }.first?.contains("Asia/Kolkata") == true)
        #expect(groups.filter { $0.matches("UTC+05:30") }.first?.contains("Asia/Kolkata") == true)
        #expect(groups.filter { $0.matches("UTC−04:00") }.first?.contains("America/New_York") == true)
        #expect(groups.filter { $0.matches("not a time zone") }.isEmpty)
    }

    @Test func everyCityMapsToOneGroupAndSavedAliasesRemainAvailable() throws {
        let identifiers = ["America/New_York", "America/Toronto", "Asia/Taipei", "Asia/Shanghai", "Europe/London"]
        let groups = TimeZoneCatalog.groups(at: summer, including: "US/Eastern", identifiers: identifiers, locale: locale)
        for identifier in identifiers + ["US/Eastern"] {
            let group = try #require(groups.only { $0.contains(identifier) })
            #expect(group.matches(identifier))
            #expect(group.identifier(preferred: identifier) == identifier)
        }
        let eastern = try #require(groups.first { $0.contains("US/Eastern") })
        #expect(eastern.contains("America/New_York"))
    }
}

private extension Array {
    func only(where predicate: (Element) -> Bool) -> Element? {
        let matches = filter(predicate)
        return matches.count == 1 ? matches[0] : nil
    }
}
