# Notifications and Automation

> Last updated: 2026-08-10 — P7.01
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

**Implementation (P7.01).** The noise control is a decision, so it lives in
[`Core/Presentation/NotificationPolicy.swift`](../../Packages/Core/Sources/Core/Presentation/NotificationPolicy.swift)
under property tests — every mechanism below is a pure function of (events,
history, settings, now), which is what makes "does the fifteen minute window
work" a one-line test instead of a fifteen minute wait. The words are in
[`NotificationWording.swift`](../../App/Sources/Notifications/NotificationWording.swift)
in the App layer, where the String Catalog can see them, and the tab is
[`NotificationSettingsTab.swift`](../../App/Sources/Settings/NotificationSettingsTab.swift).
Evidence: `--notification-drill` and `--render-settings`.

### What "Default: On" means, and what it does not

The table above says several triggers default to on. **It is not saying
notifications are on.** The subsystem itself ships disabled, because delivering
one needs a permission from macOS and this application does not ask for a
permission until the user asks it to — the same call as P6.10's global shortcuts,
which all ship unset. Read the table as *"once you turn notifications on, these
are the triggers that fire"*.

The permission is requested at the moment the switch is turned on, and if the
user refuses, **the switch goes back off** rather than staying on and delivering
nothing.

### The two health triggers, connected in P7.03

P7.01 shipped `fanAnomaly` and `batteryHealth` **wired and inert** — the switches
existed and nothing could produce the findings — and said so rather than hiding
it. P7.03 connected both to the real `Core` checks over the same readings the
diagnostics tab uses, so a notification and the tab can never disagree about
whether something is worth a look.

They are the two `isOncePerSession` kinds, which is what makes it safe to evaluate
them on every cycle: they describe a *condition*, not an event, and the policy
already refuses to say so twice in one launch.

### One trigger cannot be switched off

`Panic layer (K3) engaged` is always delivered, and no mechanism in the next
section can hold it back — not quiet hours, not the suppression window, not the
once-per-session rule. The reasoning is G2's one level up: the panic layer itself
cannot be disabled, so a notice saying it engaged cannot be silently swallowed
either. A machine cooling at full speed at three in the morning is telling its
owner something they need to know.

The exemption is deliberately **one** trigger wide, and a test asserts exactly
that — widening it is how this subsystem would quietly become un-silenceable,
which is the other way to make users switch it off.

## Noise control

The most common mistake in this category is a sensor oscillating around a threshold drowning the user in notifications. Four mechanisms:

1. **Suppression window** — a notification of the same type does not repeat within a default of 15 minutes (configurable 1–120 min)
2. **Once per session** — hardware health notifications (battery, fan anomaly) only once per application launch
3. **Coalescing** — if several thresholds are crossed at the same time, they merge into a single notification
4. **Quiet hours** — a separate time window can be defined; macOS Focus modes are respected as well

**How each is enforced (P7.01):**

| Mechanism | Rule as implemented |
|---|---|
| Suppression window | Per **(kind, subject)**, so two groups crossing their thresholds are two notices rather than one silencing the other. Default 15 min, clamped 1–120 by the type. A *withheld* notice never refreshes the timestamp — otherwise a sensor oscillating faster than the window would suppress itself forever |
| Once per session | The two hardware health kinds only. They describe a *condition*, not an event: a fan that is not tracking its targets still will not be in fifteen minutes |
| Coalescing | **Threshold crossings only.** Merging different kinds would let a profile change share an envelope with a panic, which is how the important one gets buried |
| Quiet hours | Spans midnight when start > end — the shape almost everybody wants, and the one a naive comparison gets exactly backwards. An empty window (start == end) means *no* quiet hours, because the safe reading of a mistake in a notification system is to notify |

The order matters and is stated once, in `NotificationPolicy`: the always-on
check short-circuits first, then the switches, then the timing, and **coalescing
comes last** — merging first would let a suppressed event drag its surviving
neighbours into one envelope.

Triggers fire on **edges, not levels**: the thermal state *becoming* serious, not
being serious. A level-triggered version would hand the policy the same event
every two seconds and lean on the suppression window to hide the flood, which
works right until somebody shortens the window. Threshold crossings carry their
own 2 °C release margin for the same reason.

The notification wording is bound by the **honesty rule** in
[`docs/operations/diagnostics.md`](diagnostics.md), and since P7.01 `make gate-i18n`
enforces its vocabulary over the `notify.` keys in every language — a
notification makes the same claim about somebody's hardware that a diagnostic
finding does, and makes it unprompted.

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
