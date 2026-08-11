<div align="center">

<img src="Design/icon/render/boreas-256.png" width="128" alt="Boreas icon">

# Boreas

**Mac fan control and temperature monitoring for Apple Silicon**

Free and open source. No kernel extension, no SIP changes, no telemetry.

[![CI](https://github.com/mahirozdin/boreas-mac-fan-control/actions/workflows/ci.yml/badge.svg)](https://github.com/mahirozdin/boreas-mac-fan-control/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-14.0%2B-lightgrey.svg)](#requirements)
[![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon-orange.svg)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-6.2-F05138.svg)](https://swift.org)

</div>

---

> **Status: not released yet.** The software is feature complete and runs on the
> developer's machine — it reads sensors, drives fans through a privileged
> helper, and hands them back on every failure path, all measured on real
> hardware. What is missing is **signing and notarisation**, without which macOS
> will not run the privileged helper on your Mac. Until then the only route is
> [building from source](#installation). See [the roadmap](#roadmap).

## What it does

<div align="center">
<img src="docs/images/panel-light.png" width="330" alt="The menu bar panel in light appearance: a profile picker, one fan at 2755 rpm, and temperatures grouped by compute, graphics, memory, storage and power">
<img src="docs/images/panel-dark.png" width="330" alt="The same menu bar panel in dark appearance">
</div>

Boreas is a menu bar app that shows what is happening inside your Mac and lets
you decide how it should be cooled.

- **Read every temperature sensor** your Mac exposes — performance and
  efficiency cores, GPU, memory, storage, power delivery, chassis
- **See fan speeds** with their real minimum and maximum
- **Shape the fan curve yourself** with a continuous curve rather than a list of
  on/off rules, so speed changes are smooth instead of stepped
- **Switch profiles automatically** based on power source, running app, time of
  day or thermal pressure
- **Record measurements** to JSONL or CSV, with a disk ceiling it will not cross
- **Get told when something changes** — thresholds, thermal pressure, a fan that
  stops tracking — with noise controls that a panic can still get through
- **Wire it into your own tools** with a webhook or a script, instead of an
  email client nobody wants to maintain
- **Read it in five languages** — English, Turkish, Russian, Spanish and
  Simplified Chinese
- **Stay quiet or stay cool** — the trade-off is yours to make, not the
  firmware's

## Why

On Apple Silicon, cooling is entirely firmware controlled and offers no
settings. That is a problem in both directions.

**Sometimes it is too quiet.** During a long compile, a video export or a
virtual machine run, the firmware ramps up late and conservatively. The chip
throttles, and work that could have finished faster does not.

**Sometimes it is too loud.** Recording audio, working at night, sitting in a
meeting — moments where a few degrees warmer would be a fine trade for silence.

Both come from the same place: the decision is closed to you. Boreas opens it.

## Requirements

| | |
|---|---|
| **Mac** | Apple Silicon — M1 or newer. Intel is out of scope by design |
| **macOS** | 14.0 Sonoma or newer |
| **Disk** | A few megabytes |

### Tested hardware

Boreas is developed on a single machine, so honesty about coverage matters more
than a long compatibility table.

| Hardware | Status |
|---|---|
| Mac mini (M4, 2024) — `Mac16,10` | **Verified on real hardware**: 40 named sensors, 1 fan measured from 1000 up to 4021 rpm on an edited curve and handed back on every failure path |
| Every other Apple Silicon Mac | **Should work; not verified.** Nobody has run it on one |

**What "not verified" means in practice.** Sensor naming differs between chip
generations, and multi-fan models exercise balancing code that has never met a
second fan. Nothing here is theoretical — the mapping is a heuristic over
hardware keys, and yours may produce sensors Boreas does not recognise.

If your Mac shows sensors as `uncategorized`, that is useful information —
**Settings → Sensors → Report These Sensors** opens a pre-filled
[unknown sensor report](https://github.com/mahirozdin/boreas-mac-fan-control/issues/new?template=unknown_sensor.yml)
in your browser, carrying your Mac's model identifier, chip, the unrecognised
sensor names and the fan count, and nothing else. Unmapped sensors are shown
rather than hidden precisely so they can be reported.

## Installation

**There is no release to install yet.** When there is, it will be a Homebrew
cask as the primary channel and a signed, notarised DMG as the alternative.
Neither exists today, and this section will say so until they do.

Until then, build it yourself:

```bash
git clone https://github.com/mahirozdin/boreas-mac-fan-control.git
cd boreas-mac-fan-control
brew bundle          # xcodegen, swiftlint, xcbeautify
make generate        # produces the Xcode project from project.yml
```

Then open `Boreas.xcodeproj` and run. **Monitoring works unsigned.** Fan control
needs the privileged helper, and macOS will only register a helper that is
signed with a Developer ID — so you will need your own signing identity in
`Local.xcconfig` (copy `Local.xcconfig.example` and fill in your team
identifier). Without it Boreas is a complete monitor that asks for nothing.

## Quick start

1. **Open Boreas.** It appears in the menu bar and starts reading sensors
   immediately — no permission, no setup, nothing to configure.
2. **Pick a profile** from the panel: Quiet, Balanced, Performance, or System to
   hand everything back to the firmware.
3. **Enable fan control** when you want the curve to actually drive the fans.
   This is the one step that asks for your administrator password, once.

Steps 1 and 2 are useful on their own. Step 3 is optional and reversible.

## Permissions

This is the part worth reading before you install anything that touches your
fans.

**What Boreas asks for**

| Permission | When | How often |
|---|---|---|
| Administrator password | Only when you enable fan control | **Once** |
| Background permission | When the fan helper is registered | Once, in System Settings |
| Notifications | Only if you turn alerts on | Once |

**What Boreas never asks for**

- ❌ Disabling System Integrity Protection
- ❌ A kernel extension or DriverKit driver
- ❌ Booting into Recovery or changing security policy
- ❌ Full Disk Access
- ❌ Accessibility or Screen Recording
- ❌ Camera, microphone, location, contacts or calendar

**Reading temperatures needs no privileges at all.** If you never enable fan
control, Boreas is a complete monitoring tool that asks for nothing.

Removing the app returns everything to the way it was. No firmware or NVRAM is
touched, and fan settings revert to the macOS defaults the moment Boreas stops.

## How it works

```
Your session (unprivileged)          Root                     Hardware
┌──────────────────────┐   XPC     ┌────────────────┐  IOKit ┌──────────────┐
│ Boreas.app           │◀────────▶ │ Fan helper     │◀─────▶ │ SMC          │
│  control engine      │  both     │  safety filter │        │ HID sensors  │
│  sensor reading ─────┼───────────┼────────────────┼──────▶ │ power source │
│  configuration       │  verify   │  watchdog      │        └──────────────┘
└──────────────────────┘  signature└────────────────┘
```

Reading temperatures needs no privileges, so it goes straight to the hardware.
Only writing fan speeds requires the helper, and the helper's entire surface is
four methods: describe the fans, apply targets, hand them back, and a heartbeat.

It reads no configuration, opens no network connection and starts no processes.

## The curve editor

<div align="center">
<img src="docs/images/curve-editor.png" width="820" alt="The control tab: a fan curve plotted from 0 to 120 degrees with five draggable points, a numeric point table, hysteresis and rate limit sliders, the five armed safety layers, and a manual override with a duration">
</div>

The curve is continuous, not a ladder of thresholds. Drag a point, double-click
to add one, right-click to remove. The shape cannot be made invalid — edits are
clamped rather than rejected, so no sequence of drags produces a curve that
falls as it gets hotter. Every edit reaches the fans within a cycle.

## Safety

Fan control software that gets this wrong damages hardware, so the design puts
safety ahead of user preference in five places.

| Layer | Rule | Can it be switched off? |
|---|---|---|
| Fan floor | Never below the hardware minimum | No |
| Thermal state | macOS reports `serious` → raise; `critical` → full speed | No |
| Panic threshold | Any sensor past the limit → full speed, held | No, only lowered |
| Helper guard | Out-of-range commands are refused, not clamped | No |
| **Watchdog** | No heartbeat → fans handed back to firmware | No |

The watchdog is the one that matters most. If Boreas crashes, hangs, is force
quit or you log out, the helper notices the silence and returns control to the
firmware on its own. It does not rely on the app to clean up after itself,
because the cases that matter are exactly the ones where it cannot.

Every layer can only raise fan speed. None of them can lower it.

**What Boreas cannot do:** it cannot cool a Mac whose firmware has already
stopped the fans, and it cannot exceed the maximum speed the hardware reports.
Where the firmware refuses a command, the helper refuses it too rather than
retrying.

## Privacy

- **No telemetry.** No analytics SDK, no crash reporting SDK, no advertising ID
- **No network by default.** Out of the box, Boreas makes no connections at all.
  The only code that can open one lives in a single directory, and only runs if
  you configure a webhook yourself
- **Your data stays yours**, in files you can read, on your machine

These are not promises about intent. They are checked on every commit by a
[gate that fails the build](scripts/gates/check-privacy.sh) if an analytics
symbol or an unexpected network call appears.

## Configuration

Everything lives in one file you can read, edit and put under version control:

```
~/Library/Application Support/Boreas/config.json
```

```json
{
  "schemaVersion": 1,
  "general": { "samplingIntervalSeconds": 2 },
  "safety": { "panicTemperatureCelsius": 95, "watchdogTimeoutSeconds": 15 },
  "profiles": [
    {
      "name": "Quiet",
      "priority": 0,
      "binding": {
        "input": { "group": "compute", "aggregate": "max" },
        "curve": [
          { "celsius": 40, "duty": 0    },
          { "celsius": 58, "duty": 0.15 },
          { "celsius": 72, "duty": 0.4  },
          { "celsius": 82, "duty": 0.7  },
          { "celsius": 88, "duty": 1    }
        ]
      },
      "hysteresis": 5,
      "smoothing": 0.2,
      "slew": { "maxRisePerSecond": 300, "maxFallPerSecond": 100 }
    }
  ]
}
```

That fragment is copied from a real `boreas export`, not written by hand — a
sample that does not load is worse than no sample.

A broken file can only ever fall back: Boreas keeps running on the last valid
state and leaves the fans with the firmware rather than acting on a document it
does not understand. `config.backup.json` is refreshed before every write.
Values out of range are clamped, not rejected.

Full schema: [`schema/config.schema.json`](schema/config.schema.json) ·
Reference: [`docs/architecture/configuration.md`](docs/architecture/configuration.md)

## Command line

`boreas` does everything the menu bar can, on a machine with no window server:

```
boreas status            temperatures, fans and power at a glance
boreas sensors [--raw]   every sensor, grouped; --raw shows hardware names
boreas profile [name]    list profiles, or activate one now
boreas profile --auto    hand the decision back to the profile triggers
boreas install           install the fan control helper
boreas uninstall [--all] remove the helper; --all also deletes saved settings
boreas export [file]     write the configuration; stdout when no file is given
boreas import <file>     replace the configuration, after validating it
```

```console
$ boreas status
power    : adapter
sensors  : 40  hottest PMU Die 1 75.1 C
fan 0    : Fan 1 1000 rpm (1000-4900, 0%)
control  : enabled
```

A profile chosen from the command line is **live only and never written to
disk** — a stored choice would override every profile trigger for good.

## Troubleshooting

Some of what looks like a fault is a safety guarantee doing its job, so the
short version is worth having in front of you:

| What you see | Most likely reason |
|---|---|
| Fan speeds never change | Fan control is not enabled — reading needs no privileges, writing needs the helper. Without it Boreas is a monitor and **shows no error**, by design |
| Helper stuck "waiting for approval" | macOS owns the second step: System Settings → General → Login Items & Extensions |
| The profile never switches by itself | A manual choice outranks every trigger and does not expire unless you gave it a time limit. `boreas profile --auto` hands the decision back |
| Speeds revert on their own | The watchdog. On quit, crash, sleep or log out the fans go back to the firmware unconditionally — that is the feature, not a bug |
| Fans pinned at full speed | The panic threshold or the macOS thermal state. Both release on their own; neither can be switched off |
| Sensors show as uncategorised | Sensor keys are opaque codes and unmapped ones are shown rather than hidden, so they can be reported |
| No notifications | Nothing is requested until you turn alerts on, and a refusal turns the switch back off |
| A setting did not stick | A profile chosen from the CLI is live only, on purpose. A broken config file falls back to the last valid state |

Full detail, including what to collect before opening an issue:
[`docs/operations/troubleshooting.md`](docs/operations/troubleshooting.md).

## Uninstall

```bash
boreas uninstall --all
```

That removes the privileged helper and deletes
`~/Library/Application Support/Boreas`. Then drag the app to the Trash.

Without `--all` the helper is removed and your settings are kept. Either way:

- **The fans go back to the firmware immediately** — the helper hands them over
  as it stops, and the watchdog would do it anyway
- No firmware setting, NVRAM variable or system file is touched, because none
  was ever written
- Nothing is left in `LaunchDaemons`, and `launchctl` no longer knows the
  service

This was verified from five angles rather than assumed — `SMAppService` status,
`launchctl`, the system folders, the deleted support directory and the absent
process. **It is not re-checked automatically:** `install` and `uninstall` change
the helper's registration and prompt for a password, so the command line test
suite deliberately exercises everything except those two.

## Roadmap

| Phase | Status |
|---|---|
| Documentation system and gates | ✅ Done |
| Toolchain and project scaffold | ✅ Done |
| Sensor and fan reading | ✅ Done |
| Privileged helper and XPC | ✅ Done |
| Fan control and safety chain | ✅ Done |
| Control engine — curves, hysteresis, profiles | ✅ Done |
| User interface and curve editor | ✅ Done (a VoiceOver pass is outstanding) |
| Notifications, logging, diagnostics, CLI, automation | ✅ Done |
| Signing, notarisation, release | 🔨 **In progress — the only thing between here and a download** |

Later, and deliberately not before 1.0: a WidgetKit widget, App Intents, a local
metrics endpoint, configuration sharing, and in-app updates.

Current status and next task: [`TODO.md`](TODO.md).

## Questions people actually ask

**Why is my Mac running hot?**
Usually sustained load — compiling, exporting video, running virtual machines.
Boreas shows you which part of the chip is hot, so you can tell a busy CPU from
a blocked vent.

**Can you control fan speed on Apple Silicon Macs?**
Yes, through the System Management Controller, with a small privileged helper.
Boreas asks for an administrator password once and never needs one again.

**Does this need SIP disabled or a kernel extension?**
No. Neither. That is the main reason this project exists in the shape it does.

**Is it safe to lower fan speeds?**
Lowering them raises thermal risk, which is why five safety layers can only ever
raise the speed, and three of them cannot be switched off.

**What happens if the app crashes?**
The helper stops receiving heartbeats and hands the fans back to the firmware
within seconds. This is tested, not assumed.

**Will it work on my Intel Mac?**
No. Intel Macs use a different sensor and SMC layout, and supporting both would
double a code base maintained by one person.

**Can it email me when my Mac gets hot?**
Not directly, and that is deliberate. A webhook or a one-line script can, and
neither makes this project responsible for storing your mail password — there is
a ready-made example in
[`docs/operations/notifications.md`](docs/operations/notifications.md).

## Contributing

Bug reports, hardware reports and translation fixes are all welcome. Please read
[`CONTRIBUTING.md`](CONTRIBUTING.md) first — it covers the setup, the workflow,
and the rules this project enforces on itself.

The most useful thing you can contribute right now is a **sensor report from a
Mac that is not an M4 mini**. Three of the five interface languages have not been
read by a native speaker either, and
[`TRANSLATORS.md`](TRANSLATORS.md) says exactly which.

### Development

```bash
make next            # tells you which task is next
make check           # runs every gate — must be green before pushing
make test            # Swift package tests
make smoke           # hardware smoke test on a real Mac
```

This repository uses a document driven workflow with machine enforced rules.
Start at [`BOOT.md`](BOOT.md), then [`AGENTS.md`](AGENTS.md), then
[`TODO.md`](TODO.md). Setup and the application's own diagnostic commands:
[`docs/development/setup.md`](docs/development/setup.md).

## Disclaimer

Boreas is provided as is, without warranty of any kind. **Lowering fan speeds
increases thermal risk, and the responsibility for that is yours.** Any effect on
your hardware warranty is likewise yours. This project is not affiliated with,
authorised by or endorsed by Apple Inc.

## License

[Apache-2.0](LICENSE). Attributions and trademark notices: [`NOTICE`](NOTICE).

<div align="center">
<sub>Boreas — the north wind.</sub>
</div>
