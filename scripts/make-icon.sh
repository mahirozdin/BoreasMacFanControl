#!/usr/bin/env bash
# ============================================================================
# P8.11 — build `App/Resources/Boreas.icns` from the icon source.
#
# **Why an `.icns` and not the `.icon` the design document specifies.**
# `Design/icon/README.md` describes an Icon Composer build: full-bleed layers,
# no mask, no shadow, because on macOS 26 the system applies all three. That is
# the right target for macOS 26 and the wrong one for this product — invariant
# T2 sets the minimum at macOS 14.0, and macOS 14 and 15 cannot read a `.icon`
# at all. A bundle carrying only that would show the generic placeholder on
# every Mac this project claims to support, which is exactly the defect P8.11
# exists to fix.
#
# A classic `.icns` gets nothing applied to it, so the two things the system
# would have drawn are baked in here instead:
#
#   - **The rounded rectangle.** Apple's macOS icon grid puts the plate at
#     824x824 inside a 1024x1024 canvas. The source render is full-bleed
#     1024x1024, so an icns built straight from it renders about 24 percent
#     wider than every neighbouring icon in Finder and /Applications. Measured,
#     not assumed: the render's opaque bounds are x 0-1023, y 0-1023.
#   - **The shadow.** Apple's own icons carry theirs in the artwork; Finder
#     draws none. Without it the plate sits flat against its neighbours.
#
# The output is COMMITTED. `magick` is a development tool, not a build
# dependency (T4 is about what links into the product, and nothing here does),
# and a fresh clone or a CI runner must be able to build the application
# without installing it. This script regenerates the file; it does not stand
# between the source and a build.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
. scripts/gates/_lib.sh

SRC="Design/icon/render/boreas-1024.png"
OUT="App/Resources/Boreas.icns"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▶ make-icon — the application icon"

require_tools magick iconutil sips

if [ ! -f "$SRC" ]; then
  fail "icon source missing: $SRC"
  exit 1
fi

# --- the plate -------------------------------------------------------------
# 824 of 1024, corner radius 185 — Apple's macOS grid. The radius is applied
# fresh rather than inherited from the source, whose corners were rounded for
# a full-bleed canvas and are the wrong proportion once inset.
PLATE=824
RADIUS=185
MARGIN=$(( (1024 - PLATE) / 2 ))

magick "$SRC" -resize "${PLATE}x${PLATE}" \
  \( -size "${PLATE}x${PLATE}" xc:none \
     -draw "roundrectangle 0,0,$((PLATE - 1)),$((PLATE - 1)),$RADIUS,$RADIUS" \) \
  -alpha set -compose DstIn -composite \
  "$WORK/plate.png"
note "plate ${PLATE}x${PLATE}, radius $RADIUS, margin $MARGIN"

# --- the shadow ------------------------------------------------------------
# Deliberately restrained: 28 percent black, 18px blur, 10px down. Enough to
# lift the plate off the desktop, not enough to read as a drop shadow in its
# own right at 32px.
magick -size 1024x1024 xc:none \
  \( "$WORK/plate.png" -background black -shadow 28x18+0+10 \) \
     -geometry "+$MARGIN+$((MARGIN - 10))" -composite \
  \( "$WORK/plate.png" \) -geometry "+$MARGIN+$MARGIN" -composite \
  "$WORK/master.png"
ok "1024 master composited"

# --- the iconset -----------------------------------------------------------
# Every size is downscaled from the one master, so no two sizes can disagree.
ICONSET="$WORK/Boreas.iconset"
mkdir -p "$ICONSET"

emit() {  # emit <pixels> <filename>
  sips -z "$1" "$1" "$WORK/master.png" --out "$ICONSET/$2" >/dev/null 2>&1
}

emit 16   icon_16x16.png
emit 32   icon_16x16@2x.png
emit 32   icon_32x32.png
emit 64   icon_32x32@2x.png
emit 128  icon_128x128.png
emit 256  icon_128x128@2x.png
emit 256  icon_256x256.png
emit 512  icon_256x256@2x.png
emit 512  icon_512x512.png
cp "$WORK/master.png" "$ICONSET/icon_512x512@2x.png"

COUNT=$(ls "$ICONSET" | wc -l | tr -d ' ')
if [ "$COUNT" -ne 10 ]; then
  fail "iconset holds $COUNT images, expected 10"
  exit 1
fi
ok "iconset complete ($COUNT sizes)"

# --- the icns --------------------------------------------------------------
mkdir -p "$(dirname "$OUT")"
iconutil --convert icns "$ICONSET" --output "$OUT"

if [ ! -f "$OUT" ]; then
  fail "iconutil produced nothing"
  exit 1
fi
ok "$OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"

echo
echo "✓ make-icon done"
