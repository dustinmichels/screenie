# Install

Screenie isn't distributed as a signed download yet, so you install it by building it from source. It takes a couple of minutes, and you don't need an Apple Developer account.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode (from the Mac App Store), opened at least once so it finishes installing its components
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), only if you change the project (`brew install xcodegen`)

## Build

The steps below assume you're in a checkout of the repository.

::: code-group

```sh [Terminal]
xcodebuild -project Screenie.xcodeproj -scheme Screenie \
  -configuration Release -derivedDataPath build/DerivedData build
```

```text [Xcode]
1. Open Screenie.xcodeproj.
2. Product → Scheme → Edit Scheme… → Run → Build Configuration: Release.
3. Product → Build (⌘B).
4. Product → Show Build Folder in Finder; the app is under Products/Release.
```

:::

The terminal build writes the app to `build/DerivedData/Build/Products/Release/Screenie.app`.

The build is signed ad hoc (`CODE_SIGN_IDENTITY: "-"`), so it runs on the Mac that built it without a developer certificate.

## Install the app

Copy the app to `/Applications` and launch it:

```sh
cp -R build/DerivedData/Build/Products/Release/Screenie.app /Applications/
open /Applications/Screenie.app
```

A circle shows up in the menu bar. Screenie has no Dock icon or app menu, so you control it from the popover.

## First launch

1. **Allow folder access.** If your screenshots are saved to Desktop, Documents, or Downloads, macOS asks whether Screenie may access that folder. Click **Allow**. If you deny it, the popover says it can't read the folder and links to **System Settings → Privacy & Security → Files and Folders**, where you can turn access back on. Screenie retries the next time you open the popover.
2. **Existing screenshots count as seen.** On the very first launch, everything already in the folder is marked as seen, so the dot only appears for screenshots you take from then on.
3. **Optional: launch at login.** Check **Launch at login** in the popover footer. Screenie registers itself as a login item, which you can also manage in **System Settings → General → Login Items**. Do this after moving the app to `/Applications`, because the login item points to the app where it was when you checked the box.

## Recommended: turn off the floating thumbnail

By default, macOS shows a floating thumbnail in the corner of the screen after each screenshot. It only writes the file once that thumbnail goes away (after about 5 seconds, or right away if you swipe it off). Screenie can't see the file before then, so the dot shows up late.

To turn the thumbnail off, press ⌘⇧5 → **Options** → uncheck **Show Floating Thumbnail**, or run:

```sh
defaults write com.apple.screencapture show-thumbnail -bool false
```

Screenshots are then written right away, and the dot appears almost immediately.

## Changing the screenshot folder

Screenie reads the location macOS saves screenshots to, which you set in ⌘⇧5 → **Options** → **Save to**. If you never changed it, that's `~/Desktop`. Screenie checks the setting again each time you open the popover, so a change takes effect on the next click.

## Rebuilding after code changes

The Xcode project is generated from `project.yml` by XcodeGen. If you add or rename source files, or edit `project.yml`, regenerate the project before building:

```sh
xcodegen generate
```

Don't edit `Screenie.xcodeproj` directly; your changes are lost the next time the project is regenerated.

## Uninstall

1. Uncheck **Launch at login** in the popover if you turned it on.
2. Click **Quit Screenie** (⌘Q while the popover is open).
3. Delete the app and its preferences:

```sh
rm -rf /Applications/Screenie.app
defaults delete com.dustinmichels.Screenie
```

The only preference Screenie stores is when you last looked at your screenshots (`lastSeenDate`).
