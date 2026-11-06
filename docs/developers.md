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

This builds the Release app, quits Screenie if it's running, deletes `/Applications/Screenie.app`, copies the new build there, and launches it. It replaces whatever copy is installed, including a notarized release build.

| Task | Does |
| --- | --- |
| `mise run build` | Builds the Release app into `build/DerivedData` |
| `mise run install` | `build`, then replaces `/Applications/Screenie.app` and launches it |
| `mise run generate` | Regenerates `Screenie.xcodeproj` from `project.yml` |
| `mise run release` | Notarizes, tags, and publishes a GitHub release (see [Releasing](#releasing)) |
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

Producing a signed, notarized build needs a paid Apple Developer account signed in to Xcode, and the [GitHub CLI](https://cli.github.com) logged in. Bump `MARKETING_VERSION` in `project.yml`, run `mise run generate`, commit, push to `main`, then:

```sh
mise run release
```

`scripts/release.sh` archives the app, has Apple notarize it, and publishes a GitHub release `v<version>` with `Screenie.dmg` and `Screenie.zip` attached. The [README](https://github.com/dustinmichels/screenie#releasing) lists its preconditions and the equivalent manual steps.

## Docs

This site lives in `docs/` and is built with VitePress:

```sh
mise run docs   # or: cd docs && bun install && bun run dev
```
