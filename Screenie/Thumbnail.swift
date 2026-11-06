import AppKit
import ImageIO

/// Downsampled screenshot thumbnails (plan section 6).
enum Thumbnail {
    /// Point size of the longest edge of a thumbnail in the popover.
    static let pointSize: CGFloat = 160

    /// Decodes a thumbnail whose longest edge is at most `pointSize × scale` pixels, honoring EXIF
    /// orientation. ImageIO downsamples while decoding, so the full-resolution bitmap is never
    /// materialized. Blocking; call off the main thread. Returns nil for unreadable/non-image files.
    static func make(url: URL, pointSize: CGFloat = pointSize, scale: CGFloat) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let maxPixelSize = Int((pointSize * scale).rounded(.up))
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let size = NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
        return NSImage(cgImage: cgImage, size: size)
    }
}

/// In-memory thumbnail cache keyed by file URL, bounded by decoded bitmap bytes. Thread-safe.
final class ThumbnailCache: @unchecked Sendable {
    private let cache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.totalCostLimit = 20 * 1024 * 1024
        return cache
    }()

    /// Decodes one thumbnail at a time: bounds peak memory and keeps blocking I/O off the
    /// Swift concurrency pool.
    private let queue = DispatchQueue(label: "Screenie.thumbnails", qos: .utility)

    /// Cached thumbnail, or generates and caches one in the background. Returns nil for
    /// files that can't be decoded as images.
    func thumbnail(for url: URL, scale: CGFloat) async -> NSImage? {
        if let cached = image(for: url) { return cached }
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                // A request queued earlier for the same URL may have filled the cache.
                if let cached = image(for: url) { return continuation.resume(returning: cached) }
                let image = Thumbnail.make(url: url, scale: scale)
                if let image { insert(image, for: url) }
                continuation.resume(returning: image)
            }
        }
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL, cost: Self.cost(of: image))
    }

    /// Drops `url`'s thumbnail. Runs on the decode queue, so a decode already queued or in flight
    /// for `url` can't re-insert it afterwards.
    func remove(_ url: URL) {
        queue.async { [cache] in cache.removeObject(forKey: url as NSURL) }
    }

    /// Approximate decoded size: 4 bytes per pixel.
    private static func cost(of image: NSImage) -> Int {
        image.representations.reduce(0) { $0 + $1.pixelsWide * $1.pixelsHigh * 4 }
    }
}
