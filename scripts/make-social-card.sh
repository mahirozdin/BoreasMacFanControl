#!/usr/bin/env bash
# ============================================================================
# P9.02 — build the repository's social preview card.
#
# This is the picture GitHub attaches to the repository's link. Without one it
# renders a generic card carrying an avatar and some text, which is what every
# share of this project produced until now: `openGraphImageUrl` was null.
#
# **The upload is manual and always will be.** GitHub's REST API has no
# endpoint for the social preview; it is set in the repository's Settings page
# and nowhere else. This script produces the file; M10 is the person who
# uploads it.
#
# ## Geometry
#
# 1280x640 is what GitHub serves. Other places crop it: 1.91:1 takes a slice off
# the top and bottom, and a few render it small enough that only the largest
# text survives. So the card is built to be read at two sizes — the name and the
# icon carry it when everything else is illegible, and nothing that matters sits
# in the outer 40 pixels.
#
# The interface picture is the point rather than decoration. A card that shows
# only a logo says a project exists; one that shows the product says what it is.
# It is the **dark** panel render, because the card is dark, and it bleeds off
# the right edge on purpose — a partially visible window reads as a window,
# while a complete one shrunk to fit reads as a thumbnail.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
. scripts/gates/_lib.sh

OUT="Design/social"
FONT="/System/Library/Fonts/SFNS.ttf"
ICON="Design/icon/render/boreas-512.png"
PANEL="docs/images/panel-dark.png"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▶ make-social-card — the repository's link preview"

require_tools magick

for asset in "$FONT" "$ICON" "$PANEL"; do
  if [ ! -f "$asset" ]; then
    fail "missing: $asset"
    exit 1
  fi
done

mkdir -p "$OUT"

W=1280
H=640

# --- the ground ------------------------------------------------------------
# The icon's own deep end, so the card and the product are recognisably the
# same object. A plain vertical gradient: anything busier competes with the
# interface picture, which is the one thing here that has to stay readable.
magick -size "${W}x${H}" gradient:'#12325E-#081A33' "$WORK/1-ground.png"

# A cold highlight behind the icon, wide and very faint — it separates the left
# column from the ground without drawing a box around it.
magick "$WORK/1-ground.png" \
  \( -size 700x700 radial-gradient:'#3B82D622-#00000000' \) \
  -geometry +40+20 -composite \
  "$WORK/2-glow.png"

# --- the interface ---------------------------------------------------------
# Cropped rather than scaled to fit: the panel is 640x952, and a whole window
# shrunk into a 640px-tall card is unreadable at any size the card is shown.
#
# **It runs off two edges, decisively.** The first version cleared the right
# edge and stopped a few pixels short of the bottom, which does not read as a
# window continuing past the card — it reads as a picture that was cut by
# accident, with the word "Quit" sliced in half. Bleeding off both edges is
# either obviously deliberate or nothing at all.
magick "$PANEL" -resize x660 -crop 380x660+0+0 +repage \
  -bordercolor '#2A4A7A' -border 1 \
  "$WORK/panel.png"

magick "$WORK/2-glow.png" "$WORK/panel.png" -geometry +920+70 -composite \
  -crop "${W}x${H}+0+0" +repage \
  "$WORK/3-panel.png"

# --- the words -------------------------------------------------------------
magick "$WORK/3-panel.png" \
  \( "$ICON" -resize 132x132 \) -geometry +80+92 -composite \
  "$WORK/4-icon.png"

magick "$WORK/4-icon.png" \
  -font "$FONT" -fill '#FFFFFF' -pointsize 82 \
  -annotate +236+200 'Boreas' \
  -font "$FONT" -fill '#AFC9E8' -pointsize 31 \
  -annotate +82+318 'Mac fan control and temperature' \
  -annotate +82+362 'monitoring for Apple Silicon' \
  "$WORK/5-words.png"

# --- the three things people want to know before they click ----------------
# Phrased as what the product does NOT ask for, because that is the question a
# tool that writes to hardware has to answer first.
chip() {  # chip <infile> <outfile> <x> <text>
  magick "$1" \
    -fill '#1E4272' -stroke '#33639E' -strokewidth 1 \
    -draw "roundrectangle $3,470 $(( $3 + $5 )),522 26,26" \
    -stroke none -fill '#CFE1F7' -font "$FONT" -pointsize 23 \
    -annotate "+$(( $3 + 22 ))+504" "$4" \
    "$2"
}
chip "$WORK/5-words.png" "$WORK/6a.png"  82 'No kernel extension' 250
chip "$WORK/6a.png"      "$WORK/6b.png" 348 'No SIP changes'      196
chip "$WORK/6b.png"      "$WORK/6c.png" 560 'No telemetry'        176

magick "$WORK/6c.png" \
  -font "$FONT" -fill '#7C9BC4' -pointsize 22 \
  -annotate +82+594 'Free and open source  ·  Apache-2.0  ·  macOS 14+' \
  "$OUT/social-card.png"

DIM=$(magick identify -format '%wx%h' "$OUT/social-card.png")
if [ "$DIM" != "${W}x${H}" ]; then
  fail "card is $DIM, expected ${W}x${H}"
  exit 1
fi

ok "$OUT/social-card.png $DIM ($(wc -c < "$OUT/social-card.png" | tr -d ' ') bytes)"
note "upload it by hand — GitHub has no API for the social preview (M10)"
note "Settings → General → Social preview → Upload an image"

echo
echo "✓ make-social-card done"
