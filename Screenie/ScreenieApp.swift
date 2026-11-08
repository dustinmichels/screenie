import SwiftUI

@main
struct ScreenieApp: App {
    @State private var store = ScreenshotStore()
    @State private var updater = UpdateChecker()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store, updater: updater)
        } label: {
            MenuBarIcon(hasUnseen: store.hasUnseen)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Plain circle when idle; circle with a center dot when there are unseen screenshots.
/// SF Symbols render as template images in the menu bar, adapting to light/dark.
struct MenuBarIcon: View {
    let hasUnseen: Bool

    var body: some View {
        Image(systemName: hasUnseen ? "circle.inset.filled" : "circle")
            .accessibilityLabel(hasUnseen ? "Screenie, new screenshots" : "Screenie")
    }
}
