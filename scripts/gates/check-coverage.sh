#!/usr/bin/env bash
# ============================================================================
# KAPI: gate-coverage
# Zorladığı kalite hedefi: ARCHITECTURE.md §3 — Core kapsamı >= %85
#
# NEDEN YALNIZCA Core:
#   Core, kontrol motorunun yaşadığı yer ve donanımdan bağımsız olarak test
#   edilebilen tek katman. HardwareKit'in Live uygulamaları yalnızca gerçek
#   donanımda çalışıyor; onlara kapsam eşiği koymak, ulaşılamayan satırlar
#   için sahte test yazmaya zorlar.
#
# ÖNEMLİ: birçok kurulum kapsamı RAPORLAR ama ZORLAMAZ. Bu script eşiği
# gerçekten uygular ve altındaysa sıfırdan farklı çıkar.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

THRESHOLD=${BOREAS_COVERAGE_THRESHOLD:-85}

echo "▶ gate-coverage — Core kapsamı (eşik %$THRESHOLD)"
require_tools git

if [ ! -f Packages/Core/Package.swift ]; then
  skip "Packages/Core yok"
  gate_result "gate-coverage"
  exit $?
fi

require_tools swift xcrun python3

cd Packages/Core || exit 1
if ! swift test --enable-code-coverage >/tmp/boreas-cov-build.log 2>&1; then
  fail "testler geçmedi — kapsam ölçülemez"
  tail -5 /tmp/boreas-cov-build.log | sed 's/^/      /'
  cd ../.. || exit 1
  gate_result "gate-coverage"
  exit $?
fi

BIN_PATH=$(swift build --show-bin-path 2>/dev/null)
PROFDATA="$BIN_PATH/codecov/default.profdata"
TEST_BIN=$(find "$BIN_PATH" -name '*.xctest' -maxdepth 1 2>/dev/null | head -1)
[ -n "$TEST_BIN" ] && TEST_BIN="$TEST_BIN/Contents/MacOS/$(basename "$TEST_BIN" .xctest)"

cd ../.. || exit 1

if [ ! -f "$PROFDATA" ] || [ ! -f "$TEST_BIN" ]; then
  fail "kapsam verisi üretilmedi — kapı doğrulama yapamadı (sessiz geçiş yok)"
  note "profdata: $PROFDATA"
  note "test ikilisi: $TEST_BIN"
  gate_result "gate-coverage"
  exit $?
fi

REPORT=$(xcrun llvm-cov export -summary-only \
  -instr-profile "$PROFDATA" "$TEST_BIN" 2>/dev/null)

PERCENT=$(printf '%s' "$REPORT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("ERROR"); sys.exit(0)
total = 0
covered = 0
for item in data.get("data", []):
    for entry in item.get("files", []):
        path = entry.get("filename", "")
        # Yalnızca Core kaynakları; test dosyaları ve bağımlılıklar hariç.
        if "/Packages/Core/Sources/" not in path:
            continue
        lines = entry.get("summary", {}).get("lines", {})
        total += lines.get("count", 0)
        covered += lines.get("covered", 0)
if total == 0:
    print("ERROR")
else:
    print(f"{covered * 100 / total:.1f}")
')

if [ "$PERCENT" = "ERROR" ] || [ -z "$PERCENT" ]; then
  fail "kapsam yüzdesi hesaplanamadı — sessiz geçiş yok"
  gate_result "gate-coverage"
  exit $?
fi

MEETS=$(python3 -c "print(1 if float('$PERCENT') >= $THRESHOLD else 0)")
if [ "$MEETS" = "1" ]; then
  ok "Core satır kapsamı %$PERCENT (eşik %$THRESHOLD)"
else
  fail "Core satır kapsamı %$PERCENT — eşik %$THRESHOLD"
  note "kapsanmayan dosyalar:"
  printf '%s' "$REPORT" | python3 -c '
import json, sys
data = json.load(sys.stdin)
rows = []
for item in data.get("data", []):
    for entry in item.get("files", []):
        path = entry.get("filename", "")
        if "/Packages/Core/Sources/" not in path:
            continue
        lines = entry.get("summary", {}).get("lines", {})
        if lines.get("count", 0) == 0:
            continue
        pct = lines.get("covered", 0) * 100 / lines["count"]
        rows.append((pct, path.split("/Sources/")[-1]))
for pct, name in sorted(rows)[:6]:
    print(f"        {pct:5.1f}%  {name}")
'
fi

gate_result "gate-coverage"
