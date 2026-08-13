#!/usr/bin/env bash
# ============================================================================
# P8.03 — build the distributable DMG and publish its SHA-256.
#
# The image carries three things: the application, the `boreas` command line
# tool beside it, and an /Applications symlink so the drag target is obvious.
# The CLI ships **next to** the app rather than inside its bundle, because a
# binary inside a bundle has to be signed before the bundle that contains it,
# and the Homebrew cask can link either — a `binary` stanza costs nothing while
# nested signing costs an ordering constraint nobody would remember.
#
# The DMG is signed too. An unsigned container around signed contents still
# makes Gatekeeper ask, which defeats the point of notarising at all.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

APP="${1:-}"
CLI="${2:-}"
OUT="${3:-build/dmg}"

if [ ! -d "${APP:-}" ]; then
  echo "usage: scripts/make-dmg.sh /path/to/Boreas.app /path/to/boreas [outdir]" >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "$APP/Contents/Info.plist")
NAME="Boreas-$VERSION"
STAGE="$OUT/stage"
DMG="$OUT/$NAME.dmg"

rm -rf "$OUT"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
[ -n "$CLI" ] && [ -f "$CLI" ] && cp "$CLI" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "▶ building $DMG"
hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" \
  | sed 's/^/    /'

# The container gets the same identity as its contents.
TEAM="${APPLE_TEAM_ID:-$(grep -E '^DEVELOPMENT_TEAM' Local.xcconfig 2>/dev/null | tr -d ' ' | cut -d= -f2)}"
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | grep "Developer ID Application" | grep "($TEAM)" | head -1 | awk '{print $2}')}"
if [ -z "$IDENTITY" ]; then
  echo "✗ no Developer ID Application certificate for team ${TEAM:-<unset>}" >&2
  exit 1
fi
codesign --force --sign "$IDENTITY" --timestamp "$DMG"
codesign --verify --verbose=2 "$DMG" 2>&1 | sed 's/^/    /'
echo "  ✓ disk image signed"

rm -rf "$STAGE"

# **No checksum is written here, and that is the fix for a real defect.**
# `stapler` rewrites the image when it attaches the notarisation ticket, so a
# hash taken at this point describes a file that no longer exists by the time
# anybody downloads it. v0.1.0 shipped exactly that: a `.sha256` a user running
# `shasum -c` would see fail, which reads as a corrupted or tampered download —
# worse than publishing no checksum at all. It is written after stapling, by the
# script that does the stapling.

echo "  ✓ $DMG"
