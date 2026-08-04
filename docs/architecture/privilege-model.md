# Privilege Model and Permissions

> Last updated: 2026-07-31 — P0.20
> Source: blueprint §6 · Decisions: [ADR 0007](adr/0007-privilege-split.md), [ADR 0008](adr/0008-smappservice-xpc.md), [ADR 0009](adr/0009-watchdog-dead-man-switch.md)

## The complete list of requested permissions

| Permission | When | Frequency | Mandatory |
|---|---|---|---|
| Administrator authentication | When the fan daemon is first installed | **Once** | No — if skipped, monitoring mode |
| Approval to run in the background | During daemon registration | Once | For fan control, yes |
| Notification permission | When the user turns notifications on | Once | No |
| Launch at login | If the user enables it | Once | No |

## Permissions never requested — an explicit commitment

Published in the README and inside the application:

- ❌ Disabling SIP
- ❌ A kernel extension / DriverKit driver
- ❌ Recovery Mode or a security policy change
- ❌ Full Disk Access
- ❌ Accessibility permission
- ❌ Screen Recording permission
- ❌ Camera / microphone / location / contacts / calendar
- ❌ An NVRAM or firmware change

## Installed files

> **Verified on real hardware in P3 (2026-08-04).** The P0 draft table assumed the paths
> of the previous generation helper install flow (`/Library/PrivilegedHelperTools/…`,
> `/Library/LaunchDaemons/…`) — **found error:** `SMAppService` writes to neither of
> these locations. With the helper registered and running, it was shown that neither
> directory contains any entry of ours (Run Log, 2026-08-04 P3 records).

| Location | Content | When it is written |
|---|---|---|
| The helper binary and the launchd definition inside `Boreas.app/Contents/Library/LaunchDaemons/` | `com.bubiapps.boreas.fanhelper` + `.plist` (`BundleProgram` points inside the bundle) | When the application is built — **installation copies nothing** |
| The system's background items database | Registration and approval state; visible under System Settings → Login Items | On the `register()` call |
| `~/Library/Application Support/Boreas/` | Configuration and local data | **Not written yet** — the first writer will be P5 |

Because installation copies no files into system folders, removal is a single
`unregister()` call; all that remains behind is the registration to be deleted, and the
class of orphaned files never comes into existence.

## Daemon installation

**`SMAppService.daemon(plistName:)`** is used — the legacy `SMJobBless` flow is not.

**The flow** (its counterpart in the application: `App/Sources/Helper/` — the setup window and its model):

1. The user opens the fan control setup from the menu bar panel. On a model with no
   controllable fan this entry is never shown; and while the helper is not installed,
   that is not presented as an error either (I4)
2. **What will happen, which files will be written where, and how it can be undone are
   shown in the same window before the install button**
3. `register()` is called. In the macOS 13+ flow this mostly lands in the
   `requiresApproval` state — not an error but the documented approval flow
4. The application detects this state, takes the user straight to the relevant System
   Settings panel with a single button and polls the status at a regular interval until
   approval arrives — once it does, it proceeds on its own; there is no "go back and
   refresh" step
5. The connection is proven end to end (a nonce round trip + a fan dump, with signature
   verification in both directions) and the outcome is reported to the user

## Removal

Three paths, all three ending at the same place:

1. **Interface** — the Remove button in the setup window (`unregister()`)
2. **CLI** — `boreas uninstall` removes the helper; `--all` additionally deletes the
   `~/Library/Application Support/<application name>/` directory. Because `SMAppService`
   registration is tied to the calling process's bundle, the CLI delegates removal to
   the application's maintenance entry point; if nothing is registered, the command
   returns success, not an error (idempotent). The directory name is read from the
   bundle discovered at runtime (K2)
3. **System Settings** — the switch under Login Items is turned off

That removal leaves no file behind was proven on real hardware from five angles:
`SMAppService` status, a `launchctl` query, the system folders, the user data directory
and the process list (Run Log, 2026-08-04 P3.06). The manual removal steps in the
product README will be written in P8.05.

> **Known edge:** if a remove → immediate reinstall sequence happens within a sub-second
> window, `register()` can temporarily return `Operation not permitted` (while the
> asynchronous cleanup of the background registration settles). A few seconds later the
> same call succeeds; the "Try Again" button in the interface covers this case.

## Dead man's switch

The distinguishing safety element of the design → [ADR 0009](adr/0009-watchdog-dead-man-switch.md)

- The application sends the daemon a regular **heartbeat** (default 5 s)
- If the daemon misses **3 consecutive heartbeats** (≈15 s), it hands the fans back to firmware unconditionally
- Scenarios covered: crash · `kill -9` · freeze · session logout · a dropped XPC connection
- It also hands back **immediately** on: system sleep · system shutdown · the daemon being stopped
- The timeout is **locked between 10–60 s** and cannot be disabled

**Design rationale:** A fault in a user space application must under no circumstances leave the hardware unprotected. The party holding control must be responsible for the health check.

## Daemon security surface

The XPC interface is deliberately minimal:

```
describeFans()          // read only
applyTargets([FanTarget])  // within limits
releaseToFirmware()
heartbeat(nonce:)
```

The daemon: **accepts no** file path/command/script · **reads no** configuration · **has no** network access · **spawns no** subprocess.

`make gate-daemon` enforces all of this.
