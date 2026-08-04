# 0001 — Native Swift + SwiftUI

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §3.1, §3.2

## Context

The product requires fan reads/writes over the SMC, a privileged LaunchDaemon, XPC communication and a menu bar item. None of these are reachable from cross platform frameworks. And because the application runs in the background continuously, idle CPU and energy cost is a first class requirement.

## Decision

**Swift 6.2 + SwiftUI** (bridging to AppKit via `NSViewRepresentable` where needed). The project file is generated from `project.yml` with **XcodeGen**; `.xcodeproj` is never committed. The test framework is **Swift Testing**; XCTest for UI tests.

## Alternatives

| Candidate | Why rejected |
|---|---|
| **Flutter** | Native plugins would be required for IOKit, the privileged daemon, XPC and `NSStatusItem` — meaning the hardest part of the work would still be written in Swift. On top of that: a ~40–60 MB runtime, an interface that feels foreign, the energy cost of a continuous render loop. Its only advantage is cross platform; this project is single platform by definition |
| **Electron** | A ~120 MB+ binary, ~200 MB of memory. Unacceptable for a continuously running thermal monitor |
| **Rust + native UI** | Possible via FFI, but the SwiftUI/AppKit bridge is laborious, accessibility does not come for free, and the macOS contributor pool is narrow |

## Consequences

- ✅ First class access to IOKit/ServiceManagement/XPC
- ✅ VoiceOver, Dynamic Type, App Intents and WidgetKit come for free
- ✅ The smallest binary and memory footprint
- ⚠️ Cross platform is impossible — an accepted constraint
- ⚠️ Contributors must know Swift

## Enforcement

- `make gate-layers` → red if `.xcodeproj` is committed (T5)
- `.gitignore` → excludes `*.xcodeproj/`
- The CI build runs with Swift 6 strict concurrency; warnings count as errors
