#!/usr/bin/env bash
# ============================================================================
# KAPI: gate-layers
# Zorladığı değişmezler: ARCHITECTURE.md M1 (Core saflığı), M2 (Mock kapsamı),
#                        AGENTS.md T5 (.xcodeproj commit edilmez)
# ADR: 0012-core-layer-purity.md, 0011-hardware-abstraction.md
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-layers — katman saflığı"
require_tools git grep awk sort xargs

# ---------------------------------------------------------------------------
# M1 — Core yalnızca Foundation'a bağlanır
# ---------------------------------------------------------------------------
CORE=$(tracked 'Packages/Core/Sources/' | grep '\.swift$' || true)
CORE_N=$(printf '%s\n' "$CORE" | grep -c . || true)

if [ "$CORE_N" -eq 0 ]; then
  skip "Packages/Core kaynağı yok — P2'de oluşacak"
else
  note "taranan Core dosyası: $CORE_N"
  BANNED='^[[:space:]]*import[[:space:]]+(IOKit|SwiftUI|AppKit|Cocoa|Carbon|ServiceManagement|UserNotifications|WidgetKit|AppIntents|Charts|Network)\b'
  if HITS=$(grep_files "$CORE" -nHE "$BANNED"); then
    fail "Core içinde yasaklı import (M1) — Core yalnızca Foundation'a bağlanır"
    printf '%s\n' "$HITS" | head -15 | sed 's/^/      /'
  else
    ok "Core saf: yasaklı import yok"
  fi

  # Zorla açma yasağı (AGENTS.md §6.2)
  if RAW=$(grep_files "$CORE" -nHE '[a-zA-Z0-9_)\]]![[:space:]]*(\.|$|\))'); then
    HITS=$(printf '%s\n' "$RAW" | grep -vE '!=|//' || true)
    if [ -n "$HITS" ]; then
      fail "Core içinde zorla açma (!) bulundu"
      printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
    else
      ok "Core: zorla açma yok"
    fi
  else
    ok "Core: zorla açma yok"
  fi
fi

# ---------------------------------------------------------------------------
# M2 — Her donanım protokolünün Live + Mock uygulaması olmalı
# ---------------------------------------------------------------------------
PROTOS=$(tracked 'Packages/HardwareKit/Sources/HardwareKit/Protocols/' | grep '\.swift$' || true)
HW=$(tracked 'Packages/HardwareKit/Sources/' | grep '\.swift$' || true)

if [ -z "$PROTOS" ]; then
  skip "HardwareKit protokolleri yok — P2'de oluşacak"
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
    fail "protokol için eksik uygulama (M2):$MISSING"
  else
    ok "her protokolün Live + Mock uygulaması var"
  fi
fi

# ---------------------------------------------------------------------------
# T5 — üretilen proje dosyası commit edilmemiş
# ---------------------------------------------------------------------------
if git ls-files 2>/dev/null | grep -qE '\.xcodeproj/'; then
  fail ".xcodeproj commit edilmiş (T5) — project.yml'den üretilir"
else
  ok ".xcodeproj commit edilmemiş"
fi

gate_result "gate-layers"
