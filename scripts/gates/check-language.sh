#!/usr/bin/env bash
# ============================================================================
# GATE: gate-language
# Enforces: AGENTS.md — the repository is written in English
# ADR: docs/architecture/adr/0021-english-only-repository.md
#
# WHY THIS EXISTS
#   Boreas is an open source project for a worldwide audience. A contributor
#   who cannot read the governance documents cannot contribute, and a project
#   whose own working language excludes most of its potential users is not
#   really open.
#
#   The rule is easy to state and easy to forget, so it is checked rather than
#   trusted. Turkish is detected by characters that exist in no English word
#   plus a small set of very common function words.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
. scripts/gates/_lib.sh

echo "▶ gate-language — the repository is written in English"
require_tools git grep xargs

# Files that legitimately carry non-English text.
#   - the frozen blueprint is a historical record and is never edited
#   - README translations exist on purpose (ADR 0016)
#   - this gate names the characters it looks for
EXCLUDE_RE='^(BLUEPRINT\.md|docs/blueprint/|README\.(tr|ru|es|zh-Hans)\.md|scripts/gates/check-language\.sh|TRANSLATORS\.md)'

FILES=$(tracked "" "$EXCLUDE_RE")
COUNT=$(printf '%s\n' "$FILES" | grep -c . || true)
note "files scanned: $COUNT"

# Characters that appear in Turkish and in no English word.
TURKISH_CHARS='[ğışĞİŞ]'

if HITS=$(grep_files "$FILES" -IlE "$TURKISH_CHARS"); then
  fail "non-English text found (Turkish characters):"
  printf '%s\n' "$HITS" | head -25 | sed 's/^/      /'
  TOTAL=$(printf '%s\n' "$HITS" | grep -c .)
  [ "$TOTAL" -gt 25 ] && note "and $((TOTAL - 25)) more"
else
  ok "no Turkish characters outside the allowed files"
fi

# Common Turkish function words, as a second signal. Deliberately short: these
# never appear in English prose, so false positives are unlikely.
TURKISH_WORDS='\b(icin|deyil|degil|olarak|yapilir|kullanilir|gereklidir|dosyasi|hicbir)\b'

if HITS=$(grep_files "$FILES" -IlEi "$TURKISH_WORDS"); then
  fail "non-English text found (Turkish words without diacritics):"
  printf '%s\n' "$HITS" | head -15 | sed 's/^/      /'
else
  ok "no Turkish function words"
fi

gate_result "gate-language"
