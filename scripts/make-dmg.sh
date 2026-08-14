#!/usr/bin/env bash
# ============================================================================
# P8.03 — build the distributable DMG and publish its SHA-256.
#
# The image carries three things: the application, the `boreas` command line
# tool beside it, and an /Applications symlink so the drag target is obvious.
# It also carries its own window — a background picture and a pre-baked
# `.DS_Store` holding the icon positions (P8.12). Both are committed assets,
# because the machine that builds the shipped image is a CI runner with no
# Finder to arrange anything.
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
ART="Design/dmg"

# **The volume is always called `Boreas`, and the version lives in the file
# name.** Finder stores the window's background picture in `.DS_Store` as an
# alias, and an alias resolves by volume name — so a volume named after the
# version would break its own layout on the next release. This is the one line
# that makes a pre-baked layout possible at all (P8.12).
VOLUME="Boreas"

rm -rf "$OUT"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
[ -n "$CLI" ] && [ -f "$CLI" ] && cp "$CLI" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# --- the window ------------------------------------------------------------
# Art and layout are committed build assets, produced by `make dmg-background`
# and `make dmg-layout`. **A missing one is fatal, not a fallback.** Falling
# back would ship the bare three-icons-in-a-row window this task exists to
# replace, and it would ship it silently — the failure mode this repository
# spends its gates avoiding.
for asset in "$ART/background.png" "$ART/background@2x.png" "$ART/DS_Store"; do
  if [ ! -f "$asset" ]; then
    echo "✗ missing build asset: $asset" >&2
    echo "  run 'make dmg-background' and 'make dmg-layout'" >&2
    exit 1
  fi
done

# The layout's alias points at `Boreas:.background.tiff` — one file at the
# volume root holding both resolutions. `tiffutil` is Apple's own and ships
# with the command line tools, so this costs the build nothing.
tiffutil -cathidpicheck "$ART/background.png" "$ART/background@2x.png" \
  -out "$STAGE/.background.tiff" >/dev/null
if [ ! -f "$STAGE/.background.tiff" ]; then
  echo "✗ tiffutil produced no background" >&2
  exit 1
fi
cp "$ART/DS_Store" "$STAGE/.DS_Store"

echo "▶ building $DMG"
hdiutil create -volname "$VOLUME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" \
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
echo
echo "  The window is not verified by this script exiting zero. Look at it:"
echo "      open \"$DMG\""
