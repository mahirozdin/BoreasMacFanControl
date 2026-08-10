#!/usr/bin/env bash
# ============================================================================
# GATE: gate-i18n
# Enforces: AGENTS.md §2.8 Y1 (no hard coded text), Y2 (comment required),
#           Y4 (no half translated language), the diagnostic honesty rule,
#           and the TRANSLATORS.md origin declaration (ADR 0016 addendum)
# ADR: 0016-language-scope.md
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-i18n — hard coded user facing text"
require_tools git grep xargs

UI=$(tracked 'App/Sources/' | grep '\.swift$' || true)
COUNT=$(printf '%s\n' "$UI" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  skip "no App/Sources Swift sources — activates in P6"
else
  note "UI files scanned: $COUNT"
  PATTERN='(Text|Label|Button|Toggle|Picker|TextField|Menu|Section|navigationTitle|help|accessibilityLabel)\([[:space:]]*"[^"]{2,}"'
  if RAW=$(grep_files "$UI" -nHE "$PATTERN"); then
    HITS=$(printf '%s\n' "$RAW" | grep -vE 'verbatim:|systemImage:|String\(localized:|LocalizedStringKey|//' || true)
    if [ -n "$HITS" ]; then
      fail "hard coded user facing text (Y1):"
      printf '%s\n' "$HITS" | head -15 | sed 's/^/      /'
      note 'use String(localized: "…", comment: "…")'
    else
      ok "no hard coded user facing text"
    fi
  else
    ok "no hard coded user facing text"
  fi
fi

# ---------------------------------------------------------------------------
# Y2 / Y4 / the honesty rule / the origin declaration — String Catalog
# The checks themselves are Python, in check-catalog.py, because they are
# about the shape of a JSON document and shell is the wrong instrument.
#
# TRANSLATORS.md is passed in rather than found there so the drill can point
# the same code at a deliberately broken copy without touching the real file.
# ---------------------------------------------------------------------------
CAT=$(tracked '*.xcstrings' | head -1)
if [ -z "$CAT" ]; then
  skip "no String Catalog — arrives in P6.11"
else
  require_tools python3
  python3 scripts/gates/check-catalog.py "$CAT" TRANSLATORS.md || GATE_FAIL=1
fi

gate_result "gate-i18n"
