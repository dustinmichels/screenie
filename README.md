This is a clone of a macOS utility app called "Screenie" which I was using, but which was not performant enough. It seemed to always consume a lot of my memory / CPU.

It should be a mac app that adds a circle to the top menu bar. When I click on the circle I can see recent screenshots, sorted by timestamp.

When I take a new screenshot, it quick detects this and shows a dot in the center of circle which I can click to access the screenshot (open in finder, copy, delete.)

Is Rust a good fit?

## Docs

Install and how-it-works docs live in `docs/` (VitePress). Preview them with:

```sh
cd docs && bun install && bun run dev
```

## Notes

### New screenshots show up a few seconds late

With the floating thumbnail enabled (the macOS default), the screenshot file is only written once the thumbnail in the corner of the screen goes away (about 5 seconds, or immediately if you swipe it off). Screenie can't see the file before that, so the dot appears late.

To turn the thumbnail off: press ⌘⇧5 → Options → uncheck **Show Floating Thumbnail**. Or from a terminal:

```sh
defaults write com.apple.screencapture show-thumbnail -bool false
```

Screenshots are then written right away, and Screenie's folder watcher picks them up as soon as they land.

### Screen recordings are not listed

Screenie only shows still screenshots. Screen recordings (`.mov` files from ⌘⇧5) in the same folder are ignored.
