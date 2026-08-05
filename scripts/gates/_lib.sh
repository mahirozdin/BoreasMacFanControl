#!/usr/bin/env bash
# ============================================================================
# Shared helpers for the gate scripts.
#
# COMPATIBILITY NOTE — IMPORTANT:
#   The macOS /bin/bash is version 3.2.57 (Apple stopped updating it over
#   licensing). Bash 4+ features are NOT used: mapfile/readarray, ${x,,},
#   ${x^^}, associative arrays (declare -A), string keys over ${!x[@]}.
#
#   The rule was born from a real bug: the gates used `mapfile`, the command
#   did not exist, the scan never ran and the gate still reported PASS. The
#   classic "fake gate". require_tools below makes that unrepeatable: if a
#   capability is missing the gate turns red instead of passing silently.
# ============================================================================

# Gate result
GATE_FAIL=0

ok()   { printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*"; GATE_FAIL=1; }
warn() { printf '  ! %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
skip() { printf '  ○ SKIP: %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Are the external commands the gate needs present?
# If one is missing the gate must not PASS — silent passes are forbidden.
# ---------------------------------------------------------------------------
require_tools() {
  local missing=""
  local t
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
  done
  if [ -n "$missing" ]; then
    printf '  ✗ required command missing:%s\n' "$missing"
    printf '    The gate cannot verify anything. Passing silently is forbidden.\n'
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Scannable file list (newline separated). Optional exclusion regex.
# Bash 3.2 compatible: returns a newline separated string, not an array.
#
# SCOPE NOTE — tracked AND untracked-but-not-ignored:
#   Plain `git ls-files` sees only what is already committed or staged. A
#   brand-new file is invisible to every gate until AFTER it enters git
#   history — exactly backwards for gates whose job is keeping violations
#   OUT of the permanent record. It really happened: a new schema file
#   carrying an off-allowlist domain passed gate-names untracked, was
#   committed, and only turned the gate red in the next session.
#   `--others --exclude-standard` closes that window; ignored build
#   artifacts stay excluded.
# ---------------------------------------------------------------------------
tracked() {
  local pattern="${1:-}"
  local exclude="${2:-}"
  local out
  if [ -n "$pattern" ]; then
    out=$(git ls-files --cached --others --exclude-standard -- $pattern 2>/dev/null || true)
  else
    out=$(git ls-files --cached --others --exclude-standard 2>/dev/null || true)
  fi
  if [ -n "$exclude" ]; then
    out=$(printf '%s\n' "$out" | grep -vE "$exclude" || true)
  fi
  printf '%s' "$out" | grep -c . >/dev/null 2>&1
  printf '%s\n' "$out" | grep . || true
}

# ---------------------------------------------------------------------------
# grep over a file list. If the list is empty, grep is NOT run
# (it would read stdin and hang / return the wrong result).
# Usage: grep_files "<file list>" "<grep flags>" "<pattern>"
# Output: the matches (if any). Return: 0 = matches exist, 1 = none.
# ---------------------------------------------------------------------------
grep_files() {
  local files="$1"; shift
  [ -n "$files" ] || return 1
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep "$@" 2>/dev/null
}

gate_result() {
  local name="$1"
  echo
  if [ "$GATE_FAIL" -eq 0 ]; then
    echo "✓ $name PASS"
  else
    echo "✗ $name FAIL"
  fi
  return "$GATE_FAIL"
}
