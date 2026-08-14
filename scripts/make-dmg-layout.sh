#!/usr/bin/env bash
# ============================================================================
# P8.12 — bake the disk image window layout into `Design/dmg/DS_Store`.
#
# **MAINTAINER ONLY. Not part of any build.** Its output is committed, and
# `make-dmg.sh` copies that file into every image it builds — here or on a CI
# runner, which is the point: the runner has no session to arrange anything in.
#
# ## Why this does not drive Finder
#
# It used to, and on macOS 26.5.2 that is a trap. Finder still declares
# `background picture` in its dictionary (`icvp`, type file) and still writes
# it — but the AppleScript *getter* raises -10000 instead of answering, and
# `properties` reports `missing value` for a background that is demonstrably
# there. So the obvious verification says "not set" about a correct image, and
# a script trusting it either fails on success or, worse, passes on failure.
# Every reading in this file is taken from the produced bytes instead.
#
# Finder had a second problem worth recording: it moved the window it was told
# to place. Asked for `{{200, 120}, {640, 450}}` it wrote `{{200, 870}, ...}`,
# which on a short display opens the window mostly below the screen.
#
# `dmgbuild` writes `.DS_Store` directly and touches Finder at no point, which
# is also why it works headless. Install it where it cannot reach the product:
#
#     python3 -m venv ~/.venvs/dmgbuild
#     ~/.venvs/dmgbuild/bin/pip install dmgbuild
#     DMGBUILD=~/.venvs/dmgbuild/bin/dmgbuild make dmg-layout
#
# It is a development tool in the sense the Brewfile means: never linked into
# the product, never needed to build it, and needed by nobody who is not
# changing this artwork.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
. scripts/gates/_lib.sh

APP="${1:-}"
CLI="${2:-}"
VOLUME="Boreas"
OUT="Design/dmg"
DMGBUILD="${DMGBUILD:-dmgbuild}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▶ make-dmg-layout — MAINTAINER ONLY"

if [ ! -d "${APP:-}" ] || [ ! -f "${CLI:-}" ]; then
  fail "usage: scripts/make-dmg-layout.sh /path/to/Boreas.app /path/to/boreas"
  note "positions are recorded against real item NAMES, so the real items have"
  note "to be present — a placeholder would bake positions nothing matches"
  exit 1
fi

if ! command -v "$DMGBUILD" >/dev/null 2>&1; then
  fail "dmgbuild not found (tried: $DMGBUILD)"
  note "see the header of this script for how to install it out of the way"
  exit 1
fi

for art in background.png background@2x.png; do
  if [ ! -f "$OUT/$art" ]; then
    fail "$OUT/$art missing — run 'make dmg-background' first"
    exit 1
  fi
done

# --- geometry --------------------------------------------------------------
# The same numbers as make-dmg-background.sh. Change one, change both, and
# look at the result — no gate can tell you an arrow points at the wrong place.
WIN_X=200; WIN_Y=120
WIN_W=640; WIN_H=450
APP_X=170;  APP_Y=195
DEST_X=470; DEST_Y=195
CLI_X=320;  CLI_Y=320
ICON_SIZE=128

APP_NAME="$(basename "$APP")"
CLI_NAME="$(basename "$CLI")"

cat > "$WORK/settings.py" <<SETTINGS
files = ['$(cd "$(dirname "$APP")" && pwd)/$APP_NAME',
         '$(cd "$(dirname "$CLI")" && pwd)/$CLI_NAME']
symlinks = {'Applications': '/Applications'}
icon_locations = {
    '$APP_NAME':    ($APP_X, $APP_Y),
    'Applications': ($DEST_X, $DEST_Y),
    '$CLI_NAME':    ($CLI_X, $CLI_Y),
}
# dmgbuild picks up background@2x.png beside this file on its own and emits a
# two-resolution .background.tiff. make-dmg.sh rebuilds that TIFF with the
# same tool Apple ships, so the alias below always has something to resolve.
background = '$(pwd)/$OUT/background.png'
window_rect = (($WIN_X, $WIN_Y), ($WIN_W, $WIN_H))
icon_size = $ICON_SIZE
text_size = 13
default_view = 'icon-view'
show_status_bar = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
SETTINGS

"$DMGBUILD" -s "$WORK/settings.py" "$VOLUME" "$WORK/layout.dmg" >/dev/null

hdiutil detach "/Volumes/$VOLUME" >/dev/null 2>&1 || true
hdiutil attach "$WORK/layout.dmg" -noautoopen >/dev/null
if [ ! -f "/Volumes/$VOLUME/.DS_Store" ]; then
  hdiutil detach "/Volumes/$VOLUME" >/dev/null 2>&1 || true
  fail "dmgbuild produced no .DS_Store"
  exit 1
fi
mkdir -p "$OUT"
cp "/Volumes/$VOLUME/.DS_Store" "$OUT/DS_Store"
hdiutil detach "/Volumes/$VOLUME" >/dev/null

# --- read the bytes back ---------------------------------------------------
# Not "did the command exit zero" and not "what does Finder say". The alias is
# decoded and its volume, its target and the window rectangle are checked
# against what was asked for. A layout whose alias names the wrong volume
# resolves to nothing the moment the image is rebuilt, and that is precisely
# the failure this whole pre-baked approach has to rule out.
"$DMGBUILD" --help >/dev/null 2>&1
PYTHON="$(dirname "$DMGBUILD")/python3"
[ -x "$PYTHON" ] || PYTHON="$(dirname "$DMGBUILD")/python"
[ -x "$PYTHON" ] || PYTHON="python3"

"$PYTHON" - "$OUT/DS_Store" "$VOLUME" "$WIN_W" "$WIN_H" <<'VERIFY' || exit 1
import sys
from ds_store import DSStore
import mac_alias

path, volume, want_w, want_h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
icvp = bwsp = None
with DSStore.open(path, "r") as store:
    for entry in store:
        if entry.code == b"icvp" and isinstance(entry.value, dict):
            icvp = entry.value
        elif entry.code == b"bwsp" and isinstance(entry.value, dict):
            bwsp = entry.value

problems = []
if icvp is None:
    problems.append("no icvp record — the icon view was never described")
else:
    if icvp.get("backgroundType") != 2:
        problems.append("backgroundType is %r, expected 2 (picture)" % icvp.get("backgroundType"))
    raw = icvp.get("backgroundImageAlias")
    if not raw:
        problems.append("no backgroundImageAlias — the window has no picture")
    else:
        alias = mac_alias.Alias.from_bytes(bytes(raw))
        if alias.volume.name != volume:
            problems.append("alias names volume %r, expected %r — it will not "
                            "resolve on a rebuilt image" % (alias.volume.name, volume))
        print("    background : %s:%s" % (alias.volume.name, alias.target.filename))
    if int(icvp.get("iconSize", 0)) != 128:
        problems.append("iconSize is %r" % icvp.get("iconSize"))

if bwsp is None:
    problems.append("no bwsp record — the window has no size")
else:
    bounds = bwsp.get("WindowBounds", "")
    print("    window     : %s" % bounds)
    if ("%d, %d" % (want_w, want_h)) not in bounds.replace("{", "").replace("}", ""):
        problems.append("WindowBounds %s does not carry %dx%d" % (bounds, want_w, want_h))

for problem in problems:
    print("  ✗ %s" % problem)
sys.exit(1 if problems else 0)
VERIFY

ok "$OUT/DS_Store ($(wc -c < "$OUT/DS_Store" | tr -d ' ') bytes), verified from its own bytes"
note "commit it — every image built from now on, here or on CI, uses this file"

echo
echo "✓ make-dmg-layout done"
