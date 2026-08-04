#!/usr/bin/env bash
# ============================================================================
# GATE: gate-i18n
# Enforces: AGENTS.md §2.8 Y1 (no hard coded text), Y2 (comment required)
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
# Y2 — String Catalog: all five languages present + every string has a comment
# ---------------------------------------------------------------------------
CAT=$(tracked '*.xcstrings' | head -1)
if [ -z "$CAT" ]; then
  skip "no String Catalog — arrives in P6"
else
  for lang in en tr ru es zh-Hans; do
    if grep -q "\"$lang\"" "$CAT" 2>/dev/null; then
      ok "language present: $lang"
    else
      fail "language missing from the String Catalog: $lang"
    fi
  done
  require_tools python3
  python3 - "$CAT" <<'PY' || GATE_FAIL=1
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  ✗ the String Catalog could not be parsed: {e}"); sys.exit(1)
missing = [k for k, v in data.get("strings", {}).items() if not v.get("comment")]
if missing:
    print(f"  ✗ strings with an empty comment field: {len(missing)} (Y2)")
    for k in missing[:10]:
        print(f"      {k}")
    sys.exit(1)
print("  ✓ every string carries a comment")
PY
fi

gate_result "gate-i18n"
