#!/usr/bin/env bash
# ============================================================================
# GATE: gate-layers
# Enforces: ARCHITECTURE.md M1 (Core purity), M2 (Mock coverage),
#           AGENTS.md T5 (.xcodeproj is never committed)
# ADR: 0012-core-layer-purity.md, 0011-hardware-abstraction.md
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-layers — layer purity"
require_tools git grep awk sort xargs

# ---------------------------------------------------------------------------
# M1 — Core depends only on Foundation
# ---------------------------------------------------------------------------
CORE=$(tracked 'Packages/Core/Sources/' | grep '\.swift$' || true)
CORE_N=$(printf '%s\n' "$CORE" | grep -c . || true)

if [ "$CORE_N" -eq 0 ]; then
  skip "no Packages/Core sources — arrives in P2"
else
  note "Core files scanned: $CORE_N"
  BANNED='^[[:space:]]*import[[:space:]]+(IOKit|SwiftUI|AppKit|Cocoa|Carbon|ServiceManagement|UserNotifications|WidgetKit|AppIntents|Charts|Network)\b'
  if HITS=$(grep_files "$CORE" -nHE "$BANNED"); then
    fail "forbidden import inside Core (M1) — Core depends only on Foundation"
    printf '%s\n' "$HITS" | head -15 | sed 's/^/      /'
  else
    ok "Core is pure: no forbidden imports"
  fi

  # Force unwrap ban (AGENTS.md §6.2)
  if RAW=$(grep_files "$CORE" -nHE '[a-zA-Z0-9_)\]]![[:space:]]*(\.|$|\))'); then
    HITS=$(printf '%s\n' "$RAW" | grep -vE '!=|//' || true)
    if [ -n "$HITS" ]; then
      fail "force unwrap (!) found inside Core"
      printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
    else
      ok "Core: no force unwraps"
    fi
  else
    ok "Core: no force unwraps"
  fi
fi

# ---------------------------------------------------------------------------
# M2 — every hardware protocol must have a Live + Mock implementation
# ---------------------------------------------------------------------------
PROTOS=$(tracked 'Packages/HardwareKit/Sources/HardwareKit/Protocols/' | grep '\.swift$' || true)
HW=$(tracked 'Packages/HardwareKit/Sources/' | grep '\.swift$' || true)

if [ -z "$PROTOS" ]; then
  skip "no HardwareKit protocols — arrive in P2"
else
  MISSING=""
  if NAMES=$(grep_files "$PROTOS" -hoE '^[[:space:]]*(public[[:space:]]+)?protocol[[:space:]]+[A-Za-z0-9_]+'); then
    for proto in $(printf '%s\n' "$NAMES" | awk '{print $NF}' | sort -u); do
      grep_files "$HW" -lE "(struct|final class|actor)[[:space:]]+Mock${proto}\b" >/dev/null \
        || MISSING="$MISSING Mock${proto}"
      grep_files "$HW" -lE "(struct|final class|actor)[[:space:]]+Live${proto}\b" >/dev/null \
        || MISSING="$MISSING Live${proto}"
    done
  fi
  if [ -n "$MISSING" ]; then
    fail "missing implementation for a protocol (M2):$MISSING"
  else
    ok "every protocol has a Live + Mock implementation"
  fi
fi

# ---------------------------------------------------------------------------
# T5 — the generated project file is not committed
# ---------------------------------------------------------------------------
if git ls-files 2>/dev/null | grep -qE '\.xcodeproj/'; then
  fail ".xcodeproj is committed (T5) — it is generated from project.yml"
else
  ok ".xcodeproj is not committed"
fi

gate_result "gate-layers"
