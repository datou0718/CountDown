import SwiftUI

struct TimeZonePicker: View {
    @Binding var selection: String
    let date: Date
    @State private var isPresented = false
    @State private var search = ""

    private var identifiers: [String] {
        let zones = Set(TimeZone.knownTimeZoneIdentifiers + [selection, "UTC"])
        return zones.filter {
            search.isEmpty || $0.replacingOccurrences(of: "_", with: " ").localizedCaseInsensitiveContains(search)
                || (TimeZone(identifier: $0)?.abbreviation(for: date)?.localizedCaseInsensitiveContains(search) ?? false)
        }.sorted { lhs, rhs in
            if lhs == rhs { return false }
            if lhs == selection { return true }
            if rhs == selection { return false }
            return lhs < rhs
        }
    }

    var body: some View {
        Button {
            search = ""
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                VStack(alignment: .leading, spacing: 2) {
                    Text(selection.replacingOccurrences(of: "_", with: " ")).lineLimit(1)
                    Text(offsetLabel(selection)).font(.system(size: 10)).foregroundStyle(AppTheme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }.font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered).controlSize(.large)
        .accessibilityLabel("Time zone").accessibilityValue(selection)
        .popover(isPresented: $isPresented) {
            VStack(spacing: 10) {
                TextField("Search city or time zone", text: $search)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Search time zones")
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(identifiers, id: \.self) { identifier in
                            Button {
                                selection = identifier
                                isPresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(identifier.replacingOccurrences(of: "_", with: " "))
                                        Text(offsetLabel(identifier)).font(.caption).foregroundStyle(AppTheme.secondary)
                                    }
                                    Spacer()
                                    if identifier == selection { Image(systemName: "checkmark") }
                                }.font(.system(size: 12)).padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(identifier)
                        }
                        if identifiers.isEmpty { Text("No matching time zones.").font(.caption).padding() }
                    }
                }
            }.padding(12).frame(width: 300, height: 300)
                .foregroundStyle(AppTheme.navy).background(.white).environment(\.colorScheme, .light)
        }
    }

    private func offsetLabel(_ identifier: String) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return identifier }
        let seconds = zone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "−" : "+"
        let offset = String(format: "UTC%@%02d:%02d", sign, abs(seconds) / 3_600, abs(seconds) % 3_600 / 60)
        return "\(zone.abbreviation(for: date) ?? identifier) · \(offset)"
    }
}
