# 0019 — Signing identity deferred to P8

- **Status:** Accepted
- **Date:** 2026-08-03
- **Related:** [0008](0008-smappservice-xpc.md), [0017](0017-distribution-channels.md) · `docs/reference/decisions.md` A4

## Context

The project owner did not want to configure the Developer ID certificate for now, and asked: given that the application will not be published on the App Store and will be offered only as a DMG from the GitHub repository, is the certificate mandatory?

The question carries a common misconception, and it needs to be recorded:

> **Developer ID is not for the App Store. Quite the opposite: it exists for distribution *outside* the App Store.**
> App Store distribution uses an entirely different certificate type (Mac App Distribution).
> The "DMG from GitHub" scenario is the very reason Developer ID exists.

There is also a separate technical constraint: Apple states that the **"Sign to Run Locally" (ad-hoc signing) approach is not supported** in the privileged helper + XPC scenario, because an ad-hoc signature cannot produce a code signing requirement that can securely identify the application and the helper. This directly affects the G5 invariant of [ADR 0008](0008-smappservice-xpc.md) (two-way signature verification).

## Decision

**A signing identity is not required for P1–P7; it is a prerequisite of P8.**

| Phase | Signing need |
|---|---|
| P1 · P2 (skeleton, unprivileged reading) | **None.** Reading sensors and fans requires no privileges ([ADR 0007](0007-privilege-split.md)) |
| P3–P7 (daemon, control, interface) | **An Apple Development certificate.** Available with a free Apple account; it produces a personal Team ID, and XPC signature verification works on the local machine |
| P8 (release) | **Developer ID + notarisation.** Otherwise there is no distributable product |

Manual tasks M03 and M04 remain `OPEN` but are marked as **blocking P8 only**. They stop no work throughout P1–P7.

## Two paths at P8

The decision will be made when P8 arrives. The outcomes of the two are not equal:

### Path A — Developer ID + notarisation (recommended)

- Requires Apple Developer Program membership (paid annually)
- No Gatekeeper warning, single click installation
- `SMAppService` daemon registration and XPC signature verification work as designed
- The Homebrew cask works without friction
- **The blueprint and all ADRs remain valid unchanged**

### Path B — unsigned / development certificate only

- After opening the DMG the user must grant permission by hand via System Settings → Privacy & Security. Since macOS 15 removed the Control-click shortcut, the number of steps has grown
- **The privileged daemon does not work reliably.** Because of the constraint Apple states, the XPC code signing requirement cannot securely identify the application and the helper → the G5 invariant cannot be met
- The Homebrew cask is unusable in practice
- **The product effectively splits in two:** the monitoring half works, fan control does not

If Path B is chosen, that is a fundamental change of product scope and must be recorded **with a new ADR**: `docs/product/scope.md` must move fan control to a "build from source only" position, and the README must state it plainly.

## Alternatives

| Candidate | Why rejected |
|---|---|
| Making the certificate mandatory at P1 | Needless blockage; P1–P2 work completely unsigned |
| Shipping the daemon with an ad-hoc signature | Apple does not support it; the G5 invariant cannot be met and the security model collapses |
| Leaving the decision open | A surprise blockage at P8; a known dependency must be put on record |

## Consequences

- ✅ No work is blocked throughout P1–P7
- ✅ The dependency and its cost are on record; no surprise at P8
- ✅ Path B's impact on the product is written down in advance
- ⚠️ If Path B is chosen, the project's main feature (fan control) becomes undistributable

## Enforcement

- `TODO.md` manual tasks table: M03 and M04 are marked as P8 dependencies only
- The `TODO.md` cross-phase blocker **B4** is already in place: if notarisation fails, no release ships
- The P8.09 release gates checklist verifies the signing chain
- A verification task was added in P3: that `SMAppService` registration and XPC signature verification actually work with a development certificate will be proven **empirically** (not assumed)
