#!/usr/bin/env bash
# ============================================================================
# Boreas — local development environment setup and verification
#
# Idempotent: however many times it runs it gives the same result, deletes
# nothing, reinstalls nothing that exists.
#
# DESIGN NOTE — tools are checked for "does it work", not "does it exist".
# A broken global install can stall silently; `command -v` misses that,
# `--version` catches it. This is a trap actually met in the field.
#
# Exit code: 0 = environment ready, 1 = something missing/broken (each is
# reported)
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

FAIL=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; FAIL=1; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

printf '\033[1mBoreas — environment check\033[0m\n'

# ---------------------------------------------------------------------------
head_ "Platform"
# ---------------------------------------------------------------------------
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  ok "architecture: arm64"
else
  bad "architecture: $ARCH — Boreas targets Apple Silicon only (ADR 0004)"
fi

OSV=$(sw_vers -productVersion)
OSMAJ=${OSV%%.*}
if [ "$OSMAJ" -ge 14 ]; then
  ok "macOS $OSV (minimum 14.0)"
else
  bad "macOS $OSV — minimum 14.0 required (ADR 0003)"
fi

# ---------------------------------------------------------------------------
head_ "Tools"   # NOT "does it exist" — "does it work"
# ---------------------------------------------------------------------------
# check_tool <display name> <hint> -- <command> [arg...]
#
# The command is passed AS ARGUMENTS, not as a single string. Expanding a
# string via `$cmd` behaves differently per shell (zsh does no word
# splitting by default) and the command "xcodebuild -version" was looked up
# as one name, giving "command not found" — the check mistook a healthy
# Xcode for a broken one.
check_tool() {
  local name="$1" hint="$2"; shift 3   # the 3rd argument is the "--" separator
  if ! command -v "$1" >/dev/null 2>&1; then
    bad "$name missing — fix: $hint"
    return
  fi
  local out
  out=$("$@" 2>&1 | head -1)
  if [ -n "$out" ]; then
    ok "$name — $out"
  else
    bad "$name installed but NOT WORKING (empty output) — fix: $hint"
  fi
}

check_tool "Xcode"        "install Xcode 26+ from the App Store"          -- xcodebuild -version
check_tool "Swift"        "Xcode install broken: xcode-select --install"  -- swift --version
check_tool "swift format" "Swift 6.2+ required (built into the toolchain)" -- swift format --version
check_tool "XcodeGen"     "brew bundle"                                   -- xcodegen --version
check_tool "SwiftLint"    "brew bundle"                                   -- swiftlint --version
check_tool "xcbeautify"   "brew bundle"                                   -- xcbeautify --version
check_tool "Python 3"     "required by the gate scripts"                  -- python3 --version

# Is Swift 6.2+
SWV=$(swift --version 2>/dev/null | grep -oE 'Swift version [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | head -1)
if [ -n "$SWV" ]; then
  MAJ=${SWV%%.*}; MIN=${SWV##*.}
  if [ "$MAJ" -gt 6 ] || { [ "$MAJ" -eq 6 ] && [ "$MIN" -ge 2 ]; }; then
    ok "Swift $SWV (minimum 6.2)"
  else
    bad "Swift $SWV — minimum 6.2 required (invariant T1)"
  fi
fi

# ---------------------------------------------------------------------------
head_ "Repository"
# ---------------------------------------------------------------------------
[ -d .git ] && ok "git repository" || bad "not a git repository"
[ -f BLUEPRINT.md ] && ok "blueprint in place" || bad "BLUEPRINT.md missing — wrong directory?"
[ -f LICENSE ] && ok "LICENSE in place" || bad "LICENSE missing"

if git ls-files 2>/dev/null | grep -qE '\.(p12|p8|mobileprovision|provisionprofile)$'; then
  bad "SIGNING MATERIAL IN THE REPOSITORY — remove it immediately"
else
  ok "no secret material"
fi

# ---------------------------------------------------------------------------
head_ "Gates"
# ---------------------------------------------------------------------------
if make check >/tmp/boreas-bootstrap-gates.log 2>&1; then
  ok "make check — all gates PASS"
else
  bad "make check failed — details: /tmp/boreas-bootstrap-gates.log"
  grep -E '^  ✗' /tmp/boreas-bootstrap-gates.log | head -5 | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
head_ "Next task"
# ---------------------------------------------------------------------------
if scripts/next-task.py >/tmp/boreas-next.log 2>&1; then
  sed 's/^/  /' /tmp/boreas-next.log
else
  warn "nothing actionable:"
  sed 's/^/      /' /tmp/boreas-next.log
fi

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32m✓ Environment ready.\033[0m  To start: make next\n\n'
else
  printf '\033[31m✗ Something is missing.\033[0m  Apply the fixes above and run again.\n\n'
fi
exit "$FAIL"
