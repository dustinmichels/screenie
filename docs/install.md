# Install

You can install Screenie from a notarized release build, or build it from source. Building from source takes a couple of minutes and doesn't need an Apple Developer account.

Either way, the app goes in `/Applications`:

- **Launch at login** saves the app's path when you check the box. If the app runs from `build/` or `Downloads`, the login item breaks once that copy is moved or deleted.
- macOS remembers folder access for the copy of the app you allowed. Keep one copy in one place and you're asked only once.

## Requirements

- macOS 14 (Sonoma) or later

To build from source you also need:

- Xcode (from the Mac App Store), opened at least once so it finishes installing its components
- Optional: [mise](https://mise.jdx.dev), which runs the build/install steps below as one command and installs XcodeGen for you
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), only if you change the project (`brew install xcodegen`, or `mise install`)

## Install a release build

If you have a notarized `Screenie.zip`, from a [GitHub release](https://github.com/dustinmichels/screenie/releases) or elsewhere, unzip it and drag `Screenie.app` to `/Applications`. A release build made on this Mac (see Releasing in the README) is already unzipped in `build/notarized/`:

```sh
cp -R build/notarized/Screenie.app /Applications/
open /Applications/Screenie.app
```

It's signed with a Developer ID and notarized, so Gatekeeper lets it run without warnings. Skip to [First launch](#first-launch).

## Build from source

The steps below assume you're in a checkout of the repository.

The build is signed ad hoc (`CODE_SIGN_IDENTITY: "-"`), so it runs on the Mac that built it without a developer certificate. Each rebuild has a new signature, so macOS asks for Desktop/Documents access again after you install it.

### With mise

```sh
mise run install
```

This builds the Release app, quits Screenie if it's running, deletes `/Applications/Screenie.app`, copies the new build there, and launches it. It replaces whatever copy is installed, including a notarized release build. Skip to [First launch](#first-launch).

| Task | Does |
| --- | --- |
| `mise run build` | Builds the Release app into `build/DerivedData` |
| `mise run install` | `build`, then replaces `/Applications/Screenie.app` and launches it |
| `mise run generate` | Regenerates `Screenie.xcodeproj` from `project.yml` |
| `mise run docs` | Previews this docs site |

### Without mise

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
xcodegen generate   # or: mise run generate
```

Don't edit `Screenie.xcodeproj` directly; your changes are lost the next time the project is regenerated.

## Updating

Quit Screenie first (**Quit Screenie** in the popover footer, or ⌘Q while the popover is open), then replace the app. For a source build, `mise run install` does all of this. Delete the old copy instead of copying over it: `cp -R` into an existing bundle merges the folders, and leftover files break the code signature.

```sh
rm -rf /Applications/Screenie.app
cp -R build/DerivedData/Build/Products/Release/Screenie.app /Applications/   # or build/notarized/Screenie.app
open /Applications/Screenie.app
```

Launch at login keeps working, because the app is back at the same path. A source build asks for folder access again; a Developer ID build counts as the same app as the previous version, so the permission carries over.

## Uninstall

1. Uncheck **Launch at login** in the popover if you turned it on.
2. Click **Quit Screenie** (⌘Q while the popover is open).
3. Delete the app and its preferences:

```sh
rm -rf /Applications/Screenie.app
defaults delete com.dustinmichels.Screenie
```

The only preference Screenie stores is when you last looked at your screenshots (`lastSeenDate`).
