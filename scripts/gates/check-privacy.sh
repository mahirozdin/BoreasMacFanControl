#!/usr/bin/env bash
# ============================================================================
# KAPI: gate-privacy
# Zorladığı değişmezler: AGENTS.md §2.6 P1 (sıfır telemetri), P2 (ağ yok)
# ADR: 0014-zero-telemetry.md
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-privacy — telemetri ve ağ izi"
require_tools git grep xargs

SWIFT=$(tracked '*.swift')
COUNT=$(printf '%s\n' "$SWIFT" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  skip "Swift kaynağı yok — P2'de etkinleşecek"
else
  note "taranan Swift dosyası: $COUNT"

  # -------------------------------------------------------------------------
  # P1 — telemetri / analitik / çökme raporlama SDK izi
  # -------------------------------------------------------------------------
  TELEMETRY='(Analytics|Telemetry|Crashlytics|Mixpanel|Amplitude|Firebase|AppCenter|Bugsnag|advertisingIdentifier|ASIdentifierManager|trackEvent|logEvent)'
  if HITS=$(grep_files "$SWIFT" -nHE "$TELEMETRY"); then
    fail "telemetri/analitik izi bulundu (P1)"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "telemetri/analitik izi yok"
  fi

  # -------------------------------------------------------------------------
  # P2 — ağ kullanımı yalnızca izinli modüllerde
  # -------------------------------------------------------------------------
  NET='(URLSession|NWConnection|import[[:space:]]+Network)'
  ALLOWED_PATH='(App/Sources/Updates/|App/Sources/Automation/|Tests/)'
  if NETFILES=$(grep_files "$SWIFT" -lE "$NET"); then
    OFFENDERS=$(printf '%s\n' "$NETFILES" | grep -vE "$ALLOWED_PATH" || true)
    if [ -n "$OFFENDERS" ]; then
      fail "izinli olmayan modülde ağ API'si (P2):"
      printf '%s\n' "$OFFENDERS" | sed 's/^/      /'
      note "ağ yalnızca App/Sources/Updates/ ve App/Sources/Automation/ altında"
    else
      ok "ağ API'si yalnızca izinli modüllerde"
    fi
  else
    ok "hiçbir yerde ağ API'si yok"
  fi

  # -------------------------------------------------------------------------
  # P3 — log satırlarında kişisel veri riski
  # -------------------------------------------------------------------------
  if HITS=$(grep_files "$SWIFT" -nHE '(NSUserName|NSFullUserName)\(\)'); then
    warn "kullanıcı kimliği API'si — log'a sızmadığını doğrula (P3)"
    printf '%s\n' "$HITS" | head -5 | sed 's/^/      /'
  else
    ok "kullanıcı kimliği API'si kullanımı yok"
  fi
fi

# ---------------------------------------------------------------------------
# Daemon entitlement'ında ağ yetkisi olamaz (M6)
# ---------------------------------------------------------------------------
ENTS=$(tracked '*.entitlements')
if [ -n "$ENTS" ]; then
  DAEMON_ENTS=$(printf '%s\n' "$ENTS" | grep '^Daemon/' || true)
  if [ -n "$DAEMON_ENTS" ]; then
    if grep_files "$DAEMON_ENTS" -lE 'network' >/dev/null; then
      fail "daemon entitlement'ında ağ yetkisi (M6)"
    else
      ok "daemon entitlement'ında ağ yetkisi yok"
    fi
  fi
fi

gate_result "gate-privacy"
