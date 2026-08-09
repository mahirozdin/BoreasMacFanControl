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

# The character class below is multibyte UTF-8. Under the C locale grep
# degrades it into a BYTE class, and continuation bytes shared with emoji
# and typography (0x9E/0x9F/0xB0/0xB1) produce false positives — a green
# gate on one machine and a red one in CI, depending on $LANG. The locale
# is pinned so the gate means the same thing everywhere.
export LC_ALL=en_US.UTF-8

echo "▶ gate-language — the repository is written in English"
require_tools git grep xargs

# Files that legitimately carry non-English text.
#   - the frozen blueprint is a historical record and is never edited
#   - README translations exist on purpose (ADR 0016)
#   - this gate names the characters it looks for
#   - the String Catalog is *where translations live*. H6 is about the
#     language the project is worked in — documents, comments, commits —
#     not about the product's own translated strings, and a rule that
#     forbade Turkish inside the Turkish translations would forbid the
#     product from being translated at all. The catalogue is not
#     unchecked: `make gate-i18n` reads it far more closely than this
#     gate could, including that every string has an English comment for
#     the translator (Y2). Added in P6.11.
#   - the P6.11 catalogue builder names the languages it merges
EXCLUDE_RE='^(BLUEPRINT\.md|docs/blueprint/|README\.(tr|ru|es|zh-Hans)\.md|scripts/gates/check-language\.sh|scripts/gates/check-catalog\.py|TRANSLATORS\.md|App/Resources/.*\.xcstrings)'

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
