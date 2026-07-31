#!/usr/bin/env bash
# ============================================================================
# KAPI: gate-i18n
# Zorladığı değişmezler: AGENTS.md §2.8 Y1 (sabit metin yasağı), Y2 (comment)
# ADR: 0016-language-scope.md
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-i18n — sabit yazılmış kullanıcı metni"
require_tools git grep xargs

UI=$(tracked 'App/Sources/*.swift App/Sources/**/*.swift')
COUNT=$(printf '%s\n' "$UI" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  skip "App/Sources Swift kaynağı yok — P6'da etkinleşecek"
else
  note "taranan UI dosyası: $COUNT"
  PATTERN='(Text|Label|Button|Toggle|Picker|TextField|Menu|Section|navigationTitle|help|accessibilityLabel)\([[:space:]]*"[^"]{2,}"'
  if RAW=$(grep_files "$UI" -nHE "$PATTERN"); then
    HITS=$(printf '%s\n' "$RAW" | grep -vE 'verbatim:|systemImage:|String\(localized:|LocalizedStringKey|//' || true)
    if [ -n "$HITS" ]; then
      fail "sabit yazılmış kullanıcı metni (Y1):"
      printf '%s\n' "$HITS" | head -15 | sed 's/^/      /'
      note 'String(localized: "…", comment: "…") kullan'
    else
      ok "sabit yazılmış kullanıcı metni yok"
    fi
  else
    ok "sabit yazılmış kullanıcı metni yok"
  fi
fi

# ---------------------------------------------------------------------------
# Y2 — String Catalog: 5 dil mevcut + her dizenin comment alanı dolu
# ---------------------------------------------------------------------------
CAT=$(tracked '*.xcstrings' | head -1)
if [ -z "$CAT" ]; then
  skip "String Catalog yok — P6'da oluşacak"
else
  for lang in en tr ru es zh-Hans; do
    if grep -q "\"$lang\"" "$CAT" 2>/dev/null; then
      ok "dil mevcut: $lang"
    else
      fail "String Catalog'da eksik dil: $lang"
    fi
  done
  require_tools python3
  python3 - "$CAT" <<'PY' || GATE_FAIL=1
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  ✗ String Catalog ayrıştırılamadı: {e}"); sys.exit(1)
missing = [k for k, v in data.get("strings", {}).items() if not v.get("comment")]
if missing:
    print(f"  ✗ comment alanı boş dize: {len(missing)} adet (Y2)")
    for k in missing[:10]:
        print(f"      {k}")
    sys.exit(1)
print("  ✓ tüm dizelerin comment alanı dolu")
PY
fi

gate_result "gate-i18n"
