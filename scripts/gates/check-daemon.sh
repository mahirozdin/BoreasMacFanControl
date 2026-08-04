#!/usr/bin/env bash
# ============================================================================
# GATE: gate-daemon
# Enforces: ARCHITECTURE.md M4 (XPC surface), M5 (reads no configuration),
#           M6 (no network), G5 (signature verification)
# ADR: 0007-privilege-split.md, 0008-smappservice-xpc.md
#
# The daemon runs as root. The narrower its surface, the smaller the attack
# surface. This gate keeps the surface from widening unnoticed.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-daemon — privileged surface limits"
require_tools git grep awk sort xargs


# ---------------------------------------------------------------------------
# M4 — the XPC protocol contains exactly four methods
#
# This check runs INDEPENDENTLY of the daemon sources: the surface is bounded
# the moment the protocol is written. Waiting for the daemon to exist would
# let the surface widen unnoticed.
#
# Methods are extracted from the protocol BODY, not the whole file. It used
# to scan with a '^func' pattern, which missed a method written as
# 'public func' and could mistakenly count static helpers in the same file.
# ---------------------------------------------------------------------------
PROTO_FILE=$(tracked 'Packages/SharedIPC/Sources/' | grep '\.swift$' \
             | while read -r f; do grep -lq 'protocol FanControlProtocol' "$f" && echo "$f"; done)

if [ -z "$PROTO_FILE" ]; then
  skip "no FanControlProtocol yet — written in P3.01"
else
  ALLOWED='^(describeFans|applyTargets|releaseToFirmware|heartbeat)$'
  METHODS=$(awk '
    /protocol[[:space:]]+FanControlProtocol/ { inside = 1 }
    inside && /^[[:space:]]*(public[[:space:]]+|static[[:space:]]+)*func[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/^(public[[:space:]]+|static[[:space:]]+)*func[[:space:]]+/, "", line)
      sub(/[(<].*$/, "", line)
      print line
    }
    inside && /^}/ { inside = 0 }
  ' "$PROTO_FILE" | sort -u)

  COUNT_M=$(printf '%s\n' "$METHODS" | grep -c . || true)
  EXTRA=$(printf '%s\n' "$METHODS" | grep . | grep -vE "$ALLOWED" || true)

  if [ -n "$EXTRA" ]; then
    fail "unsanctioned method on the XPC surface (M4) — widening it requires an ADR:"
    printf '%s\n' "$EXTRA" | sed 's/^/      /'
  elif [ "$COUNT_M" -ne 4 ]; then
    fail "the XPC surface has $COUNT_M methods, 4 expected (M4)"
    printf '%s\n' "$METHODS" | sed 's/^/      /'
  else
    ok "XPC surface limited to four methods"
  fi
fi

DAEMON=$(tracked 'Daemon/' | grep '\.swift$' || true)
COUNT=$(printf '%s\n' "$DAEMON" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  skip "no daemon sources — arrive in P3"
else
  note "daemon files scanned: $COUNT"

  # -------------------------------------------------------------------------
  # M5 — the daemon reads no configuration or files
  # -------------------------------------------------------------------------
  CONFIG_IO='(JSONDecoder|JSONSerialization|PropertyListDecoder|contentsOfFile|Data\(contentsOf:)'
  if HITS=$(grep_files "$DAEMON" -nHE "$CONFIG_IO"); then
    fail "the daemon reads files/configuration (M5)"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "the daemon reads no configuration"
  fi

  # -------------------------------------------------------------------------
  # M6 — the daemon uses no network
  # -------------------------------------------------------------------------
  if HITS=$(grep_files "$DAEMON" -nHE '(URLSession|import[[:space:]]+Network|NWConnection)'); then
    fail "the daemon uses a network API (M6)"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "the daemon uses no network"
  fi

  # -------------------------------------------------------------------------
  # Subprocess ban — privilege escalation risk
  # -------------------------------------------------------------------------
  if HITS=$(grep_files "$DAEMON" -nHE '(Process\(\)|posix_spawn|NSTask|execv)'); then
    fail "the daemon spawns subprocesses — privilege escalation risk"
    printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  else
    ok "the daemon spawns no subprocesses"
  fi

  # -------------------------------------------------------------------------
  # G5 — signature verification must be present
  # -------------------------------------------------------------------------
  # setCodeSigningRequirement has been the SUPPORTED route since macOS 13.
  # Calling SecCodeCheckValidity by hand is accepted too, but not preferred:
  # rewriting a security decision where Apple already got it right means
  # owning a brand new bug surface.
  if grep_files "$DAEMON" -lE '(setCodeSigningRequirement|SecCodeCheckValidity|SecRequirementCreateWithString)' >/dev/null; then
    ok "XPC signature verification present"
  else
    fail "XPC signature verification not found (G5)"
  fi
fi

gate_result "gate-daemon"
