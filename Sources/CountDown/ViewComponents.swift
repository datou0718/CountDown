import SwiftUI

enum AppTheme {
    // Duke Navy Blue: https://brand.duke.edu/colors/
    static let navy = Color(red: 1 / 255, green: 33 / 255, blue: 105 / 255)
    static let secondary = Color(red: 0.31, green: 0.37, blue: 0.47)
    static let background = Color.white
    static let card = Color(red: 0.97, green: 0.98, blue: 0.995)
}

struct PageHeader: View {
    let title: String
    var back: () -> Void
    var body: some View {
        HStack {
            Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)).frame(width: 28, height: 28) }
                .buttonStyle(.plain).accessibilityLabel("Back to countdowns")
            Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
            Spacer()
        }.padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(.white).background(AppTheme.navy)
    }
}
