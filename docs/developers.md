# Developer guide

Screenie is a native Swift/SwiftUI app with no third-party dependencies. This page covers building it from source, working on it, and cutting releases. For how the app detects screenshots and keeps its resource use low, see [Under the hood](/how-it-works#under-the-hood).

Just want to use the app? [Download a release](/install) instead.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode (from the Mac App Store), opened at least once so it finishes installing its components
- Optional: [mise](https://mise.jdx.dev), which runs the build/install steps below as one command and installs XcodeGen and Bun for you
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), only if you change the project (`brew install xcodegen`, or `mise install`)

```sh
git clone https://github.com/dustinmichels/screenie.git
cd screenie
```

## Build and install

The build is signed ad hoc (`CODE_SIGN_IDENTITY: "-"`), so it runs on the Mac that built it without a developer certificate. Each rebuild has a new signature, so macOS asks for Desktop/Documents access again after you install it.

Install the app in `/Applications`, not where you built it. **Launch at login** saves the app's path when you check the box, so a login item pointing into `build/` breaks once that copy is rebuilt or deleted.

### With mise

```sh
mise run install
```

This builds the Release app, quits Screenie if it's running, deletes `/Applications/Screenie.app`, copies the new build there, launches it, and then deletes `build/`. It replaces whatever copy is installed, including a notarized release build.

| Task                | Does                                                                                                                          |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `mise run dev`      | Builds the Debug app and runs it from `build/` in the terminal; Ctrl-C quits it                                               |
| `mise run demo`     | Like `dev`, but lists fake sample screenshots instead of your own (see [Screenshots for the docs](#screenshots-for-the-docs)) |
| `mise run build`    | Builds the Release app into `build/DerivedData`                                                                               |
| `mise run install`  | `build`, then replaces `/Applications/Screenie.app`, launches it, and runs `cleanup`                                          |
| `mise run cleanup`  | Deletes `build/` (DerivedData, archives, release artifacts)                                                                   |
| `mise run generate` | Regenerates `Screenie.xcodeproj` from `project.yml`                                                                           |
| `mise run release`  | Notarizes, tags, and publishes a GitHub release (see [Releasing](#releasing))                                                 |
| `mise run docs`     | Previews this docs site                                                                                                       |

`mise run dev` is for trying out changes without touching `/Applications`. It quits any running Screenie first, since both copies share a bundle ID. The app stays attached to the terminal, so crashes and anything it prints show up there. Don't turn on **Launch at login** from a dev build: the login item would point into `build/`.

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

Then quit any running Screenie and replace the installed copy. Delete the old copy instead of copying over it: `cp -R` into an existing bundle merges the folders, and leftover files break the code signature.

```sh
rm -rf /Applications/Screenie.app
cp -R build/DerivedData/Build/Products/Release/Screenie.app /Applications/
open /Applications/Screenie.app
```

## Changing the project

The Xcode project is generated from `project.yml` by XcodeGen. If you add or rename source files, or edit `project.yml`, regenerate the project before building:

```sh
xcodegen generate   # or: mise run generate
```

Don't edit `Screenie.xcodeproj` directly; your changes are lost the next time the project is regenerated.

The app icon is drawn by `scripts/make-icon.swift`. Edit the script and run `swift scripts/make-icon.swift` from the repo root to regenerate `Screenie/Assets.xcassets/AppIcon.appiconset`. The docs site uses copies of it in `docs/public/`.

## Releasing

Producing a signed, notarized build needs a paid Apple Developer account signed in to Xcode (Settings → Accounts). `ExportOptions.plist` exports for Developer ID distribution with automatic signing for team `LLM5F36KYW`; change `teamID` for another account. Publishing needs the [GitHub CLI](https://cli.github.com) logged in (`gh auth login`) with push access to [dustinmichels/homebrew-tap](https://github.com/dustinmichels/homebrew-tap).

To cut a release from a clean `main` that's level with `origin/main`:

```sh
mise run release          # next patch version, e.g. 0.1.0 -> 0.1.1
mise run release minor    # or major, or an exact version like 1.0.0
```

If `v<MARKETING_VERSION>` is already tagged (or you pass `patch`, `minor`, `major`, or `X.Y.Z`), `scripts/release.sh` first bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, regenerates `Screenie.xcodeproj`, and commits and pushes `chore(release): v<version>` to `main`. If the version isn't tagged yet (you bumped it by hand, or a previous release failed after its bump), plain `mise run release` releases it as-is.

The script refuses to start unless the working tree is clean, you're on `main` level with `origin/main`, `gh` is logged in and can push to the tap, `project.yml` and `Screenie.xcodeproj` agree on the version, and neither the tag `v<version>` nor a GitHub release for it exists yet. It then runs steps 1–4 below, polls every 30 s until Apple has notarized the build (gives up after 2 h), checks the result, and only then creates and pushes the annotated tag and publishes a GitHub release with generated notes and `Screenie.dmg` and `Screenie.zip` attached. If anything fails before that, no tag or release exists, so fix it and rerun `mise run release` without an argument to release the already-bumped version.

Last, it runs `scripts/update-cask.sh <version>`, which downloads the published `Screenie.dmg`, hashes it, and commits the new `version` and `sha256` to `Casks/screenie.rb` in the tap through the GitHub API. If that step fails, the release is already out; rerun `mise run cask` (latest release) or `scripts/update-cask.sh <version>`. Rerunning is a no-op when the cask already matches.

Installed copies find the update through this release: the in-app update check reads the latest release's `v<version>` tag and downloads its `Screenie.dmg`, so keep that tag format and asset name. The cask downloads the same file. Drafts and prereleases aren't offered.

### Releasing by hand

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

# 5. After tagging and publishing the GitHub release, point the Homebrew cask at it
scripts/update-cask.sh <version>
```

The disk image itself isn't signed or notarized. The app inside is notarized with its ticket stapled, and that's what Gatekeeper checks when the app is opened, so a downloaded DMG mounts and the app runs without warnings. Signing and notarizing the DMG too would need a local Developer ID certificate (Xcode signs in the cloud) and `notarytool` credentials.

To sign without notarizing, run step 2 with `ExportOptions.plist` as-is (`-exportPath build/export`).

If you prefer `notarytool` (not used for the current builds): sign without notarizing as above, zip `build/export/Screenie.app` with `ditto`, store credentials once with `xcrun notarytool store-credentials`, then `xcrun notarytool submit build/Screenie.zip --keychain-profile <profile> --wait` and `xcrun stapler staple build/export/Screenie.app`. Zip again after stapling.

## Docs

This site lives in `docs/` and is built with VitePress:

```sh
mise run docs   # or: cd docs && bun install && bun run dev
```

### Screenshots for the docs

To capture the app without showing your own files, run:

```sh
mise run demo
```

This renders eight fake screenshots (mock editor, chart, chat, and so on, aged 2 minutes to 12 days) into `build/demo-screenshots` with `scripts/make-samples.swift`, then runs the Debug app with `SCREENIE_FOLDER` pointing there. Only Debug builds read `SCREENIE_FOLDER`. To show the "new" dot, add one more from another terminal while the popover is closed:

```sh
swift scripts/make-samples.swift build/demo-screenshots --new
```

To capture only the popover, open it, press ⌘⇧4, then Space, and click the popover; hold Option while clicking to leave out the shadow. That way the desktop isn't in the shot. For video, press ⌘⇧5 and record a portion around the menu bar icon and popover; switch to a plain wallpaper first, and hide other menu bar icons if you don't want them in the clip.

The site's screenshots live in `docs/public/screenshots/`: `popover.png` on the home page and `popover-hover.png` in [How it works](/how-it-works#the-popover). Pages show them at `width="406"`, half their pixel size, so they're sharp on Retina screens.
