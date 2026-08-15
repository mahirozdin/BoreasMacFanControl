#!/usr/bin/env bash
# ============================================================================
# P9.04 — encode the demo loop the README shows.
#
# The frames come from the application's own camera (`--render-film`), which
# steps the still pictures' fixture forward one sample at a time. **The fan
# line in them is computed by `Core`** — `Curve.duty(at:)` through
# `RateLimit.standard`, the same two pieces the running product uses — so the
# loop shows what the engine does with a rising temperature rather than an
# animation drawn to look like it.
#
# ## Why a GIF, when a GIF is the worst of the options
#
# It is the only moving format a README can show. GitHub renders `<video>` in
# issues and pull requests and **not** in repository markdown, and an MP4 in a
# README is a link somebody has to decide to click. A demo nobody plays is a
# still picture with extra bytes.
#
# The cost is real: 256 colours, and the charts' anti-aliased lines are exactly
# what dithers badly. That is what the colour count and the size ceiling below
# are negotiating with.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
. scripts/gates/_lib.sh

OUT="docs/images/demo.gif"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A README picture nobody waits for. The ceiling is not advice: an oversized
# demo is worse than none, because it delays the page for readers who never
# scroll to it.
CEILING_BYTES=$((4 * 1024 * 1024))
WIDTH=760
DELAY=8        # hundredths of a second — 12.5 frames per second
COLORS=112

echo "▶ make-demo — the README's demo loop"

require_tools magick

# --- find the application --------------------------------------------------
if [ -z "${APP:-}" ]; then
  APP=$(ls -d build/release/Build/Products/Release/Boreas.app 2>/dev/null | head -1)
fi
if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
  APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Boreas-*/Build/Products/Debug/Boreas.app \
    2>/dev/null | head -1)
fi
BIN="${APP:-}/Contents/MacOS/Boreas"
if [ ! -x "$BIN" ]; then
  fail "application not found — build it first, or set APP=/path/to/Boreas.app"
  exit 1
fi
note "app: $APP"

# --- frames ----------------------------------------------------------------
"$BIN" --render-film "$WORK/frames" -AppleLanguages '(en)' >/dev/null 2>&1 \
  || { fail "--render-film failed"; exit 1; }
COUNT=$(find "$WORK/frames" -name 'frame-*.png' | wc -l | tr -d ' ')
if [ "$COUNT" -lt 2 ]; then
  fail "the camera produced $COUNT frames"
  exit 1
fi
ok "$COUNT frames rendered"

# --- encode ----------------------------------------------------------------
# `-layers optimize` rewrites each frame as the region that changed since the
# last one, which on a chart that scrolls is most of the saving there is.
magick -delay "$DELAY" "$WORK/frames"/frame-*.png \
  -resize "${WIDTH}x" \
  -colors "$COLORS" \
  -layers optimize \
  -loop 0 \
  "$WORK/demo.gif"

BYTES=$(wc -c < "$WORK/demo.gif" | tr -d ' ')
DIM=$(magick identify -format '%wx%h' "$WORK/demo.gif[0]")
SECONDS_LONG=$(echo "$COUNT $DELAY" | awk '{printf "%.1f", $1 * $2 / 100}')

if [ "$BYTES" -gt "$CEILING_BYTES" ]; then
  fail "$((BYTES / 1024)) KB exceeds the $((CEILING_BYTES / 1024)) KB ceiling"
  note "lower WIDTH or COLORS in this script, or shorten the film in"
  note "RenderFilmEvidence — do not just raise the ceiling"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
cp "$WORK/demo.gif" "$OUT"

ok "$OUT — $DIM, $COUNT frames, ${SECONDS_LONG}s, $((BYTES / 1024)) KB"
note "under the $((CEILING_BYTES / 1024)) KB ceiling"
note "the fan line in it is Core's output, not artwork — see RenderFilmEvidence"

echo
echo "✓ make-demo done"
