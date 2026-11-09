#!/usr/bin/env bash
# Point the Homebrew cask in dustinmichels/homebrew-tap at a published GitHub release.
#
# Usage: scripts/update-cask.sh [X.Y.Z | --check]
#   Hashes Screenie.dmg as GitHub serves it from release v<X.Y.Z> (default: the latest release)
#   and commits the new version and sha256 to Casks/screenie.rb. Does nothing if they already match.
#   --check only verifies that gh can read the cask and push to the tap.
set -euo pipefail

cd "$(dirname "$0")/.."

TAP_REPO=dustinmichels/homebrew-tap
CASK=Casks/screenie.rb
ASSET=Screenie.dmg
api="repos/$TAP_REPO/contents/$CASK"

die() { echo "update-cask: $*" >&2; exit 1; }

[ $# -le 1 ] || die "usage: scripts/update-cask.sh [X.Y.Z | --check]"

if [ "${1:-}" = --check ]; then
  gh api "$api" --silent 2>/dev/null || die "can't read $CASK in $TAP_REPO"
  [ "$(gh api "repos/$TAP_REPO" --jq .permissions.push)" = true ] || die "gh can't push to $TAP_REPO"
  exit 0
fi

if [ $# -eq 1 ]; then
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "bad version '$1'"
  tag="v$1"
else
  tag=$(gh release view --json tagName --jq .tagName) || die "couldn't find the latest release"
fi
version=${tag#v}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

gh release download "$tag" --pattern "$ASSET" --dir "$tmp" || die "couldn't download $ASSET from release $tag"
sha=$(shasum -a 256 "$tmp/$ASSET" | awk '{ print $1 }')

blob=$(gh api "$api" --jq .sha) || die "can't read $CASK in $TAP_REPO"
gh api "$api" -H "Accept: application/vnd.github.raw+json" >"$tmp/old.rb"
sed -E -e "s/^(  version ).*/\1\"$version\"/" -e "s/^(  sha256 ).*/\1\"$sha\"/" "$tmp/old.rb" >"$tmp/new.rb"
grep -qx "  version \"$version\"" "$tmp/new.rb" && grep -qx "  sha256 \"$sha\"" "$tmp/new.rb" ||
  die "$CASK has no '  version' or '  sha256' line to update"

if cmp -s "$tmp/old.rb" "$tmp/new.rb"; then
  echo "$TAP_REPO already points at Screenie $version"
  exit 0
fi
gh api -X PUT "$api" --silent -f message="screenie $version" \
  -f content="$(base64 -i "$tmp/new.rb")" -f sha="$blob"
echo "Updated $TAP_REPO to Screenie $version"
