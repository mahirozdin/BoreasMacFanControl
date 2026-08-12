#!/usr/bin/env bash
# ============================================================================
# P8.02 — notarise a signed disk image, then staple the ticket to it.
#
# **If this fails, no release ships.** That is cross-phase blocker B4, and it is
# enforced by this script exiting non-zero rather than by anybody remembering:
# `notarytool --wait` returns the status, and anything other than `Accepted`
# stops here.
#
# Stapling is not optional. Without it the ticket only exists on Apple's
# servers, so the first launch on a machine with no network shows the very
# Gatekeeper dialog notarisation was meant to remove.
#
# CREDENTIALS, TWO WAYS AND NEITHER IN THE REPOSITORY:
#   Locally  — a keychain profile made by `xcrun notarytool store-credentials`.
#   In CI    — NOTARY_KEY_P8_BASE64, NOTARY_KEY_ID and NOTARY_ISSUER_ID, which
#              are GitHub secrets; the key is written to a temporary file and
#              removed on exit, including on failure.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

TARGET="${1:-}"
if [ ! -f "${TARGET:-}" ]; then
  echo "usage: scripts/notarize.sh /path/to/Boreas-<version>.dmg" >&2
  exit 1
fi

PROFILE="${NOTARY_PROFILE:-boreas-notary}"
KEYFILE=""
cleanup() { [ -n "$KEYFILE" ] && rm -f "$KEYFILE"; }
trap cleanup EXIT

if [ -n "${NOTARY_KEY_P8_BASE64:-}" ]; then
  if [ -z "${NOTARY_KEY_ID:-}" ] || [ -z "${NOTARY_ISSUER_ID:-}" ]; then
    echo "✗ NOTARY_KEY_P8_BASE64 is set but NOTARY_KEY_ID or NOTARY_ISSUER_ID is not" >&2
    exit 1
  fi
  KEYFILE=$(mktemp -t boreas-notary-key)
  printf '%s' "$NOTARY_KEY_P8_BASE64" | base64 --decode > "$KEYFILE"
  AUTH=(--key "$KEYFILE" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
  echo "▶ notarising with an API key from the environment"
else
  AUTH=(--keychain-profile "$PROFILE")
  echo "▶ notarising with keychain profile '$PROFILE'"
fi

# `--wait` blocks until Apple answers. Minutes, usually; the alternative is a
# release job that reports success before the verdict exists.
set +e
OUTPUT=$(xcrun notarytool submit "$TARGET" "${AUTH[@]}" --wait 2>&1)
STATUS=$?
set -e
printf '%s\n' "$OUTPUT" | sed 's/^/    /'

SUBMISSION=$(printf '%s\n' "$OUTPUT" | grep -m1 -E '^ *id: ' | awk '{print $2}' || true)

if [ $STATUS -ne 0 ] || ! printf '%s\n' "$OUTPUT" | grep -q "status: Accepted"; then
  echo "✗ notarisation did not succeed — B4: no release ships" >&2
  if [ -n "$SUBMISSION" ]; then
    # The verdict alone never says *why*. The log does, and fetching it here
    # means the failure is diagnosable from the CI transcript.
    echo "  fetching Apple's log for $SUBMISSION:" >&2
    xcrun notarytool log "$SUBMISSION" "${AUTH[@]}" 2>&1 | sed 's/^/      /' >&2 || true
  fi
  exit 1
fi
echo "  ✓ Accepted"

echo "▶ stapling"
xcrun stapler staple "$TARGET" | sed 's/^/    /'
xcrun stapler validate "$TARGET" | sed 's/^/    /'
echo "  ✓ ticket stapled"

# What a user's Mac will actually decide, asked of the same subsystem that
# decides it. `spctl` is the closest thing to opening the download by hand.
echo "▶ Gatekeeper assessment"
spctl --assess --type open --context context:primary-signature -vv "$TARGET" 2>&1 \
  | sed 's/^/    /'
echo "  ✓ accepted by Gatekeeper"
