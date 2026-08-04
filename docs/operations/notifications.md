# Notifications and Automation

> Last updated: 2026-07-31 — P0.27
> Source: blueprint §12 · Decision: [ADR 0015](../architecture/adr/0015-automation-hooks-not-email.md)

## Notification triggers

| Trigger | Default |
|---|---|
| Sensor group crossed a threshold | Off (the user sets the threshold) |
| Thermal state `serious` or above | On |
| Panic layer (K3) engaged | On |
| Fan anomaly detected | On |
| Daemon connection lost / watchdog engaged | On |
| Profile changed | Off |
| Battery health degraded | On |

## Noise control

The most common mistake in this category is a sensor oscillating around a threshold drowning the user in notifications. Four mechanisms:

1. **Suppression window** — a notification of the same type does not repeat within a default of 15 minutes (configurable 1–120 min)
2. **Once per session** — hardware health notifications (battery, fan anomaly) only once per application launch
3. **Coalescing** — if several thresholds are crossed at the same time, they merge into a single notification
4. **Quiet hours** — a separate time window can be defined; macOS Focus modes are respected as well

## Automation hooks

An email/SMTP client is **not written** ([ADR 0015](../architecture/adr/0015-automation-hooks-not-email.md)). Instead, two generic mechanisms:

**① Webhook**
```json
{ "type": "webhook", "url": "https://…", "method": "POST", "template": "…" }
```
The user builds their own integration: a chat service webhook, ntfy, Home Assistant.

**② Shell command**
```json
{ "type": "command", "path": "~/bin/on-hot.sh", "arguments": ["${sensor}", "${celsius}"] }
```

### Safety measures

| Measure | Why |
|---|---|
| The command hook is **off by default** | Privilege escalation risk |
| An **explicit warning** is shown when enabling it | The user must know what they are accepting |
| The command runs **with user privileges** | **Never inside the daemon** — `make gate-daemon` enforces this |
| Timeout and concurrency limit | Prevents runaway process build-up |
| Network only under `App/Sources/Automation/` | `make gate-privacy` enforces this |

## For the user who wants email

The documentation provides a ready-made script example (using the system's `mail` command). This leaves the responsibility for credential storage entirely with the user and does not grow the application's attack surface.
