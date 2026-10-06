import CountdownCore
import SwiftUI

struct TimeZonePicker: View {
    @Binding var selection: TimeZoneSelection
    let date: Date
    @State private var isPresented = false
    @State private var search = ""
    @State private var options: [TimeZoneOption] = []

    private var results: [TimeZoneOption] {
        TimeZoneCatalog.search(search, in: options).sorted { lhs, rhs in
            if lhs.isSelected(selection, at: date) != rhs.isSelected(selection, at: date) { return lhs.isSelected(selection, at: date) }
            return lhs.name == rhs.name ? lhs.id < rhs.id : lhs.name < rhs.name
        }
    }

    var body: some View {
        Button {
            options = TimeZoneCatalog.options(at: date, including: selection,
                                             identifiers: TimeZone.knownTimeZoneIdentifiers + ["UTC"])
            search = ""
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                VStack(alignment: .leading, spacing: 2) {
                    Text(selection.name).lineLimit(1)
                    Text(selection.offsetLabel(at: date)).font(.system(size: 10)).foregroundStyle(AppTheme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }.font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered).controlSize(.large)
        .accessibilityLabel("Time zone").accessibilityValue("\(selection.name), \(selection.offsetLabel(at: date))")
        .popover(isPresented: $isPresented) {
            VStack(spacing: 10) {
                TextField("Search city or time zone", text: $search)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Search time zones")
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(results) { option in
                            Button {
                                selection = option.selection
                                isPresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(option.name)
                                        Text("\(option.abbreviation) · \(option.offsetLabel)")
                                            .font(.caption).foregroundStyle(AppTheme.secondary)
                                        Text(option.citySummary(matching: search))
                                            .font(.caption).foregroundStyle(AppTheme.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                    if option.isSelected(selection, at: date) { Image(systemName: "checkmark") }
                                }.font(.system(size: 12)).padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("\(option.name), \(option.abbreviation)")
                                .accessibilityValue("\(option.offsetLabel), \(option.citySummary(matching: search))")
                                .help("Uses \(option.offsetLabel) year round. \(option.identifiers.joined(separator: ", "))")
                        }
                        if results.isEmpty { Text("No matching time zones.").font(.caption).padding() }
                    }
                }
            }.padding(12).frame(width: 300, height: 300)
                .foregroundStyle(AppTheme.navy).background(.white).environment(\.colorScheme, .light)
        }
    }
}
