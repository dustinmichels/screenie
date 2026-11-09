# Release distribution ideas

Options for installing Screenie beyond the GitHub release DMG/zip.

| Route | Effort | Status |
|---|---|---|
| Own tap (`dustinmichels/homebrew-tap`) | Low | Done: `brew install --cask dustinmichels/tap/screenie` |
| Official `homebrew/cask` | Low to write | Blocked on notability thresholds |
| mise | Works mechanically | Wrong install model for a menu bar app |

## Custom Homebrew tap (done)

[dustinmichels/homebrew-tap](https://github.com/dustinmichels/homebrew-tap) holds
`Casks/screenie.rb`, which installs the release `Screenie.dmg`.
`scripts/release.sh` runs `scripts/update-cask.sh` after publishing, which
rewrites `version` and `sha256` through the GitHub API (`mise run cask` reruns
it). The cask sets `auto_updates true` because of the in-app update check, so a
plain `brew upgrade` may leave it to the app; `brew upgrade --cask screenie`
always upgrades it.

## Official `homebrew/cask`

Screenie already meets the technical requirements
([Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)): notarized app,
native arm64 (no Rosetta), developer-published GitHub download, versioned URL.

Blocker is [notability](https://docs.brew.sh/Package-Acceptance-Policy#notability):

- Self-submission by the repo owner: at least 90 forks, 90 watchers, or 225 stars.
- Submission by someone else: at least 30 forks, 30 watchers, or 75 stars.

As of 2026-11-08 the repo has 0 / 0 / 0. The tap cask can be submitted
unchanged once the project qualifies (drop the `version`/`sha256` automation
then; Homebrew's autobump updates official casks).

## mise (not recommended)

mise's `github:` backend can download `Screenie.zip`, but it extracts into
`~/.local/share/mise/installs/...` and looks for CLI binaries to put on `PATH`.
Screenie is an `LSUIElement` menu bar app that registers a login item via
`SMAppService.mainApp`; it belongs in `/Applications`, and mise has no
cask equivalent. Installing this way recreates the problem the DMG solves.
