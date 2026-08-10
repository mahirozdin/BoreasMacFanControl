#!/usr/bin/env bash
# ============================================================================
# CLI test (P7.04) — every `boreas` command, against real state.
#
# Not a drill inside the app: the CLI is a separate binary and the thing worth
# proving is that it behaves correctly *as a process* — exit codes, refusals,
# and the fact that `import` validates before it writes. A drill compiled into
# the app could not test any of that.
#
# The destructive commands are the point of the care taken here:
#   - `import` is run against a COPY of the real configuration, restored after
#   - `install` / `uninstall` are NOT run: they change the helper's registration
#     and ask for an administrator password. `--helper-status` is checked instead.
#
# Exit code: 0 = every check passed.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
. scripts/gates/_lib.sh

echo "▶ cli-test — the boreas command line surface"

CLI="${CLI:-}"
if [ -z "$CLI" ]; then
  CLI=$(ls -d ~/Library/Developer/Xcode/DerivedData/Boreas-*/Build/Products/Debug/boreas \
    2>/dev/null | head -1)
fi
if [ ! -x "${CLI:-}" ]; then
  fail "boreas not found — build it first, or set CLI=/path/to/boreas"
  exit 1
fi
note "cli: $CLI"

PASSED=0
FAILED=0
check() {
  if [ "$2" -eq 0 ]; then ok "$1"; PASSED=$((PASSED + 1));
  else fail "$1"; FAILED=$((FAILED + 1)); fi
}

# ---------------------------------------------------------------------------
# The read-only commands. Each must exit 0 and say something.
# ---------------------------------------------------------------------------
for command in version status sensors profile; do
  OUT=$("$CLI" $command 2>&1); RC=$?
  LINES=$(printf '%s\n' "$OUT" | grep -c . || true)
  [ "$RC" -eq 0 ] && [ "$LINES" -gt 0 ]
  check "'$command' exits 0 and prints something ($LINES lines)" $?
done

# `help` writes to stderr and exits 0 — a usage message is not an error when
# it was asked for.
OUT=$("$CLI" help 2>&1); RC=$?
# Each new command by name. The first version of this check grepped for
# "boreas profile", which the usage text has no reason to contain — the test was
# wrong, not the help.
MISSING=""
for command in profile install export import; do
  printf '%s\n' "$OUT" | grep -qE "^  $command" || MISSING="$MISSING $command"
done
[ -z "$MISSING" ]
check "'help' documents every new command (missing:${MISSING:- none})" $?
[ "$RC" -eq 0 ]
check "'help' exits 0 when asked for" $?

# An unknown command must fail, not shrug.
"$CLI" definitely-not-a-command >/dev/null 2>&1
[ $? -ne 0 ]
check "an unknown command exits non-zero" $?

# ---------------------------------------------------------------------------
# profile — refusals happen before anything is posted.
# ---------------------------------------------------------------------------
"$CLI" profile ThisProfileDoesNotExist >/dev/null 2>&1
[ $? -ne 0 ]
check "'profile <unknown>' is refused" $?

OUT=$("$CLI" profile 2>&1)
printf '%s\n' "$OUT" | grep -q "the fallback"
check "'profile' marks the configured fallback" $?
printf '%s\n' "$OUT" | grep -q "never written to disk\|live only\|hand the decision"
check "'profile' says a choice is not persisted" $?

# ---------------------------------------------------------------------------
# export — to stdout, and to a file, and it must be valid JSON both ways.
# ---------------------------------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

"$CLI" export > "$TMP/stdout.json" 2>/dev/null
python3 -c "import json,sys; json.load(open('$TMP/stdout.json'))" 2>/dev/null
check "'export' with no file writes valid JSON to stdout" $?

"$CLI" export "$TMP/file.json" >/dev/null 2>&1
python3 -c "import json,sys; json.load(open('$TMP/file.json'))" 2>/dev/null
check "'export <file>' writes valid JSON to the file" $?

python3 - "$TMP/file.json" <<'PY'
import json, sys
document = json.load(open(sys.argv[1]))
required = {"schemaVersion", "general", "safety", "profiles"}
sys.exit(0 if required <= set(document) else 1)
PY
check "the exported document carries every required section" $?

# ---------------------------------------------------------------------------
# import — validates BEFORE writing, which is the claim worth testing.
# ---------------------------------------------------------------------------
CONFIG="$HOME/Library/Application Support/Boreas/config.json"
RESTORE=""
if [ -f "$CONFIG" ]; then
  RESTORE="$TMP/original.json"
  cp "$CONFIG" "$RESTORE"
  note "real configuration backed up for the import checks"
fi

printf 'this is not json at all' > "$TMP/broken.json"
BEFORE=$(shasum -a 256 "$CONFIG" 2>/dev/null | awk '{print $1}')
"$CLI" import "$TMP/broken.json" >/dev/null 2>&1
[ $? -ne 0 ]
check "'import' refuses a file that is not valid JSON" $?
AFTER=$(shasum -a 256 "$CONFIG" 2>/dev/null | awk '{print $1}')
[ "$BEFORE" = "$AFTER" ]
check "a refused import changed nothing on disk" $?

# A hostile but well formed document: the loader must clamp it, not refuse it,
# and the file written back must be the CLAMPED version.
python3 - "$TMP/hostile.json" <<'PY'
import json, sys
json.dump({
    "schemaVersion": 1,
    "safety": {"panicTemperatureCelsius": 140, "watchdogTimeoutSeconds": 900},
    "recording": {"suppressionWindowMinutes": 99999, "diskCeilingBytes": 1},
}, open(sys.argv[1], "w"))
PY
"$CLI" import "$TMP/hostile.json" >/dev/null 2>&1
check "'import' accepts a hostile but well formed document" $?
python3 - "$CONFIG" <<'PY'
import json, sys
document = json.load(open(sys.argv[1]))
panic = document["safety"]["panicTemperatureCelsius"]
watchdog = document["safety"]["watchdogTimeoutSeconds"]
sys.exit(0 if 70 <= panic <= 95 and 10 <= watchdog <= 60 else 1)
PY
check "the written file is the clamped version, not the hostile one" $?

if [ -f "$TMP/original.json" ]; then
  "$CLI" import "$TMP/original.json" >/dev/null 2>&1
  check "the real configuration was restored through import" $?
fi

# ---------------------------------------------------------------------------
# install / uninstall — checked as reachable, never actually run.
# ---------------------------------------------------------------------------
OUT=$("$CLI" status 2>&1)
printf '%s\n' "$OUT" | grep -q "^control  :"
check "'status' reports the helper's registration state" $?
note "install / uninstall are not exercised: they change the helper and prompt for a password"

echo
if [ "$FAILED" -eq 0 ]; then
  echo "✓ cli-test PASS ($PASSED checks)"
  exit 0
fi
echo "✗ cli-test FAIL ($FAILED of $((PASSED + FAILED)) checks)"
exit 1
