# Release distribution ideas

Options for installing Screenie beyond the GitHub release DMG/zip.

| Route | Effort | Blocker |
|---|---|---|
| Own tap (`dustinmichels/homebrew-tap`) | Low | None |
| Official `homebrew/cask` | Low to write | Notability thresholds |
| mise | Works mechanically | Wrong install model for a menu bar app |

## Custom Homebrew tap (recommended next step)

Create a public repo `dustinmichels/homebrew-tap` containing `Casks/screenie.rb`.
Users install with:

```sh
brew install --cask dustinmichels/tap/screenie
```

Cask:

```ruby
cask "screenie" do
  version "0.1.0"
  sha256 "<shasum -a 256 Screenie.zip>"

  url "https://github.com/dustinmichels/screenie/releases/download/v#{version}/Screenie.zip"
  name "Screenie"
  desc "Menu bar list of recent screenshots"
  homepage "https://github.com/dustinmichels/screenie"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma" # project.yml deploymentTarget 14.0

  app "Screenie.app"

  zap trash: "~/Library/Preferences/com.dustinmichels.Screenie.plist"
end
```

Notes:

- Uses the existing release zip. The app inside is notarized, so Gatekeeper
  passes without `--no-quarantine`.
- No Sparkle/self-updater, so no `auto_updates true`; users update via
  `brew upgrade`.
- Installs into `/Applications`, which avoids the Launch at login problem of
  running from Downloads.

### Release automation

Each release must bump `version` and `sha256` in the tap. Add a step at the end
of `scripts/release.sh`, either:

- clone the tap, rewrite those two lines, commit, push; or
- `brew bump-cask-pr --tap dustinmichels/tap --version <v> screenie`.

## Official `homebrew/cask`

Screenie already meets the technical requirements
([Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)): notarized app,
native arm64 (no Rosetta), developer-published GitHub download, versioned URL.

Blocker is [notability](https://docs.brew.sh/Package-Acceptance-Policy#notability):

- Self-submission by the repo owner: at least 90 forks, 90 watchers, or 225 stars.
- Submission by someone else: at least 30 forks, 30 watchers, or 75 stars.

As of 2026-11-06 the repo has 0 / 0 / 0. The tap cask can be submitted
unchanged once the project qualifies.

## mise (not recommended)

mise's `github:` backend can download `Screenie.zip`, but it extracts into
`~/.local/share/mise/installs/...` and looks for CLI binaries to put on `PATH`.
Screenie is an `LSUIElement` menu bar app that registers a login item via
`SMAppService.mainApp`; it belongs in `/Applications`, and mise has no
cask equivalent. Installing this way recreates the problem the DMG solves.
