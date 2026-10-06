import CountdownCore
import SwiftUI

struct TimeZonePicker: View {
    @Binding var selection: String
    let date: Date
    @State private var isPresented = false
    @State private var search = ""
    @State private var groups: [TimeZoneGroup] = []

    private var results: [TimeZoneGroup] {
        groups.filter { $0.matches(search) }.sorted { lhs, rhs in
            if lhs.contains(selection) != rhs.contains(selection) { return lhs.contains(selection) }
            return lhs.name == rhs.name ? lhs.id < rhs.id : lhs.name < rhs.name
        }
    }

    private var selectedName: String {
        TimeZone(identifier: selection)?.localizedName(for: .generic, locale: .current) ?? selection
    }

    var body: some View {
        Button {
            groups = TimeZoneCatalog.groups(at: date, including: selection,
                                            identifiers: TimeZone.knownTimeZoneIdentifiers + ["UTC"])
            search = ""
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedName).lineLimit(1)
                    Text(TimeZoneCatalog.offsetLabel(for: selection, at: date)).font(.system(size: 10)).foregroundStyle(AppTheme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }.font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered).controlSize(.large)
        .accessibilityLabel("Time zone").accessibilityValue("\(selectedName), \(selection)")
        .popover(isPresented: $isPresented) {
            VStack(spacing: 10) {
                TextField("Search city or time zone", text: $search)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Search time zones")
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(results) { group in
                            Button {
                                selection = group.identifier(preferred: selection, matching: search)
                                isPresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(group.name)
                                        Text(TimeZoneCatalog.offsetLabel(for: group.identifier(preferred: selection, matching: search), at: date))
                                            .font(.caption).foregroundStyle(AppTheme.secondary)
                                        Text(group.citySummary(matching: search))
                                            .font(.caption).foregroundStyle(AppTheme.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                    if group.contains(selection) { Image(systemName: "checkmark") }
                                }.font(.system(size: 12)).padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(group.name)
                                .accessibilityValue(group.citySummary(matching: search))
                                .help(group.identifiers.joined(separator: ", "))
                        }
                        if results.isEmpty { Text("No matching time zones.").font(.caption).padding() }
                    }
                }
            }.padding(12).frame(width: 300, height: 300)
                .foregroundStyle(AppTheme.navy).background(.white).environment(\.colorScheme, .light)
        }
    }
}
