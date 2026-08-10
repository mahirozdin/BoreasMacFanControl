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

> **Status: in development.** The monitoring half works — Boreas reads named
> temperature sensors and fan speeds from real hardware today. Fan control is
> being built. There is no release yet; see [the roadmap](#roadmap).

## What it does

Boreas is a menu bar app that shows what is happening inside your Mac and lets
you decide how it should be cooled.

- **Read every temperature sensor** your Mac exposes — performance and
  efficiency cores, GPU, memory, storage, power delivery, chassis
- **See fan speeds** with their real minimum and maximum
- **Shape the fan curve yourself** with a continuous curve rather than a list of
  on/off rules, so speed changes are smooth instead of stepped
- **Switch profiles automatically** based on power source, running app, time of
  day or thermal pressure
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
| Mac mini (M4, 2024) — `Mac16,10` | Verified: 40 named sensors, 1 fan |
| Everything else | Should work; **not verified** |

If your Mac shows sensors as `uncategorized`, that is useful information —
please open an [unknown sensor report](https://github.com/mahirozdin/boreas-mac-fan-control/issues/new?template=unknown_sensor.yml).
Unmapped sensors are shown rather than hidden precisely so they can be reported.

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

## Privacy

- **No telemetry.** No analytics SDK, no crash reporting SDK, no advertising ID
- **No network by default.** Out of the box, Boreas makes no connections at all
- **Your data stays yours**, in files you can read, on your machine

These are not promises about intent. They are checked on every commit by a
[gate that fails the build](scripts/gates/check-privacy.sh) if an analytics
symbol or an unexpected network call appears.

## Development

```bash
git clone https://github.com/mahirozdin/boreas-mac-fan-control.git
cd boreas-mac-fan-control
brew bundle          # xcodegen, swiftlint, xcbeautify
make bootstrap       # checks the tools actually run, not just that they exist
make generate        # produces the Xcode project from project.yml
make next            # tells you which task is next
```

| Command | What it does |
|---|---|
| `make next` | Prints the next actionable task |
| `make check` | Runs every gate — must be green before pushing |
| `make build` / `make test` | Swift packages |
| `make lint` / `make format` | SwiftLint and swift-format |
| `make smoke` | Hardware smoke test on a real Mac |

The built application also answers a set of drill and render arguments used to reproduce the evidence in the run log — see [`docs/development/setup.md`](docs/development/setup.md#the-applications-own-commands).

There is also a `boreas` command line tool — `status`, `sensors`, `profile`, `install`, `uninstall`, `export`, `import` — documented in the same place.

This repository uses a document driven workflow with machine enforced rules.
Start at [`BOOT.md`](BOOT.md), then [`AGENTS.md`](AGENTS.md), then
[`TODO.md`](TODO.md). Contribution guide: [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Roadmap

| Phase | Status |
|---|---|
| Documentation system and gates | ✅ Done |
| Toolchain and project scaffold | ✅ Done |
| Sensor and fan reading | ✅ Done |
| Privileged helper and XPC | 🔨 In progress |
| Fan control and safety chain | ⏳ Next |
| Control engine — curves, hysteresis, profiles | ⏳ |
| User interface and curve editor | ⏳ |
| Notifications, logging, diagnostics, CLI | ⏳ |
| Signing, notarisation, release | ⏳ |

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

## Contributing

Bug reports, hardware reports and translation fixes are all welcome. Please read
[`CONTRIBUTING.md`](CONTRIBUTING.md) first — it covers the setup, the workflow,
and the rules this project enforces on itself.

The most useful thing you can contribute right now is a **sensor report from a
Mac that is not an M4 mini**.

## Disclaimer

Boreas is provided as is, without warranty. Lowering fan speeds increases
thermal risk and the responsibility for that is yours. This project is not
affiliated with, authorised by or endorsed by Apple Inc.

## License

[Apache-2.0](LICENSE). Attributions and trademark notices: [`NOTICE`](NOTICE).

<div align="center">
<sub>Boreas — the north wind.</sub>
</div>
