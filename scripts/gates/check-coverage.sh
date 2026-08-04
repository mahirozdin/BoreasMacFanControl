#!/usr/bin/env bash
# ============================================================================
# GATE: gate-coverage
# Enforces the quality target: ARCHITECTURE.md §3 — Core coverage >= 85%
#
# WHY Core ONLY:
#   Core is where the control engine lives and the only layer testable
#   without hardware. HardwareKit's Live implementations only run on real
#   hardware; putting a coverage threshold on them forces fake tests for
#   unreachable lines.
#
# IMPORTANT: many setups REPORT coverage but do not ENFORCE it. This script
# actually applies the threshold and exits nonzero below it.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

THRESHOLD=${BOREAS_COVERAGE_THRESHOLD:-85}

echo "▶ gate-coverage — Core coverage (threshold ${THRESHOLD}%)"
require_tools git

if [ ! -f Packages/Core/Package.swift ]; then
  skip "no Packages/Core"
  gate_result "gate-coverage"
  exit $?
fi

require_tools swift xcrun python3

cd Packages/Core || exit 1
if ! swift test --enable-code-coverage >/tmp/boreas-cov-build.log 2>&1; then
  fail "tests failed — coverage cannot be measured"
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
  fail "no coverage data produced — the gate could not verify (no silent pass)"
  note "profdata: $PROFDATA"
  note "test binary: $TEST_BIN"
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
        # Core sources only; test files and dependencies excluded.
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
  fail "the coverage percentage could not be computed — no silent pass"
  gate_result "gate-coverage"
  exit $?
fi

MEETS=$(python3 -c "print(1 if float('$PERCENT') >= $THRESHOLD else 0)")
if [ "$MEETS" = "1" ]; then
  ok "Core line coverage ${PERCENT}% (threshold ${THRESHOLD}%)"
else
  fail "Core line coverage ${PERCENT}% — threshold ${THRESHOLD}%"
  note "least covered files:"
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
