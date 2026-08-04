# 0014 — Zero telemetry

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §1.4, §14.3

## Context

The application is a tool that continuously reads the user's hardware sensors and runs in the background. For software in that position, collecting data is the most sensitive point of user trust.

The counterargument: without telemetry there is no way to know which features are used. This is accepted — product decisions are made from user feedback.

## Decision

- **No usage data is collected or transmitted**
- There is **no** analytics SDK, no crash reporting SDK, no advertising identifier
- **By default the application makes no network connection at all**
- The network is used in exactly two cases, and only if the user turned them on: the update check, and a webhook the user defined
- A user who wants to report a crash attaches the generated **local** file to an issue themselves
- Log lines contain no personal data: no user name, no file path, no network information is logged

## Alternatives

| Option | Why not |
|---|---|
| Anonymous usage statistics | The "anonymous" claim cannot be verified; the user has to take it on trust. In this category trust is the most valuable asset |
| Opt-in telemetry | Even having telemetry infrastructure in the codebase creates audit burden and risk |
| Automatic crash reporting | Crash reports carry context; context can leak personal data |

## Consequences

- ✅ The privacy claim is **verifiable at the code level** — not a marketing promise
- ✅ No GDPR/KVKK surface
- ✅ Adoption in corporate environments becomes easier
- ⚠️ No feature usage data → product decisions rest on feedback
- ⚠️ Crash diagnosis requires the user's active participation

## Enforcement

`make gate-privacy`:
- Any telemetry/analytics SDK name or a trace of `advertisingIdentifier` → red (P1)
- A network API outside `App/Sources/Updates/` and `App/Sources/Automation/` → red (P2)
- A network entitlement on the daemon → red

Proven: when a file containing an `Analytics` reference was placed, the gate turned red.
