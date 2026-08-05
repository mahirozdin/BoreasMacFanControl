#!/usr/bin/env bash
# ============================================================================
# Hardware smoke test (P4.10) — the drills that only mean something on a
# real Mac, in one reproducible run:
#
#   1. take over / hand back, closed loop, K4 refusal   (--takeover-drill)
#   2. the manual control loop end to end               (--control-drill)
#   3. kill -9 while driving      -> handback via connection invalidation
#   4. SIGSTOP freeze while driving -> handback via watchdog expiry
#   5. sleep/wake                 -> ATTENDED ONLY (see --with-sleep)
#
# The fan itself is the witness: state is read unprivileged (--fan-state)
# from a process that is not the one being measured.
#
# Exit code: 0 = every leg that ran passed. The sleep leg is skipped unless
# --with-sleep is given, because `pmset sleepnow` on an unattended machine
# parks the session with nobody to wake it. Release blocker B5 requires the
# sleep leg to have passed before v1.0 ships.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
. scripts/gates/_lib.sh

require_tools python3 pgrep mdfind

# ---------------------------------------------------------------------------
# Locate the application. APP overrides; Launch Services otherwise.
# ---------------------------------------------------------------------------
if [ -z "${APP:-}" ]; then
  APP=$(mdfind "kMDItemCFBundleIdentifier == 'com.bubiapps.boreas'" 2>/dev/null | head -1)
fi
BIN="$APP/Contents/MacOS/Boreas"
if [ ! -x "$BIN" ]; then
  fail "application not found — set APP=/path/to/Boreas.app"
  exit 1
fi
note "app: $APP"

STATUS=$("$BIN" --helper-status)
case "$STATUS" in
  *enabled*) ok "helper enabled" ;;
  *)
    fail "helper is not installed ($STATUS) — set it up from the app first"
    exit 1
    ;;
esac

FAIL=0

echo
echo "▶ 1/4 take over / hand back (closed loop, K4 refusal)"
if "$BIN" --takeover-drill; then ok "takeover drill"; else fail "takeover drill"; FAIL=1; fi

echo
echo "▶ 2/4 manual control loop end to end"
if "$BIN" --control-drill; then ok "control drill"; else fail "control drill"; FAIL=1; fi

echo
echo "▶ 3/4 kill -9 while driving  ·  4/4 freeze while driving"
if BOREAS_BIN="$BIN" python3 - <<'PY'
import os, re, signal, subprocess, sys, time

BIN = os.environ["BOREAS_BIN"]

def fan_state():
    r = subprocess.run([BIN, "--fan-state"], capture_output=True, text=True, timeout=10)
    m = re.search(r"mode=(\S+) rpm=(\d+)", r.stdout)
    return (m.group(1), int(m.group(2))) if m else ("?", -1)

def start_pump():
    pump = subprocess.Popen([BIN, "--pump-heartbeats"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for _ in range(3):
        pump.stdout.readline()
    return pump

def wait_handback(t0, timeout, baseline):
    while time.time() - t0 < timeout:
        mode, rpm = fan_state()
        if mode == "0" and rpm <= baseline + 120:
            return time.time() - t0
        time.sleep(0.3)
    return None

mode, baseline = fan_state()
if mode != "0":
    print(f"  precondition failed: fan not under firmware control (mode={mode})")
    sys.exit(1)

pump = start_pump(); time.sleep(6)
mode, rpm = fan_state()
if mode != "1":
    print(f"  takeover for the kill leg did not engage (mode={mode})"); sys.exit(1)
os.kill(pump.pid, signal.SIGKILL)
back = wait_handback(time.time(), 30, baseline)
pump.wait()
if back is None:
    print("  kill -9: hardware NOT handed back within 30 s"); sys.exit(1)
print(f"  kill -9 while driving: handed back in {back:.1f}s")

time.sleep(3)

pump = start_pump(); time.sleep(6)
mode, rpm = fan_state()
if mode != "1":
    print(f"  takeover for the freeze leg did not engage (mode={mode})"); sys.exit(1)
os.kill(pump.pid, signal.SIGSTOP)
back = wait_handback(time.time(), 45, baseline)
os.kill(pump.pid, signal.SIGKILL); pump.wait()
if back is None:
    print("  freeze: hardware NOT handed back within 45 s"); sys.exit(1)
print(f"  freeze while driving: watchdog handed back in {back:.1f}s")
ok = 8.0 <= back <= 25.0
sys.exit(0 if ok else 1)
PY
then ok "kill and freeze handback"; else fail "kill and freeze handback"; FAIL=1; fi

echo
if [ "${1:-}" = "--with-sleep" ]; then
  echo "▶ sleep/wake (attended)"
  note "taking over, sleeping in 5 s — wake the machine yourself"
  "$BIN" --pump-heartbeats >/dev/null 2>&1 &
  PUMP=$!
  sleep 6
  pmset sleepnow
  # After wake: the pump was cut by the sleep; give the stack a moment.
  sleep 8
  kill -9 "$PUMP" 2>/dev/null
  STATE=$("$BIN" --fan-state)
  case "$STATE" in
    "mode=0"*) ok "after wake the firmware has the fan ($STATE)" ;;
    *) fail "after wake the fan is not back with firmware ($STATE)"; FAIL=1 ;;
  esac
else
  skip "sleep/wake leg — attended only, run: scripts/smoke-test-hardware.sh --with-sleep (release blocker B5)"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "✓ smoke-test-hardware PASS (every leg that ran)"
else
  echo "✗ smoke-test-hardware FAIL"
fi
exit "$FAIL"
