import SwiftUI

/// Reusable BrightPass logo view that loads the bundled `brightpass.png`.
/// Default height is 40pt with proportional width, matching the standard brand rendering.
@available(macOS 14.0, iOS 17.0, *)
public struct BrightPassLogo: View {
    let height: CGFloat

    public init(height: CGFloat = 40) {
        self.height = height
    }

    public var body: some View {
        if let image = loadImage() {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
                .accessibilityLabel("BrightPass logo")
        } else {
            // Fallback when resource isn't available (e.g. previews, tests)
            Text("BrightPass")
                .font(.largeTitle.bold())
                .accessibilityLabel("BrightPass logo")
        }
    }

    #if os(macOS)
    private func loadImage() -> CGImage? {
        guard let url = Bundle.module.url(forResource: "brightpass", withExtension: "png"),
              let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
    }
    #else
    private func loadImage() -> CGImage? {
        guard let url = Bundle.module.url(forResource: "brightpass", withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            return nil
        }
        return cgImage
    }
    #endif
}

/// Reusable app icon view that loads the bundled `AppIcon.png`.
@available(macOS 14.0, iOS 17.0, *)
public struct BrightPassAppIcon: View {
    let size: CGFloat

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        if let image = loadImage() {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
                .accessibilityHidden(true)
        }
    }

    #if os(macOS)
    private func loadImage() -> CGImage? {
        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
              let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
    }
    #else
    private func loadImage() -> CGImage? {
        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            return nil
        }
        return cgImage
    }
    #endif
}
