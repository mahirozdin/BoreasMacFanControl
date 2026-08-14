#!/usr/bin/env bash
# ============================================================================
# P8.09 — the release gates in ARCHITECTURE.md §10, checked. Eight of them are
# the ones that document names; the ninth was added by P8.11 after v0.1.0
# shipped with no application icon and a blank disk image window.
#
# **The point of this script is what it refuses to claim.** Five of the eight
# gates are machine-checkable and are run here. Three are not:
#
#   - the `kill -9` smoke test needs a real Mac with the helper installed, and
#     it drives the fans, so it is opt-in rather than a side effect of asking
#     for a status report
#   - the sleep and wake test cannot be automated at all — something has to put
#     the machine to sleep and watch what the fans do (release blocker B5)
#   - "the README tested hardware section is honest" is a judgement, and no
#     script has an opinion about honesty
#
# An unverified gate is reported as unverified and **fails the run**. Reaching
# zero requires either running the thing or attesting to it deliberately, which
# is the same rule the run log has always had: no checkbox without evidence.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

PASSED=0
FAILED=0
UNVERIFIED=0

pass() { printf '  ✓ %s\n' "$*"; PASSED=$((PASSED + 1)); }
fail() { printf '  ✗ %s\n' "$*"; FAILED=$((FAILED + 1)); }
unver() {
  printf '  ? %s\n' "$1"
  printf '      %s\n' "$2"
  UNVERIFIED=$((UNVERIFIED + 1))
}

echo "▶ release-gates — ARCHITECTURE.md §10"
echo ""

# --- 1. invariant tests -----------------------------------------------------
# Named separately from the suite because they are the gates on G1–G6, and a
# release that ran "the tests" without them would have proven nothing about
# safety. Their presence is checked too: a renamed suite would otherwise make
# this pass by finding nothing to run.
INVARIANTS=$(ls Packages/Core/Tests/CoreTests/{SafetyChain,WatchdogPolicy,Curve}Tests.swift 2>/dev/null | wc -l | tr -d ' ')
if [ "$INVARIANTS" -lt 3 ]; then
  fail "invariant test suites: expected 3, found $INVARIANTS — has one been renamed?"
elif make test >/tmp/rg-test.log 2>&1; then
  pass "invariant tests pass ($(grep -c 'Test run with' /tmp/rg-test.log) packages)"
else
  fail "tests failed — see /tmp/rg-test.log"
fi

# --- 2. Core coverage -------------------------------------------------------
if make gate-coverage >/tmp/rg-cov.log 2>&1; then
  pass "$(grep -oE 'Core line coverage [0-9.]+%.*' /tmp/rg-cov.log | head -1)"
else
  fail "Core coverage below the threshold — see /tmp/rg-cov.log"
fi

# --- 3. make check ----------------------------------------------------------
if make check >/tmp/rg-check.log 2>&1; then
  pass "make check fully green ($(grep -c 'PASS$' /tmp/rg-check.log) gates)"
else
  fail "a gate is red — see /tmp/rg-check.log"
fi

# --- 4. kill -9 on real hardware -------------------------------------------
if [ "${RUN_SMOKE:-}" = "1" ]; then
  if make smoke >/tmp/rg-smoke.log 2>&1; then
    pass "kill -9 smoke test passed on this machine"
  else
    fail "the smoke test failed — see /tmp/rg-smoke.log"
  fi
else
  unver "kill -9 smoke test on real hardware" \
    "needs a Mac with the helper installed, and it drives the fans: RUN_SMOKE=1 to run it"
fi

# --- 5. sleep and wake ------------------------------------------------------
if [ -n "${ATTESTED_SLEEP:-}" ]; then
  pass "sleep and wake test attested: $ATTESTED_SLEEP"
else
  unver "sleep and wake smoke test (release blocker B5)" \
    "cannot be automated — sleep the machine, wake it, confirm the fans returned to firmware, then set ATTESTED_SLEEP='<what you saw>'"
fi

# --- 6. notarisation --------------------------------------------------------
# Asked of the Release workflow rather than re-run: a notarisation round trip
# per status check would be minutes of Apple's time for an answer already on
# record. The last run's conclusion is the evidence.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  LAST=$(gh run list --workflow=Release --limit 1 \
    --json conclusion,displayTitle,url \
    -q '.[] | "\(.conclusion)\t\(.url)"' 2>/dev/null)
  if [ -z "$LAST" ]; then
    unver "notarisation" "no Release workflow run found to read a verdict from"
  elif [ "$(printf '%s' "$LAST" | cut -f1)" = "success" ]; then
    pass "notarisation succeeded in the last Release run"
    printf '      %s\n' "$(printf '%s' "$LAST" | cut -f2)"
  else
    fail "the last Release run did not succeed — $(printf '%s' "$LAST" | cut -f2)"
  fi
else
  unver "notarisation" "gh is unavailable or unauthenticated, so the Release run cannot be read"
fi

# --- 7. five languages and the layout test ---------------------------------
if make gate-i18n >/tmp/rg-i18n.log 2>&1 && make layout >/tmp/rg-layout.log 2>&1; then
  pass "five languages complete and the pseudo-locale layout test passes"
else
  fail "localisation or layout is red — see /tmp/rg-i18n.log and /tmp/rg-layout.log"
fi

# --- 8. the README's honesty ------------------------------------------------
# Two halves: that the section exists and says what it must, which is
# checkable, and that what it says is true, which is not.
if grep -q "Tested hardware" README.md && grep -q "not verified" README.md; then
  if [ -n "${ATTESTED_README:-}" ]; then
    pass "README tested-hardware section is honest, attested: $ATTESTED_README"
  else
    unver "the README tested-hardware section is honest (blocker B6)" \
      "the section exists and admits unverified hardware, but whether it *overstates* is a judgement: read it and set ATTESTED_README='<who read it, when>'"
  fi
else
  fail "README has no honest tested-hardware section (B6)"
fi

# --- 9. the shipped image presents itself -----------------------------------
# **This gate exists because nothing caught the thing it checks.** M08 designed
# an icon in 2026-08-03 and closed. P8.03 built a disk image and closed. Both
# were done; the icon was never wired into the bundle and the image was never
# given a window, so v0.1.0 shipped with the generic placeholder application
# icon and three loose items on a blank background. Every gate was green. Found
# by the project owner downloading the release and looking at it (P8.11, P8.12).
#
# What is checkable here is presence, and only presence: an icns inside the
# built bundle, the Info.plist key that points at it, and the two committed
# assets the disk image window is made of. Whether the artwork is any good, or
# whether the arrow points at the right place, is not a thing a script knows.
ICON_APP="${ICON_APP:-build/release/Build/Products/Release/Boreas.app}"
ICON_OK=1
if [ -d "$ICON_APP" ]; then
  ICON_KEY=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" \
    "$ICON_APP/Contents/Info.plist" 2>/dev/null || true)
  [ -n "$ICON_KEY" ] || { echo "      no CFBundleIconFile in $ICON_APP"; ICON_OK=0; }
  [ -f "$ICON_APP/Contents/Resources/${ICON_KEY:-missing}.icns" ] \
    || { echo "      no ${ICON_KEY:-?}.icns in the bundle"; ICON_OK=0; }
else
  echo "      $ICON_APP not built — set ICON_APP=<path> or build first"
  ICON_OK=0
fi
for asset in Design/dmg/background.png Design/dmg/background@2x.png Design/dmg/DS_Store; do
  [ -f "$asset" ] || { echo "      missing disk image asset: $asset"; ICON_OK=0; }
done
if [ "$ICON_OK" -eq 1 ]; then
  pass "the bundle carries its icon and the disk image carries its window"
else
  fail "the shipped image does not present itself — see the lines above"
fi

echo ""
echo "  $PASSED passed · $FAILED failed · $UNVERIFIED unverified"
if [ "$FAILED" -gt 0 ]; then
  echo "✗ release-gates FAIL — a gate is red"
  exit 1
fi
if [ "$UNVERIFIED" -gt 0 ]; then
  echo "✗ release-gates INCOMPLETE — $UNVERIFIED gate(s) unverified, which is not the same as passing"
  exit 1
fi
echo "✓ release-gates PASS — all nine satisfied"
