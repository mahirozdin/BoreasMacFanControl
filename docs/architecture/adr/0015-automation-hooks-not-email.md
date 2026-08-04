# 0015 — Automation hooks instead of email notifications

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §8.4, §12.3

## Context

A user monitoring a remote Mac wants to be notified when a threshold is crossed. The classic solution is to embed an SMTP client in the application.

The real cost of that: credential storage, Keychain management, provider specific app passwords, TLS compatibility, automatic port/encryption discovery, delivery problems, and the perpetual maintenance of all of it.

## Decision

An SMTP client is **not written**. In its place, two generic mechanisms:

**① Webhook**
```json
{ "type": "webhook", "url": "https://…", "method": "POST", "template": "…" }
```

**② Shell command**
```json
{ "type": "command", "path": "~/bin/on-hot.sh", "arguments": ["${sensor}", "${celsius}"] }
```

Safety measures: the command hook is **off** by default, with an explicit warning when it is turned on; the command runs **with user privileges**, never inside the daemon; a timeout and a concurrency limit are applied.

## Alternatives

| Option | Why not |
|---|---|
| An embedded SMTP client | Enormous maintenance burden, responsibility for storing credentials, provider specific code |
| Local notifications only | Does not cover the remote server scenario |
| A third party notification service | Dependency + network + privacy surface (contrary to [0014](0014-zero-telemetry.md)) |

## Consequences

- ✅ Far less code, far less attack surface
- ✅ The responsibility for storing credentials disappears entirely
- ✅ Users wire up their own integrations — chat services, push notification tools, home automation platforms, the `mail` command
- ⚠️ A user who wants email must write their own script — the documentation ships a ready example
- ⚠️ The command hook carries a privilege escalation risk → off by default + a warning

## Enforcement

- `make gate-daemon` → red if the daemon spawns a subprocess
- `make gate-privacy` → network APIs only under `App/Sources/Automation/` and `App/Sources/Updates/`
- Unit test: the command hook is off by default
