#!/usr/bin/env bash
# ============================================================================
# P9.03 — regenerate the screenshots the READMEs show.
#
# **This exists because P8.05 wrote down that it did not.** Its run log closed
# with: *"screenshots are fixture renders and will drift from the interface
# silently; nothing regenerates them."* Three pictures were produced by hand,
# and the next interface change would have made them quietly wrong. This is the
# command that makes them a build output.
#
# ## They are renders, not screenshots
#
# The application draws its own interface into PNG files offscreen
# (`RenderEvidence`), because a real screen capture needs the Screen Recording
# permission this project promises never to ask for (invariant I2). Two things
# fall out of that, and both are worth more than the permission:
#
#   - **They are deterministic.** The fixtures are frozen, including the clock,
#     so a chart's x axis is the same in every run. A screenshot never is.
#   - **They carry nobody's data.** No machine name, no account name, no real
#     sensor values — the same allowlist reasoning as the support report
#     (P7.05) and the unknown-sensor report (P7.09).
#
# Rendered under `-AppleLanguages '(en)'` because the developer's machine is not
# English and the English README needs English pictures. The translated READMEs
# share these files deliberately: a screenshot per language would be five sets
# to keep in step, and the interface in the picture is not what those readers
# are checking.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
. scripts/gates/_lib.sh

OUT="docs/images"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▶ make-screenshots — the pictures the READMEs show"

# --- find the application --------------------------------------------------
# Same order as scripts/layout-test.sh: an explicit override, then the build
# directories, then Launch Services. A freshly built app has no Launch Services
# entry, which is why the build directories come first.
if [ -z "${APP:-}" ]; then
  APP=$(ls -d build/release/Build/Products/Release/Boreas.app 2>/dev/null | head -1)
fi
if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
  APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Boreas-*/Build/Products/Debug/Boreas.app \
    2>/dev/null | head -1)
fi
if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
  APP=$(ls -d build/Debug/Boreas.app 2>/dev/null | head -1)
fi

BIN="${APP:-}/Contents/MacOS/Boreas"
if [ ! -x "$BIN" ]; then
  fail "application not found — build it first, or set APP=/path/to/Boreas.app"
  note "make generate && xcodebuild -project Boreas.xcodeproj -scheme Boreas \\"
  note "  -configuration Release -destination 'platform=macOS,arch=arm64' \\"
  note "  -derivedDataPath build/release build"
  exit 1
fi
note "app: $APP"

# --- render everything the camera has --------------------------------------
for surface in panel window settings status; do
  "$BIN" "--render-$surface" "$WORK/$surface" -AppleLanguages '(en)' >/dev/null 2>&1 \
    || { fail "--render-$surface failed"; exit 1; }
done
RENDERED=$(find "$WORK" -name '*.png' | wc -l | tr -d ' ')
ok "$RENDERED renders produced"

# --- the published set -----------------------------------------------------
# The camera renders far more than the READMEs should show. This table is the
# editorial decision, in one place: which surface earns a place on the page,
# and under what name. Renaming a published picture breaks the READMEs, so the
# names on the left are a contract.
mkdir -p "$OUT"
COPIED=0
publish() {  # publish <published-name> <render-path>
  if [ ! -f "$WORK/$2" ]; then
    fail "the camera did not produce $2 — has a fixture been renamed?"
    exit 1
  fi
  cp "$WORK/$2" "$OUT/$1"
  COPIED=$((COPIED + 1))
}

publish main-window.png        window/window-monitoring-light.png
publish main-window-dark.png   window/window-monitoring-dark.png
publish panel-light.png        panel/panel-2-driving.png
publish panel-dark.png         panel/panel-3-driving-dark.png
publish curve-editor.png       window/window-control-light.png
publish curve-editor-dark.png  window/window-control-dark.png
publish diagnostics.png        window/window-diagnostics-light.png
publish settings.png           settings/settings-4-control.png

# --- the menu bar strip ----------------------------------------------------
# The status item's variants are 48 points tall and meaningless one at a time;
# together they show that the thing in the menu bar is configurable. Composed
# rather than rendered, because no single fixture is "all of them at once".
if command -v magick >/dev/null 2>&1; then
  magick \
    "$WORK/status/status-1-default.png" \
    "$WORK/status/status-2-driving.png" \
    "$WORK/status/status-5-chart.png" \
    "$WORK/status/status-6-vertical.png" \
    "$WORK/status/status-7-compact.png" \
    -background none -bordercolor none -border 18x14 +append \
    "$OUT/menu-bar.png"
  # `-splice` was the first attempt and it is the wrong operator: it inserts
  # space INTO each image at the gravity point, so centred it cut every variant
  # in half. A border pads around them, which is what "space between" means.
  COPIED=$((COPIED + 1))
  ok "menu-bar.png composed from five status item variants"
else
  warn "imagemagick absent — menu-bar.png not rebuilt (the committed one stands)"
fi

ok "$COPIED pictures written to $OUT"
note "they are renders, not captures: deterministic, and carrying nobody's data"

echo
echo "✓ make-screenshots done"
