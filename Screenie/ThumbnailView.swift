import SwiftUI

/// A screenshot thumbnail that fits its frame. Shows a placeholder while the thumbnail is
/// generated in the background, and a generic icon if the file can't be decoded.
struct ThumbnailView: View {
    let url: URL
    let cache: ThumbnailCache

    @Environment(\.displayScale) private var scale
    @State private var image: NSImage?
    @State private var failed = false

    init(url: URL, cache: ThumbnailCache) {
        self.url = url
        self.cache = cache
        // Cache hit: render immediately, no placeholder flash.
        _image = State(initialValue: cache.image(for: url))
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .overlay {
                        if failed {
                            Image(systemName: "photo").foregroundStyle(.secondary)
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
            }
        }
        .task(id: url) {
            let loaded = await cache.thumbnail(for: url, scale: scale)
            image = loaded
            failed = loaded == nil
        }
    }
}
