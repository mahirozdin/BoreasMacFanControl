#!/usr/bin/env bash
# ============================================================================
# KAPI: gate-daemon
# Zorladığı değişmezler: ARCHITECTURE.md M4 (XPC yüzeyi), M5 (config okumaz),
#                        M6 (ağ yok), G5 (imza doğrulaması)
# ADR: 0007-privilege-split.md, 0008-smappservice-xpc.md
#
# Daemon root olarak çalışır. Yüzeyi ne kadar dar olursa saldırı yüzeyi o kadar
# küçüktür. Bu kapı, yüzeyin fark ettirmeden genişlemesini önler.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-daemon — ayrıcalıklı yüzey sınırları"
require_tools git grep awk sort xargs

DAEMON=$(tracked 'Daemon/*.swift Daemon/**/*.swift')
COUNT=$(printf '%s\n' "$DAEMON" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  skip "Daemon kaynağı yok — P3'te oluşacak"
else
  note "taranan daemon dosyası: $COUNT"

  # -------------------------------------------------------------------------
  # M4 — XPC protokolü yalnızca dört metot içerir
  # -------------------------------------------------------------------------
  PROTO=$(tracked 'Packages/SharedIPC/Sources/**/*.swift')
  if [ -n "$PROTO" ]; then
    ALLOWED='^(describeFans|applyTargets|releaseToFirmware|heartbeat)$'
    if FUNCS=$(grep_files "$PROTO" -hoE '^[[:space:]]*func[[:space:]]+[A-Za-z0-9_]+'); then
      EXTRA=$(printf '%s\n' "$FUNCS" | awk '{print $2}' | sort -u | grep -vE "$ALLOWED" || true)
      if [ -n "$EXTRA" ]; then
        fail "XPC yüzeyinde izinsiz metot (M4) — genişletmek ADR gerektirir:"
        printf '%s\n' "$EXTRA" | sed 's/^/      /'
      else
        ok "XPC yüzeyi dört metotla sınırlı"
      fi
    fi
  fi

  # -------------------------------------------------------------------------
  # M5 — daemon yapılandırma/dosya okumaz
  # -------------------------------------------------------------------------
  CONFIG_IO='(JSONDecoder|JSONSerialization|PropertyListDecoder|contentsOfFile|Data\(contentsOf:)'
  if HITS=$(grep_files "$DAEMON" -nHE "$CONFIG_IO"); then
    fail "daemon dosya/yapılandırma okuyor (M5)"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "daemon yapılandırma okumuyor"
  fi

  # -------------------------------------------------------------------------
  # M6 — daemon ağ kullanmaz
  # -------------------------------------------------------------------------
  if HITS=$(grep_files "$DAEMON" -nHE '(URLSession|import[[:space:]]+Network|NWConnection)'); then
    fail "daemon ağ API'si kullanıyor (M6)"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "daemon ağ kullanmıyor"
  fi

  # -------------------------------------------------------------------------
  # Alt süreç yasağı — ayrıcalık yükseltme riski
  # -------------------------------------------------------------------------
  if HITS=$(grep_files "$DAEMON" -nHE '(Process\(\)|posix_spawn|NSTask|execv)'); then
    fail "daemon alt süreç başlatıyor — ayrıcalık yükseltme riski"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "daemon alt süreç başlatmıyor"
  fi

  # -------------------------------------------------------------------------
  # G5 — imza doğrulaması mevcut olmalı
  # -------------------------------------------------------------------------
  if grep_files "$DAEMON" -lE '(SecCodeCheckValidity|SecRequirementCreateWithString|auditToken)' >/dev/null; then
    ok "XPC imza doğrulaması mevcut"
  else
    fail "XPC imza doğrulaması bulunamadı (G5)"
  fi
fi

gate_result "gate-daemon"
