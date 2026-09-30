// Compile alongside the widget and core sources with -D WIDGET_PREVIEW.
import AppKit
import SwiftUI
import WidgetKit

@main
struct PreviewWidgets {
    @MainActor static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sample = CountdownProvider().sample()
        for (name, family, width) in [("small", WidgetFamily.systemSmall, 164.0), ("medium", .systemMedium, 344.0)] {
            let view = CountdownWidgetView(entry: sample, family: family)
                .environment(\.colorScheme, .light)
                .padding(16)
                .frame(width: width, height: 164)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
            let bitmap = NSBitmapImageRep(cgImage: image)
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
}
