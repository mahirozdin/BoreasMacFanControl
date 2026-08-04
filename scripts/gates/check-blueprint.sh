#!/usr/bin/env bash
# ============================================================================
# GATE: blueprint-check
# Enforces: docs/blueprint/README.md — the frozen source is never edited
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

SRC="BLUEPRINT.md"
FROZEN="docs/blueprint/boreas-blueprint-v1.1.md"
FAIL=0

echo "▶ blueprint-check — frozen source integrity"

for f in "$SRC" "$FROZEN"; do
  if [ ! -f "$f" ]; then
    printf '  ✗ %s not found\n' "$f"
    FAIL=1
  fi
done

if [ "$FAIL" -eq 0 ]; then
  if diff -q "$SRC" "$FROZEN" >/dev/null 2>&1; then
    printf '  ✓ copy identical (%s)\n' "$(shasum -a 256 "$FROZEN" | cut -c1-16)…"
  else
    printf '  ✗ THEY DIFFER — one of them was edited\n\n'
    diff -u "$FROZEN" "$SRC" | head -40
    printf '\n  The blueprint is frozen. A deviation is recorded as an ADR; the file is never edited.\n'
    printf '  See docs/blueprint/README.md\n'
    FAIL=1
  fi
fi

echo
[ "$FAIL" -eq 0 ] && echo "✓ blueprint-check PASS" || echo "✗ blueprint-check FAIL"
exit "$FAIL"
