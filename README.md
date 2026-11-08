# Screenie

A small macOS menu bar app that lists your recent screenshots. It's a lightweight replacement for the original Screenie app, which used too much memory and CPU.

A circle sits in the menu bar. When you take a screenshot, a dot appears in the middle of it. Click the circle to see your recent screenshots, newest first, and open, copy, or delete them.

Native Swift/SwiftUI. Idle, it uses ~0% CPU and about 14 MB of memory; with the popover open and 50 thumbnails loaded it plateaus around 50 MB. It never decodes full-resolution images for display.

## Requirements

macOS 14 (Sonoma) or later.

## Install

Install Screenie in `/Applications`, not where you built or downloaded it:

- **Launch at login** saves the app's path when you check the box. If the app runs from `build/` or `Downloads`, the login item breaks once that copy is moved or deleted.
- macOS remembers folder access for the copy of the app you allowed. Keep one copy in one place and you're asked only once.

### From a release

Each [GitHub release](https://github.com/dustinmichels/screenie/releases) has `Screenie.dmg` and `Screenie.zip` attached (see [Releasing](#releasing)); both contain the same notarized app.

1. Open `Screenie.dmg` and drag `Screenie.app` onto the `Applications` shortcut in its window, then eject the disk image. From the zip, unzip it and drag `Screenie.app` to `/Applications`. For a local release build: `cp -R build/notarized/Screenie.app /Applications/`.
2. Open it from `/Applications`. It's signed with a Developer ID and notarized, so Gatekeeper lets it run without warnings.

### From source

With [mise](https://mise.jdx.dev), one command builds the Release app, quits any running Screenie, replaces `/Applications/Screenie.app`, and launches it:

```sh
mise run install
```

`mise run build` only builds. Without mise:

```sh
xcodebuild -project Screenie.xcodeproj -scheme Screenie \
  -configuration Release -derivedDataPath build/DerivedData build
cp -R build/DerivedData/Build/Products/Release/Screenie.app /Applications/
open /Applications/Screenie.app
```

A source build is signed ad hoc, so it runs on the Mac that built it without a developer certificate. Every rebuild has a new signature, so macOS asks for Desktop/Documents access again after each one. Developer ID builds count as the same app from one version to the next, so the permission carries over. `mise run install` overwrites whatever is in `/Applications`, including a notarized build. See [`docs/developers.md`](docs/developers.md) for Xcode steps and rebuilding with XcodeGen, and [`docs/install.md`](docs/install.md) for uninstalling.

### Updating

Quit Screenie first (**Quit Screenie** in the popover footer), then replace the app. `mise run install` does all of this for a source build. Delete the old copy instead of copying over it: `cp -R` into an existing bundle merges the folders, and leftover files break the code signature.

```sh
rm -rf /Applications/Screenie.app
cp -R build/DerivedData/Build/Products/Release/Screenie.app /Applications/   # or build/notarized/Screenie.app
open /Applications/Screenie.app
```

Launch at login keeps working, because the app is back at the same path.

### First launch

- If your screenshots are saved to Desktop, Documents, or Downloads, macOS asks whether Screenie may access that folder. Click **Allow**. If you deny it, the popover says so and links to **System Settings → Privacy & Security → Files and Folders**.
- Screenshots that already exist count as seen, so the dot only lights up for new ones.

## Usage

- **Circle** in the menu bar: no new screenshots. **Circle with a dot**: there are screenshots you haven't looked at yet. Opening the popover clears the dot and highlights the newest screenshot.
- **Double-click** a thumbnail to open it in its default app (usually Preview).
- **Hover** over a thumbnail for buttons to copy, share, or move the image to the Trash, plus a magnifying glass in the middle to show it in Finder.
- **Right-click** a thumbnail for the same actions plus Open.
- **Drag** a thumbnail into another app or a Finder window to use the file.
- **Launch at login**: checkbox in the popover footer. Turn it on after moving the app to `/Applications`.
- **Check for Updates…**: footer button. Screenie also checks GitHub at launch and when you open the popover, at most once a day, and offers to download a newer release.
- **Quit**: **Quit Screenie** in the footer, or ⌘Q while the popover is open.

Screenie watches the folder macOS saves screenshots to (⌘⇧5 → **Options** → **Save to**; `~/Desktop` if you never changed it) and picks up a change of folder the next time you open the popover. It shows the newest 50 screenshots.

## Releasing

Producing a signed, notarized build needs a paid Apple Developer account signed in to Xcode (Settings → Accounts). `ExportOptions.plist` exports for Developer ID distribution with automatic signing for team `LLM5F36KYW`; change `teamID` for another account. Publishing needs the [GitHub CLI](https://cli.github.com) logged in (`gh auth login`).

To cut a release, bump `MARKETING_VERSION` in `project.yml`, run `mise run generate`, commit, and push to `main`. Then:

```sh
mise run release
```

`scripts/release.sh` refuses to start unless the working tree is clean, you're on `main` level with `origin/main`, `project.yml` and `Screenie.xcodeproj` agree on the version, and neither the tag `v<version>` nor a GitHub release for it exists yet. It then runs steps 1–4 below, polls every 30 s until Apple has notarized the build (gives up after 2 h), checks the result, and only then creates and pushes the annotated tag and publishes a GitHub release with generated notes and `Screenie.dmg` and `Screenie.zip` attached. If anything fails before that, no tag or release exists, so fix it and rerun.

The same steps by hand:

```sh
# 1. Archive
xcodebuild -project Screenie.xcodeproj -scheme Screenie -configuration Release \
  -derivedDataPath build/DerivedData -archivePath build/Screenie.xcarchive archive

# 2. Upload to Apple's notary service, signed with the Developer ID
cp ExportOptions.plist build/upload.plist
plutil -insert destination -string upload build/upload.plist
xcodebuild -exportArchive -archivePath build/Screenie.xcarchive \
  -exportOptionsPlist build/upload.plist -exportPath build/notarize -allowProvisioningUpdates

# 3. Once Apple has notarized it, export the stapled app.
#    Fails with "is processing" until then (minutes, longer for a first submission); rerun.
xcodebuild -exportNotarizedApp -archivePath build/Screenie.xcarchive \
  -exportPath build/notarized -allowProvisioningUpdates

# 4. Check, zip, and build the disk image
xcrun stapler validate build/notarized/Screenie.app
spctl -a -vvv -t exec build/notarized/Screenie.app   # "source=Notarized Developer ID"
ditto -c -k --keepParent build/notarized/Screenie.app build/Screenie.zip
mkdir -p build/dmg && ditto build/notarized/Screenie.app build/dmg/Screenie.app
ln -s /Applications build/dmg/Applications
hdiutil create -volname Screenie -srcfolder build/dmg -fs HFS+ -format UDZO build/Screenie.dmg
```

The disk image itself isn't signed or notarized. The app inside is notarized with its ticket stapled, and that's what Gatekeeper checks when the app is opened, so a downloaded DMG mounts and the app runs without warnings. Signing and notarizing the DMG too would need a local Developer ID certificate (Xcode signs in the cloud) and `notarytool` credentials.

To sign without notarizing, run step 2 with `ExportOptions.plist` as-is (`-exportPath build/export`).

If you prefer `notarytool` (not used for the current builds): sign without notarizing as above, zip `build/export/Screenie.app` with `ditto`, store credentials once with `xcrun notarytool store-credentials`, then `xcrun notarytool submit build/Screenie.zip --keychain-profile <profile> --wait` and `xcrun stapler staple build/export/Screenie.app`. Zip again after stapling.

The app icon is drawn by `scripts/make-icon.swift`. Edit the script and run `swift scripts/make-icon.swift` from the repo root to regenerate `Screenie/Assets.xcassets/AppIcon.appiconset`.

## Docs

User (install, how it works) and developer docs live in `docs/` (VitePress). Preview them with:

```sh
mise run docs   # or: cd docs && bun install && bun run dev
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
