#!/usr/bin/env bash
# ============================================================================
# KAPI: blueprint-check
# Zorladığı kural: docs/blueprint/README.md — dondurulmuş kaynak düzenlenmez
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

SRC="BLUEPRINT.md"
FROZEN="docs/blueprint/boreas-blueprint-v1.1.md"
FAIL=0

echo "▶ blueprint-check — dondurulmuş kaynak bütünlüğü"

for f in "$SRC" "$FROZEN"; do
  if [ ! -f "$f" ]; then
    printf '  ✗ %s bulunamadı\n' "$f"
    FAIL=1
  fi
done

if [ "$FAIL" -eq 0 ]; then
  if diff -q "$SRC" "$FROZEN" >/dev/null 2>&1; then
    printf '  ✓ kopya birebir (%s)\n' "$(shasum -a 256 "$FROZEN" | cut -c1-16)…"
  else
    printf '  ✗ FARK VAR — biri düzenlenmiş\n\n'
    diff -u "$FROZEN" "$SRC" | head -40
    printf '\n  Blueprint dondurulmuştur. Sapma ADR ile kaydedilir, dosya düzenlenmez.\n'
    printf '  Bkz. docs/blueprint/README.md\n'
    FAIL=1
  fi
fi

echo
[ "$FAIL" -eq 0 ] && echo "✓ blueprint-check PASS" || echo "✗ blueprint-check FAIL"
exit "$FAIL"
