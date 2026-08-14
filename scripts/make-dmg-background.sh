#!/usr/bin/env bash
# ============================================================================
# P8.12 — build the disk image window background.
#
# The image is drawn at 2x and downsampled, so the two files cannot disagree
# about anything but resolution. Finder picks `background@2x.png` on a Retina
# display and `background.png` everywhere else.
#
# **Everything positioned here has a partner in `make-dmg-layout.sh`.** The
# arrow points at coordinates Finder puts icons at, and nothing checks that
# claim — if you move an icon there, move the art here, and look at the result.
# The constants are named in both files for that reason.
#
# **Known limitation, recorded rather than hidden:** a disk image background is
# one fixed picture, and Finder draws icon labels in the system's text colour.
# In dark appearance those labels are white, and they sit on this light
# background with less contrast than they deserve. Every alternative trades the
# problem the other way — a dark background loses the labels in light
# appearance, which is the commoner case — so this is a choice, not an
# oversight.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
. scripts/gates/_lib.sh

OUT="Design/dmg"
FONT="/System/Library/Fonts/SFNS.ttf"

echo "▶ make-dmg-background — the disk image window"

require_tools magick

if [ ! -f "$FONT" ]; then
  fail "system font missing: $FONT"
  exit 1
fi

mkdir -p "$OUT"

# --- geometry --------------------------------------------------------------
# The 1x window, in points. `make-dmg-layout.sh` reads the same numbers.
W=640
H=450
# Icon centres, 1x. Row one is the install gesture; row two is the optional
# command line tool, deliberately below and out of the way of it.
APP_X=170;  APP_Y=195
DEST_X=470; DEST_Y=195
CLI_X=320;  CLI_Y=320
# A 128 point icon centred at CLI_Y spans 64 points either side, and Finder
# draws its own label in the ~16 points below that. The caption has to clear
# both or it lands on top of the word "boreas" — which is what the first
# render did.
CAPTION_Y=$(( CLI_Y + 92 ))

S=2                       # draw at 2x
W2=$(( W * S )); H2=$(( H * S ))

px() { echo $(( $1 * S )); }

# --- the canvas ------------------------------------------------------------
# A cold, very pale wash — the north wind at almost no saturation, so the
# application icon is the only saturated thing in the window.
magick -size "${W2}x${H2}" \
  gradient:'#FBFCFE-#E8EEF6' \
  -blur 0x1 \
  "$OUT/.work-canvas.png"

# --- the arrow -------------------------------------------------------------
# From the application towards /Applications, on the icons' own centre line.
# Drawn as a shaft plus a head rather than a font glyph, so it scales cleanly.
AY=$(px $APP_Y)
A1=$(px $(( APP_X + 78 )))      # shaft start
A2=$(px $(( DEST_X - 92 )))     # shaft end, where the head begins
HEAD=$(px 26)
HALF=$(px 13)

magick "$OUT/.work-canvas.png" \
  -stroke '#9FB3CC' -strokewidth "$(px 5)" -fill none \
  -draw "line $A1,$AY $A2,$AY" \
  -stroke none -fill '#9FB3CC' \
  -draw "polygon $A2,$(( AY - HALF )) $(( A2 + HEAD )),$AY $A2,$(( AY + HALF ))" \
  "$OUT/.work-arrow.png"

# --- the words -------------------------------------------------------------
# The title carries the product; the line under it carries what the product is,
# in the same words the repository description uses.
magick "$OUT/.work-arrow.png" \
  -font "$FONT" -fill '#16202C' -pointsize "$(px 34)" \
  -gravity North -annotate "+0+$(px 44)" 'Boreas' \
  -font "$FONT" -fill '#5C6B7D' -pointsize "$(px 14)" \
  -gravity North -annotate "+0+$(px 92)" \
    'Fan control and temperature monitoring for Apple Silicon' \
  "$OUT/.work-title.png"

# The caption for the second row, centred and clear of Finder's own label.
magick "$OUT/.work-title.png" \
  -font "$FONT" -fill '#8494A6' -pointsize "$(px 12)" \
  -gravity North -annotate "+0+$(px $CAPTION_Y)" \
    'Optional command line tool — drag it anywhere on your PATH' \
  "$OUT/.work-caption.png"

# --- emit ------------------------------------------------------------------
cp "$OUT/.work-caption.png" "$OUT/background@2x.png"
magick "$OUT/.work-caption.png" -resize "${W}x${H}" "$OUT/background.png"
rm -f "$OUT"/.work-*.png

ok "background.png    ${W}x${H}"
ok "background@2x.png ${W2}x${H2}"

echo
echo "✓ make-dmg-background done"
