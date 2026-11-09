# Install

Screenie runs on macOS 14 (Sonoma) or later. Building it yourself? See the [developer guide](/developers).

## Download

1. Download **Screenie.dmg** from the [latest GitHub release](https://github.com/dustinmichels/screenie/releases/latest) ([direct download](https://github.com/dustinmichels/screenie/releases/latest/download/Screenie.dmg)).
2. Open it, then drag **Screenie.app** onto the **Applications** shortcut in the window that appears.
3. Eject the **Screenie** disk image (in Finder's sidebar, or drag it to the Trash), then open Screenie from Applications.

Prefer a zip? Each release also has **Screenie.zip** ([direct download](https://github.com/dustinmichels/screenie/releases/latest/download/Screenie.zip)) with the same app: open it, then drag **Screenie.app** into Applications.

Screenie is signed and notarized by Apple, so it opens without security warnings. A circle appears in the menu bar. There's no Dock icon or app window; you use Screenie from the menu bar.

::: tip Keep it in Applications
Run Screenie from **Applications**, not from the disk image or Downloads. **Launch at login** remembers where the app was when you turned it on, and macOS remembers folder access for that one copy.
:::

## Homebrew

```sh
brew install --cask dustinmichels/tap/screenie
```

This installs the same notarized app into Applications from the `dustinmichels/tap` [tap](https://docs.brew.sh/Taps), which is updated with every release.

## First launch

1. **Allow folder access.** If your screenshots are saved to Desktop, Documents, or Downloads, macOS asks whether Screenie may access that folder. Click **Allow**. If you deny it, the popover says it can't read the folder and links to **System Settings → Privacy & Security → Files and Folders**, where you can turn access back on. Screenie retries the next time you open the popover.
2. **Existing screenshots count as seen.** On the very first launch, everything already in the folder is marked as seen, so the dot only appears for screenshots you take from then on.
3. **Optional: launch at login.** Check **Launch at login** in the popover footer. You can also manage it in **System Settings → General → Login Items**.

## Recommended: turn off the floating thumbnail

By default, macOS shows a floating thumbnail in the corner of the screen after each screenshot. It only writes the file once that thumbnail goes away (after about 5 seconds, or right away if you swipe it off). Screenie can't see the file before then, so the dot shows up late.

To turn the thumbnail off, press ⌘⇧5 → **Options** → uncheck **Show Floating Thumbnail**, or run:

```sh
defaults write com.apple.screencapture show-thumbnail -bool false
```

Screenshots are then written right away, and the dot appears almost immediately.

## Changing the screenshot folder

Screenie reads the location macOS saves screenshots to, which you set in ⌘⇧5 → **Options** → **Save to**. If you never changed it, that's your Desktop. Screenie checks the setting again each time you open the popover, so a change takes effect on the next click.

## Updating

Screenie checks GitHub for a new release when it launches and when you open the popover, at most once a day. To check right away, click **Check for Updates…** in the popover footer.

When a new version is out, Screenie asks whether to update:

- **Download** downloads the new **Screenie.dmg**, opens it, and quits Screenie. Drag **Screenie.app** onto the **Applications** shortcut, choose **Replace**, eject the disk image, and open Screenie again.
- **Later** dismisses the prompt. Screenie asks again the next day.
- **Release Notes** opens the release on GitHub.

To update by hand instead:

1. Quit Screenie: **Quit Screenie** in the popover footer, or ⌘Q while the popover is open.
2. Download the new **Screenie.dmg** from the [latest release](https://github.com/dustinmichels/screenie/releases/latest) and open it.
3. Drag the new **Screenie.app** onto the **Applications** shortcut and choose **Replace**, then eject the disk image.
4. Open Screenie.

Launch at login and folder access carry over to the new version.

Installed with Homebrew? The in-app update works the same way, or run `brew upgrade --cask screenie`.

## Uninstall

1. Uncheck **Launch at login** in the popover if you turned it on.
2. Click **Quit Screenie** (⌘Q while the popover is open).
3. Move **Screenie.app** from Applications to the Trash.

Screenie stores a single preference: when you last looked at your screenshots. To remove it too, run:

```sh
defaults delete com.dustinmichels.Screenie
```

Installed with Homebrew? Do step 1, then run `brew uninstall --cask screenie` (it quits Screenie and removes the app). `brew uninstall --zap --cask screenie` also deletes the preference.
