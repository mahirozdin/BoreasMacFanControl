#!/usr/bin/env bash
# ============================================================================
# Pseudo-locale layout test (P6.13) — invariant Y3.
#
# Two things happen here, and only the first can fail the build:
#
#   1. `--layout-drill` measures every fixed-width text container against the
#      strings it has to hold, in every language in the bundle, expanded by the
#      budget in `Core.PseudoLocale`. This is the check. It exits non-zero.
#
#   2. Renders of the same surfaces under the platform's own doubling flag,
#      written to a directory, so a human can *see* what a lengthened interface
#      looks like. This cannot fail — it produces evidence, not a verdict.
#      Foundation's doubling corrupts format specifiers (%lld becomes lld), so
#      it is fit for looking at and not for measuring; that is exactly why the
#      measurement in step 1 uses our own expansion.
#
# Why the drill and not a gate: this needs the *built application*, because only
# SwiftUI and AppKit can say how wide a string renders in the font it will
# actually use. `make check` runs without building. So it runs in CI after the
# app build step, and locally with `make layout`.
#
# Exit code: whatever the drill returns.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
. scripts/gates/_lib.sh

echo "▶ layout test — pseudo-locale overflow (Y3)"

# ---------------------------------------------------------------------------
# Locate the application. APP overrides; the build directory otherwise, then
# Launch Services. CI has no Launch Services entry for a freshly built app,
# which is why the build directory is tried first.
# ---------------------------------------------------------------------------
if [ -z "${APP:-}" ]; then
  APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Boreas-*/Build/Products/Debug/Boreas.app \
    2>/dev/null | head -1)
fi
if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
  APP=$(ls -d build/Debug/Boreas.app 2>/dev/null | head -1)
fi
if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
  require_tools mdfind
  APP=$(mdfind "kMDItemCFBundleIdentifier == 'com.bubiapps.boreas'" 2>/dev/null | head -1)
fi

BIN="$APP/Contents/MacOS/Boreas"
if [ ! -x "$BIN" ]; then
  fail "application not found — build it first, or set APP=/path/to/Boreas.app"
  exit 1
fi
note "app: $APP"

# ---------------------------------------------------------------------------
# 1. The check.
# ---------------------------------------------------------------------------
"$BIN" --layout-drill
DRILL_STATUS=$?

# ---------------------------------------------------------------------------
# 2. The evidence. Written next to the other render output; never fatal.
# ---------------------------------------------------------------------------
OUT="${LAYOUT_RENDER_DIR:-}"
if [ -n "$OUT" ]; then
  note "rendering the doubled interface into $OUT"
  for language in en tr; do
    "$BIN" --render-window "$OUT/$language-doubled" \
      -AppleLanguages "($language)" -NSDoubleLocalizedStrings YES >/dev/null 2>&1 \
      && ok "$language doubled renders written" \
      || warn "$language doubled renders failed (evidence only, not a verdict)"
  done
else
  note "set LAYOUT_RENDER_DIR=<dir> to also write doubled renders to look at"
fi

if [ "$DRILL_STATUS" -eq 0 ]; then
  echo
  echo "✓ layout-test PASS"
else
  echo
  echo "✗ layout-test FAIL"
fi
exit "$DRILL_STATUS"
