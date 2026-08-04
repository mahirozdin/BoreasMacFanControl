#!/usr/bin/env bash
# ============================================================================
# GATE: gate-privacy
# Enforces: AGENTS.md §2.6 P1 (zero telemetry), P2 (no network)
# ADR: 0014-zero-telemetry.md
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-privacy — telemetry and network traces"
require_tools git grep xargs

SWIFT=$(tracked '*.swift')
COUNT=$(printf '%s\n' "$SWIFT" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  skip "no Swift sources — activates in P2"
else
  note "Swift files scanned: $COUNT"

  # -------------------------------------------------------------------------
  # P1 — telemetry / analytics / crash reporting SDK traces
  # -------------------------------------------------------------------------
  TELEMETRY='(Analytics|Telemetry|Crashlytics|Mixpanel|Amplitude|Firebase|AppCenter|Bugsnag|advertisingIdentifier|ASIdentifierManager|trackEvent|logEvent)'
  if HITS=$(grep_files "$SWIFT" -nHE "$TELEMETRY"); then
    fail "telemetry/analytics trace found (P1)"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "no telemetry/analytics traces"
  fi

  # -------------------------------------------------------------------------
  # P2 — network use only in permitted modules
  # -------------------------------------------------------------------------
  NET='(URLSession|NWConnection|import[[:space:]]+Network)'
  ALLOWED_PATH='(App/Sources/Updates/|App/Sources/Automation/|Tests/)'
  if NETFILES=$(grep_files "$SWIFT" -lE "$NET"); then
    OFFENDERS=$(printf '%s\n' "$NETFILES" | grep -vE "$ALLOWED_PATH" || true)
    if [ -n "$OFFENDERS" ]; then
      fail "network API in a module that is not permitted (P2):"
      printf '%s\n' "$OFFENDERS" | sed 's/^/      /'
      note "network only under App/Sources/Updates/ and App/Sources/Automation/"
    else
      ok "network APIs only in permitted modules"
    fi
  else
    ok "no network API anywhere"
  fi

  # -------------------------------------------------------------------------
  # P3 — personal data risk in log lines
  # -------------------------------------------------------------------------
  if HITS=$(grep_files "$SWIFT" -nHE '(NSUserName|NSFullUserName)\(\)'); then
    warn "user identity API — verify it never reaches a log (P3)"
    printf '%s\n' "$HITS" | head -5 | sed 's/^/      /'
  else
    ok "no user identity API use"
  fi
fi

# ---------------------------------------------------------------------------
# The daemon entitlements may not include network (M6)
# ---------------------------------------------------------------------------
ENTS=$(tracked '*.entitlements')
if [ -n "$ENTS" ]; then
  DAEMON_ENTS=$(printf '%s\n' "$ENTS" | grep '^Daemon/' || true)
  if [ -n "$DAEMON_ENTS" ]; then
    if grep_files "$DAEMON_ENTS" -lE 'network' >/dev/null; then
      fail "network entitlement on the daemon (M6)"
    else
      ok "no network entitlement on the daemon"
    fi
  fi
fi

gate_result "gate-privacy"
