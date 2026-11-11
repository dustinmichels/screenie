# Screenie

A small macOS menu bar app that lists your recent screenshots. It's a lightweight replacement for an eponymous app from ThnkDev, which used too much memory and CPU.

A circle sits in the menu bar. When you take a screenshot, a dot appears in the middle of it. Click the circle to see your recent screenshots, newest first, and open, copy, share, or delete them.

Native Swift/SwiftUI, no dependencies. Idle, it uses ~0% CPU and about 14 MB of memory.

**Docs: [dustinmichels.github.io/screenie](https://dustinmichels.github.io/screenie/)**

## Install

Requires macOS 14 (Sonoma) or later.

```sh
brew install --cask dustinmichels/tap/screenie
```

Or download **Screenie.dmg** from the [latest release](https://github.com/dustinmichels/screenie/releases/latest) and drag Screenie into Applications. See [Install](https://dustinmichels.github.io/screenie/install) for first launch, updating, and uninstalling.

## Documentation

- [Install](https://dustinmichels.github.io/screenie/install): download, Homebrew, first launch, updating, uninstalling
- [How it works](https://dustinmichels.github.io/screenie/how-it-works): using the app, what's under the hood, known limitations
- [Developer guide](https://dustinmichels.github.io/screenie/developers): building from source and cutting releases

The docs source lives in [`docs/`](docs/) (VitePress); preview it with `mise run docs`.

## Building from source

With [mise](https://mise.jdx.dev) and Xcode installed:

```sh
mise run install
```

This builds the Release app and installs it to `/Applications`. See the [developer guide](https://dustinmichels.github.io/screenie/developers) for building without mise and for releasing.
