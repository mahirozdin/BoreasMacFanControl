# Troubleshooting

> Last updated: 2026-08-10 — P7.08
> Source: blueprint §17.1 · Risk [R5](../reference/risks.md)

The problems most likely to bring somebody here, with what causes each one and
what to do about it.

**Read this first, because it explains four of the entries below.** Several of
the behaviours that look like faults are guarantees doing their job. Fan control
software that fails open damages hardware, so Boreas is built to return the fans
to the firmware whenever it is not certain it should be driving them. The
handback is not a symptom — it is the feature. Where that is what you are
seeing, the entry says so and points at the control you actually wanted.

## Quick triage

| What you see | Start at |
|---|---|
| Fan speeds never change | [1](#1-the-fans-never-change-speed), [2](#2-the-helper-says-it-is-waiting-for-approval) |
| Speeds reset on their own | [4](#4-the-fans-go-back-to-firmware-control-by-themselves) |
| Fans stuck at full speed | [5](#5-the-fans-are-at-full-speed-and-stay-there) |
| The profile never switches by itself | [3](#3-profiles-never-switch-automatically) |
| Sensors look wrong or unnamed | [6](#6-sensors-are-uncategorised-or-named-like-codes) |
| Nothing in the menu bar | [7](#7-the-menu-bar-item-is-missing) |
| No notifications | [8](#8-notifications-never-arrive) |
| Recordings missing | [9](#9-recording-stopped-or-files-disappeared) |
| Settings did not stick | [10](#10-a-setting-did-not-survive-a-restart) |

One command answers most questions before you read any further:

```bash
boreas status
```

The Diagnostics tab in the main window shows the same state with more detail,
including the helper's exact registration status.

> **A note on the labels quoted here.** This documentation is English only
> ([ADR 0016](../architecture/adr/0016-language-scope.md)), but the product speaks
> five languages and so does its command line output. On a Mac set to another
> language every button, tab and status word below appears translated — a Turkish
> system prints `control : etkin`, not `control : enabled`. Tab and status names
> are quoted in English throughout; match them by position and meaning rather
> than by the exact word. macOS supplies its own System Settings labels in the
> system language too.

---

## 1. The fans never change speed

**Most likely: fan control is not enabled.** Reading temperatures needs no
privileges at all, so Boreas is a complete monitoring tool the moment it opens.
Writing fan speeds needs the privileged helper, which is a separate, deliberate
step.

This is the one case where **the absence of an error is by design**. Invariant
I4 says that without the helper the application is a fully working monitor and
shows no error — so a Boreas that is only monitoring looks exactly like a Boreas
that is working, because it *is* working, just not driving anything.

Check which one you have — `boreas status` reports it on the `control` line, and
the Diagnostics tab shows the same value:

| Helper state | English text | What it means |
|---|---|---|
| Enabled | `enabled` | Installed and approved — fan control is available |
| Never installed | `not registered` | Enable fan control to install it |
| Awaiting approval | `waiting for approval in System Settings` | See [2](#2-the-helper-says-it-is-waiting-for-approval) |
| Missing from the bundle | `not found` | Reinstall the application |

**Second possibility: the `System` profile is selected.** `System` means "let the
firmware decide", and the engine deliberately emits no targets at all while it is
active. That is a valid choice, not a broken one. Pick any other profile to take
the wheel.

## 2. The helper says it is waiting for approval

Registering the helper is two steps, and macOS owns the second one. Boreas asks
for your administrator password once; macOS then requires you to approve the
background item yourself.

**System Settings → General → Login Items & Extensions**, then enable the entry
for Boreas. The setup window links straight there.

**A known timing edge:** if you remove the helper and reinstall it within about a
second, registration returns `Operation not permitted` and reports
`not registered`. Roughly eight seconds later the same call succeeds cleanly.
This was measured during development and is recorded in
[`privilege-model.md`](../architecture/privilege-model.md); the **Try Again**
button exists for it. Wait a moment and retry rather than reinstalling the app.

## 3. Profiles never switch automatically

**A manual profile choice outranks every trigger, and it does not expire unless
you gave it a time limit.** This is arbitration rule 1 in
[`control-model.md`](../product/control-model.md): a live manual selection beats
everything. Choose a profile once, and unless you set it to last a fixed period,
it holds until further notice — every trigger you subsequently configure is
evaluated and then ignored.

That is correct behaviour, and it is also the single most confusing consequence
of the design: nothing looks broken, the triggers all look right, and none of
them ever wins.

Hand the decision back:

```bash
boreas profile --auto
```

Or select automatic mode in the menu bar panel. The control tab always names the
reason the active profile is active, so it will say `manual` while this is what
is happening — that field is the fastest way to confirm it.

> **Boreas has to be running for the command to reach anything.** A selection
> made from the terminal is delivered to the application as a local notification
> and is never written to disk, so with the app closed there is nothing to
> receive it. The command does not currently detect that and reports success
> either way — if nothing changed, check the app is open and run it again.
> Tracked as P7.14.

## 4. The fans go back to firmware control by themselves

**This is the watchdog, and it is the safety guarantee the whole design is built
around.** The helper expects a regular heartbeat from the application. When the
heartbeat stops, it returns the fans to the firmware on its own, without waiting
to be asked.

It fires on quit, crash, force quit, log out, sleep and shutdown — unconditionally
(invariant G4). It deliberately does not rely on the application cleaning up
after itself, because the situations that matter most are exactly the ones where
the application cannot.

So if fan speeds revert when you quit Boreas, close the lid, or the app is killed,
nothing is wrong. If it happens **while Boreas is running and responsive**, that
is worth reporting — collect a support report first (see
[Collecting evidence](#collecting-evidence)).

## 5. The fans are at full speed and stay there

Two safety layers can do this, and neither can be switched off:

| Layer | When it fires | When it releases |
|---|---|---|
| **Panic threshold** | Any sensor passes the limit | **30 seconds after** the temperature recovers, not immediately |
| **Thermal state** | macOS reports `critical` | When macOS reports otherwise |

The 30 second hold is intentional — releasing the instant a spike passes
produces exactly the oscillation the engine exists to avoid. The hold re-arms on
every reading still above the threshold, so it expires 30 seconds after the
**last** excursion rather than the first.

You can **lower** the panic threshold in the Advanced tab but never raise it
(invariant G2, [ADR 0022](../architecture/adr/0022-panic-threshold-ceiling.md)).
If the fans are at full speed with everything reading cool, check the sensor
validity result in the Diagnostics tab: a sensor stuck at a high value will hold
panic open, and that check exists to find it.

Every safety layer can only raise fan speed. None of them can lower it, so no
combination of settings will quiet a Mac that one of these layers thinks is in
trouble.

## 6. Sensors are uncategorised or named like codes

Sensor identifiers on this hardware are opaque four character keys, not readable
names. Boreas maps the ones it recognises into groups and shows the rest
**exactly as the hardware reports them**.

**Unmapped sensors are displayed rather than hidden on purpose** — they are the
only signal that hardware support is incomplete, and hiding them would make the
gap invisible to the one person who can report it.

- Rename or re-file any sensor in the **Sensors** tab; the change is yours and
  persists
- Hiding a sensor is a display choice only. A hidden sensor still counts toward
  its group's aggregate and can still trigger panic — safety never depends on
  what you chose to look at
- If your Mac shows sensors as uncategorised, please send a report using the
  [unknown sensor template](../../.github/ISSUE_TEMPLATE/unknown_sensor.yml).
  This is the most useful contribution available, because the project is
  developed on one machine

## 7. The menu bar item is missing

macOS gives crowded-out menu bar items no usable frame, and on Macs with a notch
an item can also be laid out underneath it. Boreas detects both and warns rather
than disappearing silently.

Free up space by quitting other menu bar applications, or switch the status item
to **compact** mode in the General tab so it asks for less room.

## 8. Notifications never arrive

**Boreas does not ask for the notification permission until you turn the switch
on**, so if you have never enabled alerts, macOS has never been asked and will
not deliver anything. If you were asked and refused, the switch turns itself back
off rather than staying on and lying to you — so a switch that will not stay on
means the permission was declined. Grant it in System Settings, then enable the
switch again.

If the permission is granted and notifications are still sparse, that is probably
the noise control working. Several mechanisms deliberately suppress repeats — a
suppression window, coalescing, a once-per-session rule and quiet hours. All of
them are described in [`notifications.md`](notifications.md), and all of them can
be adjusted.

**One notification survives every one of those mechanisms stacked together: the
panic.** If your Mac reaches the panic threshold you will be told, whatever else
is configured.

## 9. Recording stopped or files disappeared

Recording is bounded by two different things, and the difference matters:

| Setting | What it is |
|---|---|
| **Retention** | A preference — how long you would like to keep measurements |
| **Disk ceiling** | A promise — how much space recordings may ever occupy |

The ceiling wins. When recordings would exceed it, the oldest are pruned even if
retention says they should still be here. **The file currently being written is
never deleted**, whatever either setting says.

Recordings live beside the configuration, under
`~/Library/Application Support/Boreas/Recordings`.

Write errors — a full disk, a permissions problem — are logged and deliberately
not allowed to propagate: a recording is a convenience, and losing it must never
take down temperature monitoring or fan control. The state is surfaced in
`boreas status` and in the Recording tab, so a recording that is failing says so
rather than failing invisibly.

## 10. A setting did not survive a restart

**A profile chosen from the command line is live only, and never written to
disk.** That is deliberate: a stored choice made outside the app would override
every profile trigger permanently, which is exactly problem
[3](#3-profiles-never-switch-automatically) reintroduced somewhere nobody would
think to look.

To change what is saved, use `boreas import`, or the settings window.

**If other settings were lost**, the configuration file was probably unreadable
at launch. A broken configuration can only ever fall back — Boreas keeps running
on the last valid state and leaves the fans with the firmware rather than acting
on a file it does not understand (invariant G6). Look for:

```
~/Library/Application Support/Boreas/config.json
~/Library/Application Support/Boreas/config.backup.json
```

The backup is refreshed **before** every write, so it holds the last state that
was known good. Values out of range are clamped rather than rejected, so a
hand-edited file usually loads with corrections instead of failing outright.
Schema: [`config.schema.json`](../../schema/config.schema.json).

---

## Collecting evidence

If none of the above fits, the support report is the fastest way to make a
problem examinable:

**Diagnostics tab → Create Support Report.** It produces **one local file** and
nothing is transmitted — there is no submission path in the product at all.

It is built from an allowlist rather than by redacting a dump, so the machine
name, serial numbers and your account name are absent by construction rather
than by being filtered out afterwards. Read it before you share it.

Also useful, and safe to paste:

```bash
boreas status
```

## When to open an issue

| Situation | Where |
|---|---|
| Sensors uncategorised on your Mac | Unknown sensor template — always welcome |
| A translated string is wrong | Translation fix template; see [`TRANSLATORS.md`](../../TRANSLATORS.md) |
| Fans hand back while Boreas is running normally | Bug report, with a support report attached |
| Anything touching security | **Not a public issue** — see [`SECURITY.md`](../../SECURITY.md) |

## Related

| Question | File |
|---|---|
| What do the diagnostic checks actually measure? | [`diagnostics.md`](diagnostics.md) |
| How do profiles, curves and arbitration work? | [`control-model.md`](../product/control-model.md) |
| Why is a privileged helper needed at all? | [`privilege-model.md`](../architecture/privilege-model.md) |
| What is in the configuration file? | [`configuration.md`](../architecture/configuration.md) |
| Which notification rules apply? | [`notifications.md`](notifications.md) |
