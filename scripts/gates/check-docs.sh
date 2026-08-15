#!/usr/bin/env bash
# ============================================================================
# GATE: docs-check
# Enforces: AGENTS.md §7 documentation update protocol
# Checks:
#   1. Broken relative markdown links
#   2. Every target in the traceability matrix actually exists
#   3. ADR files  ==  ADR index  ==  ARCHITECTURE.md table
#   4. make commands in documentation == Makefile targets
#   5. Pictures shown with <img> tags exist (P9.05)
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

FAIL=0
ok()   { printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*"; FAIL=1; }

echo "▶ docs-check — documentation integrity"

# ---------------------------------------------------------------------------
# 1. Broken relative links
# ---------------------------------------------------------------------------
BROKEN=""
while IFS= read -r md; do
  [ -f "$md" ] || continue
  dir=$(dirname "$md")
  # [text](target) → target; http(s), mailto and #anchor excluded
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    case "$target" in http*|mailto:*|\#*) continue ;; esac
    clean=${target%%#*}
    [ -z "$clean" ] && continue
    if [ ! -e "$dir/$clean" ] && [ ! -e "$clean" ]; then
      BROKEN+="    $md → $clean"$'\n'
    fi
  done < <(grep -oE '\]\([^)]+\)' "$md" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//')
done < <(git ls-files '*.md' 2>/dev/null)

if [ -n "$BROKEN" ]; then
  fail "broken relative link:"
  printf '%s' "$BROKEN"
else
  ok "no broken relative links"
fi

# ---------------------------------------------------------------------------
# 2. Traceability matrix targets
# ---------------------------------------------------------------------------
MAP="docs/reference/blueprint-map.md"
if [ -f "$MAP" ]; then
  MISSING=""
  while IFS= read -r t; do
    [ -e "$t" ] || MISSING+="    $t"$'\n'
  done < <(grep -oE '`(docs/[^`]+\.md|[A-Z_]+\.md)`' "$MAP" 2>/dev/null | tr -d '`' | sort -u)
  if [ -n "$MISSING" ]; then
    fail "nonexistent target in the traceability matrix:"
    printf '%s' "$MISSING"
  else
    ok "traceability matrix targets exist"
  fi

  # Missing section check
  if grep -qiE '^\|.*\|[[:space:]]*(—|-|none|MISSING)[[:space:]]*\|' "$MAP"; then
    fail "unmapped section in the traceability matrix (missing must be 0)"
  else
    ok "no unmapped blueprint section"
  fi
else
  fail "$MAP not found"
fi

# ---------------------------------------------------------------------------
# 3. ADR three-way sync
# ---------------------------------------------------------------------------
ADR_DIR="docs/architecture/adr"
if [ -d "$ADR_DIR" ]; then
  FILES=$(find "$ADR_DIR" -name '[0-9][0-9][0-9][0-9]-*.md' -exec basename {} \; | sed -E 's/^([0-9]{4}).*/\1/' | sort -u)
  IDX=$(grep -oE '\[?[0-9]{4}\]?\([^)]*\)|\b[0-9]{4}-[a-z0-9-]+\.md' "$ADR_DIR/README.md" 2>/dev/null \
        | grep -oE '[0-9]{4}' | sort -u)
  ARCH=$(grep -oE 'adr/[0-9]{4}-[a-z0-9-]+\.md' ARCHITECTURE.md 2>/dev/null \
        | grep -oE '[0-9]{4}' | sort -u)

  if [ "$FILES" = "$IDX" ]; then
    ok "ADR files == ADR index ($(echo "$FILES" | grep -c . ) entries)"
  else
    fail "ADR files and the index disagree"
    printf '      files: %s\n' "$(echo $FILES)"
    printf '      index: %s\n' "$(echo $IDX)"
  fi

  if [ "$FILES" = "$ARCH" ]; then
    ok "ADR files == ARCHITECTURE.md table"
  else
    fail "ADR files and the ARCHITECTURE.md table disagree"
    printf '      files:           %s\n' "$(echo $FILES)"
    printf '      ARCHITECTURE.md: %s\n' "$(echo $ARCH)"
  fi
else
  fail "$ADR_DIR not found"
fi

# ---------------------------------------------------------------------------
# 4. Do the make commands in documentation exist in the Makefile?
# ---------------------------------------------------------------------------
# The frozen blueprint is outside this check: it describes planned (not yet
# written) targets, not current state.
#
# CONTEXT REQUIREMENT: only "make x" in CODE context counts —
#   `make x`   (inside backticks)  or
#   ^make x    (start of line, inside a code block)
# In plain English prose "make" is a verb ("make participation", "make a
# report") and a context-free regex mistakes those for targets and breaks the
# gate falsely. That actually happened.
if [ -f Makefile ]; then
  MISSING=""
  while IFS= read -r tgt; do
    [ -n "$tgt" ] || continue
    grep -qE "^${tgt}:" Makefile || MISSING+="    make $tgt"$'\n'
  done < <(git ls-files '*.md' 2>/dev/null \
           | grep -vE '^(BLUEPRINT\.md|docs/blueprint/)' \
           | tr '\n' '\0' \
           | xargs -0 grep -ohE '`make [a-z][a-z0-9-]*`|^make [a-z][a-z0-9-]*' 2>/dev/null \
           | tr -d '`' | awk '{print $2}' | sort -u)
  if [ -n "$MISSING" ]; then
    fail "target mentioned in documentation but absent from the Makefile:"
    printf '%s' "$MISSING"
  else
    ok "make targets in documentation match the Makefile"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Do the pictures the documentation shows exist? (P9.05)
# ---------------------------------------------------------------------------
# Check 1 follows markdown links and does not look inside HTML. The READMEs
# show their screenshots with <img> tags, because markdown cannot set a width
# and a 1720 pixel picture at full size is not a page anybody reads. So the
# fifty picture references across the five READMEs were checked by nothing:
# rename a screenshot and all five break, silently, in the one file every
# visitor sees first.
#
# Not hypothetical — `make screenshots` renames what it publishes whenever the
# table inside it changes, which is exactly the kind of edit made without
# opening a README.
MISSING_IMG=""
for file in $(git ls-files '*.md' | grep -vE '^(BLUEPRINT\.md|docs/blueprint/)'); do
  for src in $(grep -oE '<img[^>]+src="[^"]+"' "$file" 2>/dev/null \
    | sed 's/.*src="//; s/"$//'); do
    case "$src" in
      http://*|https://*|data:*) continue ;;
    esac
    # Relative to the file that references it, as a browser would resolve it.
    base=$(dirname "$file")
    [ "$base" = "." ] && target="$src" || target="$base/$src"
    if [ ! -f "$target" ]; then
      MISSING_IMG="$MISSING_IMG    $file → $src"$'\n'
    fi
  done
done

if [ -n "$MISSING_IMG" ]; then
  fail "picture shown in documentation but not in the repository:"
  printf '%s' "$MISSING_IMG"
else
  ok "every picture the documentation shows exists"
fi

echo
[ "$FAIL" -eq 0 ] && echo "✓ docs-check PASS" || echo "✗ docs-check FAIL"
exit "$FAIL"
