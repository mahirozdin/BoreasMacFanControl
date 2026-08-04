# Security Policy

> Last updated: 2026-08-04
> Source: blueprint §14

## Reporting a vulnerability

If you have found a security issue, **please do not open a public issue**.

- **Contact:** `mahirozdin@bubiapps.com`
- **Target first response:** 72 hours
- **In scope:** the application, the privileged helper, the XPC interface,
  configuration handling, the install and uninstall flows
- **Out of scope:** macOS itself, third party tools, social engineering

Responsible disclosure is preferred. Once a fix ships, you are welcome to be
credited in `NOTICE` if you would like to be.

## Hardening

| Measure | Status |
|---|---|
| Hardened Runtime | Required |
| Library validation | Enabled |
| Apple notarisation | Required for every release |
| Code signing (Developer ID) | Required for release |
| XPC signature verification | **Both directions**, required |
| Executable pages in writable memory | Disabled |
| Network client entitlement | Only in the update and automation modules |

## The privileged surface

The helper runs as root. Its interface is deliberately tiny:

```
describeFans()             // read only
applyTargets([FanTarget])  // within hardware limits
releaseToFirmware()
heartbeat(nonce:)
```

Only primitive values cross the boundary — numbers and strings, never a
structured payload. The helper therefore has **nothing to parse**, which removes
decoding bugs as a class rather than trying to write them correctly.

The helper also:

- **Accepts no** file path, command, script or arbitrary data
- **Reads no** configuration — nothing user supplied is parsed as root
- **Has no** network access
- **Starts no** subprocess
- Verifies that every caller carries the same code signing team as itself, and
  rejects anything else

All of this is enforced by `make gate-daemon`, which fails the build if any of
it changes. Details: [ADR 0007](docs/architecture/adr/0007-privilege-split.md),
[ADR 0008](docs/architecture/adr/0008-smappservice-xpc.md).

## The safety chain

Fan commands pass through five layers before reaching hardware. **No layer can
lower a fan speed; each can only raise it.** Two of them cannot be switched off
at all.

The watchdog is the backstop: if the application stops sending heartbeats —
because it crashed, hung, was force quit, or the user logged out — the helper
hands the fans back to the firmware on its own. It never relies on the
application to clean up after itself, because the cases that matter are exactly
the ones where it cannot.

Details: `ARCHITECTURE.md` §7 and
[`docs/product/control-model.md`](docs/product/control-model.md).

## Privacy

- No usage data is collected or transmitted
- No analytics SDK, no crash reporting SDK, no advertising identifier
- **By default the application makes no network connections at all**
- If update checking is enabled, only a version number is fetched
- Everything stays on your machine, in files you can read

These claims are **verifiable in code** and checked on every commit by
`make gate-privacy`. See [ADR 0014](docs/architecture/adr/0014-zero-telemetry.md).

## Uninstalling

Removing the application returns the system to its previous state. No firmware
or NVRAM change is made, and fan settings revert to the macOS defaults as soon
as Boreas stops running.
