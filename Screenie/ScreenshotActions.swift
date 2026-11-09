import AppKit
import UniformTypeIdentifiers

/// File actions offered on each screenshot (plan section 8). Main-thread only.
enum ScreenshotActions {
    /// Opens a Finder window on the file's folder with the file selected.
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens the file in its default app (Preview for images).
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Shows the system share picker (AirDrop, Messages, Mail, …) for the file, below `view`.
    /// `onDismiss` runs once the picker closes, whether or not a service was chosen.
    static func share(_ url: URL, from view: NSView, onDismiss: @escaping () -> Void = {}) {
        let picker = NSSharingServicePicker(items: [url])
        let delegate = SharePickerDelegate(onDismiss: onDismiss)
        // `delegate` is weak; the picker is gone once dismissed, so this releases both.
        objc_setAssociatedObject(picker, &SharePickerDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN)
        picker.delegate = delegate
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    /// Puts the image on the general pasteboard so it pastes as an image (not a file).
    ///
    /// Writes the file's original bytes under its own type (`public.png` for default
    /// screenshots) instead of an `NSImage`: `NSImage` writes an uncompressed TIFF, which for
    /// an 8000×6000 image left ~280 MB in this process until the clipboard next changed.
    /// The pasteboard still serves TIFF to readers that ask for it, converting on their side.
    /// Nothing is decoded here and the bytes are released before returning.
    /// Returns false if the file isn't a readable image.
    @discardableResult
    static func copyImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image)
        else { return false }
        return autoreleasepool {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return false }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type.identifier))
        }
    }
}

/// Reports when a share picker closes. AppKit calls `didChoose` with `nil` on dismissal.
private final class SharePickerDelegate: NSObject, NSSharingServicePickerDelegate {
    nonisolated(unsafe) static var key: UInt8 = 0
    let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func sharingServicePicker(_ picker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        onDismiss()
    }
}
