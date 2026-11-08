#!/usr/bin/env bash
# Build, notarize, tag, and publish a GitHub release of Screenie.
#
# Usage: scripts/release.sh [patch|minor|major|X.Y.Z]
#   With an argument, bumps MARKETING_VERSION (and CURRENT_PROJECT_VERSION) in project.yml,
#   regenerates Screenie.xcodeproj, commits, and pushes before building.
#   Without one, releases MARKETING_VERSION as-is if v<version> isn't tagged yet (a manual bump,
#   or a rerun after a failed release), otherwise bumps the patch version.
set -euo pipefail

cd "$(dirname "$0")/.."

ARCHIVE=build/Screenie.xcarchive
APP=build/notarized/Screenie.app
ZIP=build/Screenie.zip
DMG=build/Screenie.dmg
DMG_ROOT=build/dmg
NOTARIZE_TIMEOUT=7200 # seconds; a first submission took ~30 min

die() { echo "release: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

bump=${1:-}
case "$bump" in
  "" | patch | minor | major) ;;
  [0-9]*.[0-9]*.[0-9]*) [[ "$bump" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "bad version '$bump'" ;;
  *) die "usage: scripts/release.sh [patch|minor|major|X.Y.Z]" ;;
esac
[ $# -le 1 ] || die "usage: scripts/release.sh [patch|minor|major|X.Y.Z]"

# --- Preflight: everything that can fail before the long notarization wait ---

step "Checking git state"
if [ -n "$(git status --porcelain)" ]; then
  git status --short >&2
  die "working tree is not clean; commit or stash first"
fi
branch=$(git symbolic-ref --short HEAD 2>/dev/null) || die "HEAD is detached"
[ "$branch" = main ] || die "on branch '$branch'; release from main"
git fetch --quiet --tags origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] ||
  die "main and origin/main differ; push or pull first"
gh auth status >/dev/null 2>&1 || die "gh is not logged in; run 'gh auth login'"

yml_version=$(awk '$1 == "MARKETING_VERSION:" { gsub(/"/, "", $2); print $2; exit }' project.yml)
[[ "$yml_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "project.yml MARKETING_VERSION '$yml_version' is not X.Y.Z"
if [ -z "$bump" ] && git rev-parse -q --verify "refs/tags/v$yml_version" >/dev/null; then
  bump=patch
fi

if [ -n "$bump" ]; then
  IFS=. read -r major minor patch <<<"$yml_version"
  case "$bump" in
    patch) new_version="$major.$minor.$((patch + 1))" ;;
    minor) new_version="$major.$((minor + 1)).0" ;;
    major) new_version="$((major + 1)).0.0" ;;
    *) new_version=$bump ;;
  esac
  git rev-parse -q --verify "refs/tags/v$new_version" >/dev/null && die "tag v$new_version already exists"
  build=$(awk '$1 == "CURRENT_PROJECT_VERSION:" { gsub(/"/, "", $2); print $2; exit }' project.yml)
  [[ "$build" =~ ^[0-9]+$ ]] || die "project.yml CURRENT_PROJECT_VERSION '$build' is not an integer"

  step "Bumping version $yml_version -> $new_version (build $((build + 1)))"
  sed -i '' -E \
    -e "s/^([[:space:]]*MARKETING_VERSION:).*/\1 \"$new_version\"/" \
    -e "s/^([[:space:]]*CURRENT_PROJECT_VERSION:).*/\1 \"$((build + 1))\"/" \
    project.yml
  xcodegen generate --quiet
  git add project.yml Screenie.xcodeproj
  git commit --quiet -m "chore(release): v$new_version"
  git push --quiet origin main
fi

version=$(xcodebuild -project Screenie.xcodeproj -scheme Screenie -configuration Release \
  -showBuildSettings 2>/dev/null | awk '$1 == "MARKETING_VERSION" { print $3; exit }')
[ -n "$version" ] || die "could not read MARKETING_VERSION from Screenie.xcodeproj"
yml_version=$(awk '$1 == "MARKETING_VERSION:" { gsub(/"/, "", $2); print $2; exit }' project.yml)
[ "$version" = "$yml_version" ] ||
  die "project.yml has $yml_version but Screenie.xcodeproj has $version; run 'mise run generate' and commit"
tag="v$version"

git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "tag $tag already exists; bump MARKETING_VERSION"
gh release view "$tag" >/dev/null 2>&1 && die "GitHub release $tag already exists"

echo "Releasing Screenie $version ($tag) from $(git rev-parse --short HEAD)"

# --- Build and notarize ---

rm -rf "$ARCHIVE" build/notarize build/notarized "$ZIP" "$DMG" "$DMG_ROOT" build/upload.plist
mkdir -p build

step "Archiving"
xcodebuild -project Screenie.xcodeproj -scheme Screenie -configuration Release \
  -derivedDataPath build/DerivedData -archivePath "$ARCHIVE" archive -quiet

step "Signing with Developer ID and uploading to Apple's notary service"
cp ExportOptions.plist build/upload.plist
plutil -insert destination -string upload build/upload.plist
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist build/upload.plist \
  -exportPath build/notarize -allowProvisioningUpdates -quiet

step "Waiting for notarization"
start=$SECONDS
until out=$(xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" \
  -exportPath build/notarized -allowProvisioningUpdates 2>&1); do
  if ! grep -qiE 'processing|in progress' <<<"$out"; then
    printf '%s\n' "$out" >&2
    die "exporting the notarized app failed"
  fi
  elapsed=$((SECONDS - start))
  [ "$elapsed" -lt "$NOTARIZE_TIMEOUT" ] ||
    die "still processing after $((elapsed / 60)) min; when Apple finishes, finish by hand (README → Releasing, steps 3-4) and publish with: git tag -a $tag -m 'Screenie $version' && git push origin $tag && gh release create $tag $DMG $ZIP --verify-tag --title 'Screenie $version' --generate-notes"
  echo "  still processing ($((elapsed / 60)) min elapsed)"
  sleep 30
done

step "Verifying and packaging"
xcrun stapler validate "$APP"
spctl -a -vv -t exec "$APP" 2>&1 | grep -q 'source=Notarized Developer ID' ||
  die "spctl does not accept $APP as notarized"
ditto -c -k --keepParent "$APP" "$ZIP"
# The disk image itself is unsigned; Gatekeeper checks the stapled app inside when it's opened.
mkdir -p "$DMG_ROOT"
ditto "$APP" "$DMG_ROOT/Screenie.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -quiet -volname Screenie -srcfolder "$DMG_ROOT" -fs HFS+ -format UDZO "$DMG"
hdiutil verify -quiet "$DMG"

# --- Tag and publish ---

step "Tagging $tag and publishing the GitHub release"
git tag -a "$tag" -m "Screenie $version"
git push origin "$tag"
gh release create "$tag" "$DMG" "$ZIP" --verify-tag --title "Screenie $version" --generate-notes

echo
echo "Released $(gh release view "$tag" --json url --jq .url)"
