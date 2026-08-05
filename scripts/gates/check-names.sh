#!/usr/bin/env bash
# ============================================================================
# GATE: gate-names
# Enforces: AGENTS.md §2.1 H1, H4  ·  LEGAL.md Y5, Y6
# ADR: docs/architecture/adr/0006-independent-development-policy.md
#
# WHY THERE IS NO NAME LIST:
#   Keeping forbidden product names in this file would violate the ban
#   itself — the names would be in the repository. So the gate uses three
#   layers that need no names: comparative marketing patterns, an external
#   domain allowlist and a trademark symbol scan. The remaining space is
#   covered by the PR declaration plus human review. See LEGAL.md §5.2.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-names — third party product names / comparative marketing"
require_tools git grep sed sort xargs

# ---------------------------------------------------------------------------
# EXEMPTION — two layers
#
# Policy files inevitably produce false positives because they contain the
# rule's OWN text (say, a table listing the forbidden patterns).
#
#   1) Fixed exemption: the core governance files
#   2) Marker exemption: any file carrying POLICY_MARKER
#
# The marker is preferred because the file declares its own exemption and
# that declaration is visible in code review. A fixed list goes stale.
# ---------------------------------------------------------------------------
POLICY_MARKER='gate-names:policy-doc'
EXCLUDE_RE='^(LEGAL\.md|AGENTS\.md|CLAUDE\.md|BLUEPRINT\.md|BOOT\.md|docs/blueprint/|scripts/gates/check-names\.sh|scripts/gates/_lib\.sh)'

ALL_FILES=$(tracked "" "$EXCLUDE_RE")

# Also drop the files carrying the marker
MARKED=$(grep_files "$ALL_FILES" -lF -e "$POLICY_MARKER" || true)
if [ -n "$MARKED" ]; then
  FILES=$(printf '%s\n' "$ALL_FILES" | grep -vxF "$(printf '%s\n' "$MARKED")" || true)
  note "exempt via policy marker: $(printf '%s\n' "$MARKED" | grep -c .) file(s)"
else
  FILES="$ALL_FILES"
fi
COUNT=$(printf '%s\n' "$FILES" | grep -c . || true)
note "files scanned: $COUNT"

if [ "$COUNT" -eq 0 ]; then
  warn "no files to scan — empty repository or everything excluded"
fi

# NOTE: every text scan uses grep -I — binary files (PNG and so on) are
# skipped. Otherwise random byte sequences match ™/®.
# ---------------------------------------------------------------------------
# 1. Comparative marketing patterns (Y6)
# ---------------------------------------------------------------------------
# Case INSENSITIVE patterns: phrases that compare regardless of how a product
# name is written. (The Turkish-language variants were dropped with ADR 0021:
# the repository language is English, and any Turkish prose would trip
# gate-language before these patterns could matter.)
COMPARATIVE_ANY='(alternative[[:space:]]+to|better[[:space:]]+than|replacement[[:space:]]+for|drop-in[[:space:]]+replacement|competitor)'

# Case SENSITIVE patterns: here the capital letter is what points at a
# PRODUCT NAME. The split is essential — scanned with `grep -i` the [A-Z]
# requirement would be meaningless and ordinary English like "instead of
# returning", "instead of failing" would match. It actually happened.
COMPARATIVE_CASED='instead[[:space:]]+of[[:space:]]+[A-Z]'

COMP_FAIL=0
if HITS=$(grep_files "$FILES" -InEHi "$COMPARATIVE_ANY"); then
  fail "comparative marketing pattern found (Y6)"
  printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  COMP_FAIL=1
fi
if HITS=$(grep_files "$FILES" -InEH "$COMPARATIVE_CASED"); then
  fail "comparison against a capitalised product name (Y6)"
  printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
  COMP_FAIL=1
fi
[ "$COMP_FAIL" -eq 0 ] && ok "no comparative marketing patterns"

# ---------------------------------------------------------------------------
# 2. Trademark symbols — the tell of a third party brand reference
# ---------------------------------------------------------------------------
if HITS=$(grep_files "$FILES" -InH -e '™' -e '®'); then
  fail "trademark symbol (™/®) found — possible third party brand reference"
  printf '%s\n' "$HITS" | head -10 | sed 's/^/      /'
else
  ok "no trademark symbols"
fi

# ---------------------------------------------------------------------------
# 3. External domain allowlist
#    How to catch third party product references without keeping a name
#    list: every external domain not on the allowlist asks for human review.
# ---------------------------------------------------------------------------
ALLOWED='(apple\.com|developer\.apple\.com|support\.apple\.com|github\.com|githubusercontent\.com|swift\.org|opensource\.org|spdx\.org|json-schema\.org|keepachangelog\.com|semver\.org|contributor-covenant\.org|brew\.sh|conventionalcommits\.org|www\.apache\.org|apache\.org|www\.apple\.com|www\.contributor-covenant\.org|www\.w3\.org|w3\.org|img\.shields\.io|shields\.io|localhost|127\.0\.0\.1|example\.org|example\.com|bubiapps\.com)'

if [ "$COUNT" -gt 0 ]; then
  URLS=$(grep_files "$FILES" -IohE 'https?://[a-zA-Z0-9._-]+' || true)
  UNKNOWN=$(printf '%s\n' "$URLS" | sed -E 's#https?://##' | grep . | sort -u \
            | grep -vE "^${ALLOWED}$" || true)
  if [ -n "$UNKNOWN" ]; then
    fail "external domain outside the allowlist — human review required:"
    printf '%s\n' "$UNKNOWN" | sed 's/^/      /'
    note "if it is acceptable, add it to the ALLOWED list in this script"
  else
    ok "all external domains are on the allowlist"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Local name list (optional, gitignored)
# ---------------------------------------------------------------------------
LOCAL_LIST="scripts/gates/.forbidden-names.local"
if [ -f "$LOCAL_LIST" ]; then
  HITS_FOUND=0
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    case "$name" in \#*) continue ;; esac
    if OUT=$(grep_files "$FILES" -InHiF -e "$name"); then
      HITS_FOUND=1
      printf '%s\n' "$OUT" | head -5 | sed 's/^/      /'
    fi
  done < "$LOCAL_LIST"
  if [ "$HITS_FOUND" -eq 1 ]; then
    fail "match from the local forbidden name list (Y5)"
  else
    ok "local name list: no matches"
  fi
else
  note "no local name list — optional, see LEGAL.md §5.2"
fi

gate_result "gate-names"
