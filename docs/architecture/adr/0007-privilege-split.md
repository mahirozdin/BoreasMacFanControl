# 0007 — Unprivileged read / privileged write split

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §4.2, §6

## Context

Users' biggest reservation about tools in this category is installation steps that weaken system security. At the same time, writing fan speeds genuinely requires root.

The critical technical finding: **on Apple Silicon, reading temperatures requires no privileges at all.** Only writing to the SMC does.

## Decision

The architecture is built on this finding:

- **Read path** — the application accesses the hardware directly; it does not go through the helper
- **Write path** — fan target/mode only; via the privileged helper
- **The helper surface is minimal:** four XPC methods; it reads no configuration, uses no network, launches no subprocesses

The result: even if the user **never installs the helper at all**, the application is a fully functional monitoring tool.

## Alternatives

| Candidate | Why rejected |
|---|---|
| Doing everything through the helper | Needlessly grows the privileged surface; asking for root in order to read is indefensible |
| Kernel extension | Requires disabling SIP + a Recovery Mode step — contrary to Principle 2 |
| Having the helper read the configuration | Parsing user data on the root side creates an attack surface |

## Consequences

- ✅ The administrator password is asked only once, and only when fan control is requested
- ✅ Full monitoring without the helper installed
- ✅ The privileged code surface is limited to a few hundred lines
- ⚠️ Two separate hardware access paths (read/write) need maintaining

## Enforcement

- `make gate-daemon` → red if the helper contains `JSONDecoder`/file reads (M5)
- `make gate-daemon` → red if the helper contains a network API (M6)
- `make gate-daemon` → red if the helper launches a subprocess
- `make gate-privacy` → red if the helper's entitlements include network access
