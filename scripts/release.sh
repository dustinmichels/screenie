#!/usr/bin/env bash
# Build, notarize, tag, and publish a GitHub release of Screenie.
# The version comes from MARKETING_VERSION in project.yml; bump it, run
# `mise run generate`, and commit before releasing.
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

version=$(xcodebuild -project Screenie.xcodeproj -scheme Screenie -configuration Release \
  -showBuildSettings 2>/dev/null | awk '$1 == "MARKETING_VERSION" { print $3; exit }')
[ -n "$version" ] || die "could not read MARKETING_VERSION from Screenie.xcodeproj"
yml_version=$(awk '$1 == "MARKETING_VERSION:" { gsub(/"/, "", $2); print $2; exit }' project.yml)
[ "$version" = "$yml_version" ] ||
  die "project.yml has $yml_version but Screenie.xcodeproj has $version; run 'mise run generate' and commit"
tag="v$version"

git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "tag $tag already exists; bump MARKETING_VERSION"
gh auth status >/dev/null 2>&1 || die "gh is not logged in; run 'gh auth login'"
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
