# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The configuration schema is versioned separately; a breaking schema change
requires a MAJOR release.

## [Unreleased]

Nothing released yet. The signing chain is proven — see the notes below for what
exists — but no version has been tagged.

### Added

**Monitoring.** Every temperature sensor the hardware exposes, read without any
privilege at all, grouped by what it measures; fan speeds with their real limits.
Unrecognised sensors are shown rather than hidden, because they are the only
signal that support for a machine is incomplete.

**Fan control.** A continuous curve rather than a ladder of thresholds, with
dual-curve hysteresis, exponential smoothing and an asymmetric rate limiter.
Profiles switch on power source, foreground application, time of day, battery
level, external display or thermal pressure.

**A safety chain that can only ever raise fan speed.** A hardware floor, the
macOS thermal state, a panic threshold that can be lowered but never raised, a
helper that refuses out-of-range commands, and a watchdog that hands the fans
back to firmware when the application stops answering — on quit, crash, force
quit, sleep or log out, unconditionally.

**A privileged helper with a four-method surface.** It reads no configuration,
opens no network connection and starts no processes. Signature verification runs
in both directions. Reading temperatures needs no privilege; only writing fan
speeds does, and that asks for an administrator password once.

**Interface.** A menu bar panel and status item, a main window with temperature
and fan charts on one shared time axis, a curve editor whose edits cannot produce
an invalid curve, seven settings tabs, and diagnostics that never name a fault
they cannot know.

**Operations.** Notifications with suppression, coalescing, quiet hours and one
trigger — the panic — that survives all of them. Measurement recording to JSONL
or CSV under a hard disk ceiling. Six diagnostic checks. A support report built
from an allowlist, written locally, never transmitted. Automation hooks: a
webhook, or a command that runs with your privileges and only after two separate
switches are turned on.

**A command line tool**, `boreas`, that does what the menu bar does on a machine
with no window server.

**Five languages** — English, Turkish, Russian, Spanish and Simplified Chinese —
with the origin of each stated in `TRANSLATORS.md` rather than implied.

### Privacy

No telemetry, no analytics, no crash reporting, no advertising identifier, and no
network connection at all unless you configure a webhook yourself. Enforced by a
gate that fails the build.

### Notes

- Verified on one machine: a Mac mini (M4, 2024). Every other Apple Silicon Mac
  should work and none has been tried — see the README's tested hardware section.
- A VoiceOver pass over the critical flows is outstanding.
