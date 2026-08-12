#!/usr/bin/env bash
# ============================================================================
# P8.01 — sign the app, the daemon and the CLI, each separately.
#
# Order matters and is not a style choice: the helper lives *inside* the
# application bundle, so signing the app first and the helper second would
# invalidate the outer signature. Nested code is signed inside out.
#
# `--options runtime` (Hardened Runtime) is required for notarisation. So is a
# secure timestamp, which is the default and is left alone deliberately —
# `--timestamp=none` would produce a signature that notarisation rejects.
#
# THE IDENTITY IS RESOLVED, NOT PASSED AS A STRING:
#   This team has two Developer ID Application certificates with identical
#   names, so `codesign -s "Developer ID Application: …"` fails as ambiguous on
#   a machine holding both. The hash is looked up instead, and which one was
#   chosen is printed — a build must never be vague about what signed it.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

APP="${1:-}"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "usage: scripts/sign.sh /path/to/Boreas.app [/path/to/boreas]" >&2
  exit 1
fi
CLI="${2:-}"

TEAM="${APPLE_TEAM_ID:-$(grep -E '^DEVELOPMENT_TEAM' Local.xcconfig 2>/dev/null | tr -d ' ' | cut -d= -f2)}"
if [ -z "$TEAM" ]; then
  echo "✗ no team identifier: set APPLE_TEAM_ID or DEVELOPMENT_TEAM in Local.xcconfig" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Which certificate, exactly.
# ---------------------------------------------------------------------------
resolve_identity() {
  local matches
  matches=$(security find-identity -v -p codesigning \
    | grep "Developer ID Application" | grep "($TEAM)" || true)
  local count
  count=$(printf '%s\n' "$matches" | grep -c . || true)

  if [ "$count" -eq 0 ]; then
    echo "✗ no Developer ID Application certificate for team $TEAM" >&2
    echo "  ADR 0019 Path A needs one; see the M03 row in TODO.md" >&2
    exit 1
  fi
  if [ "$count" -gt 1 ] && [ -z "${SIGN_IDENTITY:-}" ]; then
    # Reported, then the first is used. Both are the same team and the same
    # kind of certificate, so either produces a valid signature — but which
    # one signed a released binary is not something to leave unrecorded.
    echo "  ! $count Developer ID certificates for $TEAM; using the first." >&2
    echo "    Set SIGN_IDENTITY=<sha1> to choose. Available:" >&2
    printf '%s\n' "$matches" | sed 's/^/      /' >&2
  fi
  printf '%s\n' "$matches" | head -1 | awk '{print $2}'
}

IDENTITY="${SIGN_IDENTITY:-$(resolve_identity)}"
echo "▶ signing as $IDENTITY (team $TEAM)"

sign_one() {
  local target="$1" label="$2"
  codesign --force --sign "$IDENTITY" --options runtime --timestamp "$target"
  echo "  ✓ signed $label"
}

# ---------------------------------------------------------------------------
# Inside out. The helper and its launchd plist ride inside the app bundle
# (ADR 0008); signing the outer bundle first would invalidate itself.
# ---------------------------------------------------------------------------
HELPER="$APP/Contents/Library/LaunchDaemons"
if [ -d "$HELPER" ]; then
  while IFS= read -r binary; do
    [ -f "$binary" ] || continue
    case "$binary" in *.plist) continue ;; esac
    sign_one "$binary" "helper $(basename "$binary")"
  done < <(find "$HELPER" -type f -perm +111)
fi

sign_one "$APP" "$(basename "$APP")"

if [ -n "$CLI" ] && [ -f "$CLI" ]; then
  sign_one "$CLI" "$(basename "$CLI")"
fi

# ---------------------------------------------------------------------------
# Verified, not assumed. `--strict` is what catches a nested binary that was
# missed, which is the failure this script's ordering exists to prevent.
# ---------------------------------------------------------------------------
echo "▶ verifying"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | sed 's/^/    /'
echo "  ✓ signature valid and complete"

# The team the signature actually carries, read back rather than trusted: this
# is the value the XPC peer check (G5) will compare against at runtime.
ACTUAL=$(codesign -dv --verbose=4 "$APP" 2>&1 | grep -E '^TeamIdentifier=' | cut -d= -f2)
if [ "$ACTUAL" != "$TEAM" ]; then
  echo "✗ signed with team $ACTUAL but expected $TEAM" >&2
  exit 1
fi
echo "  ✓ team identifier in the signature is $ACTUAL"
