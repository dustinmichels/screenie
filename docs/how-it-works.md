# How it works

## Using Screenie

### The menu bar icon

| Icon | Meaning |
| --- | --- |
| Empty circle | No new screenshots |
| Circle with a dot in the center | You've taken a screenshot since you last opened the popover |

Click the icon to open the popover. If the dot was showing, the popover scrolls to the top and outlines the newest screenshot, and the dot goes away. Screenshots you take while the popover is open count as seen right away.

Screenie remembers when you last looked, so a screenshot taken while Screenie wasn't running still shows the dot the next time it launches.

### The popover

The popover shows a two-column grid of up to 50 screenshots, newest first. Each one shows how long ago it was taken ("2 min. ago", "yesterday"). Hover over a thumbnail to see its file name.

| To… | Do this |
| --- | --- |
| Open in Preview (or your default image app) | Double-click the thumbnail |
| Copy the image | Hover → copy button, or right-click → **Copy Image** |
| Show it in Finder | Hover → magnifying glass in the middle, or right-click → **Show in Finder** |
| Move it to the Trash | Hover → trash button, or right-click → **Move to Trash…**, then confirm with Return (Escape cancels) |
| Put it in another app | Drag the thumbnail into a Finder window, email, chat, etc. |

The footer has the **Launch at login** checkbox and **Quit Screenie** (⌘Q).

If the folder has no screenshots yet, the popover shows the folder it's watching, so you can tell whether ⌘⇧5 → **Options** → **Save to** points where you expect.

### What gets listed

- Only files macOS marks as screenshots. Other images in the same folder are ignored.
- Still screenshots only. Screen recordings (`.mov` files from ⌘⇧5) are skipped.
- Only the folder macOS currently saves screenshots to. If you change that folder, the list switches to the new one.

## Under the hood

Screenie is a native Swift/SwiftUI app with no third-party dependencies. It's built to cost nothing while you aren't using it: no timers, no polling, and no full-size images kept in memory.

### Finding the screenshot folder

macOS stores the screenshot location in the `com.apple.screencapture` preferences under the `location` key. Screenie reads it, falls back to `~/Desktop` when it isn't set, and resolves `~` and symlinks. It reads the setting again whenever you open the popover, and if the folder changed, it stops the old watcher and starts a new one.

### Detecting new screenshots

When macOS saves a screenshot, it tags the file with the `kMDItemIsScreenCapture` attribute. Screenie uses two sources that both look for that tag, and merges what they find:

1. **Spotlight.** An `NSMetadataQuery` for `kMDItemIsScreenCapture == 1`, limited to the screenshot folder and sorted by creation date. Spotlight pushes updates as files appear and disappear.
2. **A folder watcher.** Spotlight can be turned off or lag behind a new file by a few seconds, so Screenie also watches the folder with a kqueue event source. Whenever a file is added, removed, or renamed, it lists the folder and keeps files that carry the `com.apple.metadata:kMDItemIsScreenCapture` extended attribute. It lists the folder once more a second after the last change, because some tools create the file first and set its attributes afterwards, which doesn't trigger another event.

For files directly in the folder, the folder listing decides what's there. Spotlight fills in anything deeper and supplies the more accurate creation date. Both sources wait for events from the system, so neither uses any CPU while nothing happens.

Files that start with `.` are skipped, because macOS writes a screenshot as `.Screenshot …` and renames it when it's done. Recordings are recognized by file extension, which needs no file access.

### The "new" dot

Screenie saves one value in its preferences: `lastSeenDate`, the creation date of the newest screenshot you've seen. The dot shows whenever the newest listed screenshot is newer than that. Opening the popover sets `lastSeenDate` to the newest listed screenshot's date, not the current time, so a screenshot Spotlight hasn't reported yet won't be marked seen by mistake. Because the dot is computed from the list, it also goes away if you delete the new screenshot.

### Thumbnails

Thumbnails come from ImageIO (`CGImageSourceCreateThumbnailAtIndex`). ImageIO shrinks the image while decoding it, so the full-resolution image is never held in memory. Each thumbnail is 160 points on its longest side at your screen's scale, rotated to match the photo's orientation data.

They're decoded one at a time on a background queue and kept in an `NSCache` capped at about 20 MB. A screenshot's thumbnail is dropped from the cache once it leaves the list. The grid is lazy, so only cells you scroll to are decoded.

### Copying

**Copy Image** puts the file's original bytes on the clipboard under their own type (`public.png` for a standard screenshot) instead of going through `NSImage`. With `NSImage`, a large image is turned into an uncompressed TIFF that Screenie would have to keep in memory until something else replaces the clipboard. With the original bytes, that cost drops from hundreds of megabytes to a few. Apps that want TIFF still get it, converted on their side.

### Permissions

Screenie isn't sandboxed. Desktop, Documents, and Downloads are still protected by macOS privacy controls, so listing one of them for the first time shows the system's permission prompt. If you deny it, Screenie shows a message with a link to the right settings page, and tries again each time you open the popover or switch to the app.

### Resource use

Measured with a Release build watching a folder of 33 screenshots:

| State | CPU | Memory |
| --- | --- | --- |
| Idle, popover never opened | 0.0% | ~14 MB |
| After opening the popover (thumbnails decoded) | back to 0.0% within ~20 s | ~32 MB |

## Known limitations

- **New screenshots show up a few seconds late** while the floating thumbnail is enabled. [Turn it off](/install#recommended-turn-off-the-floating-thumbnail) to fix this.
- **Screen recordings aren't listed.**
- **Only the 50 newest screenshots are shown.**
