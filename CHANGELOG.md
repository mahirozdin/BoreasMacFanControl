# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The configuration schema is versioned separately; a breaking schema change
requires a MAJOR release.

## [Unreleased]

Nothing since 0.1.1.

## [0.1.1] — 2026-08-15

**Beta.** Nothing about monitoring, fan control or the safety chain changed. The
whole of this release is how the product presents itself, and all three defects
in it were found the same way: by downloading 0.1.0 and looking at it.

### Fixed

**The application had no icon.** The icon was designed in `Design/icon/` and
never wired into the bundle — no `.icns`, no `CFBundleIconFile` — so macOS drew
the generic placeholder in Finder, in `/Applications` and in the disk image
window. The bundle now carries `Boreas.icns`, built by `make icon`.

The artwork needed a second correction to be a macOS icon rather than a square
picture: Apple's grid puts the plate at 824×824 inside a 1024×1024 canvas, and
the source render was full-bleed. Rendered as-is it would have stood about a
quarter wider than every icon beside it.

**The disk image window was blank.** Three items in a row on an empty
background, with nothing to say that one of them should be dragged onto another.
It now opens at a fixed size with a background, the application and
`/Applications` on one line with an arrow between them, and the command line
tool below with a caption saying what it is.

**Every 0.x release was hidden from the repository page.** The release workflow
treated any `0.` version as a pre-release, and GitHub's "latest release"
deliberately skips those — so `/releases/latest` answered 404, the Releases
panel had nothing to show, and the only published version of this product
appeared on its own home page as the words "1 tag". A pre-release is now
something a tag says (`-beta`, `-rc`, `-alpha`), not something the major version
implies.

### Changed

The application and its privileged helper take their version from one value
rather than two literals kept in step by hand. They live inside the same bundle
and `SMAppService` compares them; a release that bumped one and forgot the other
would have shipped a mismatch nothing checked for.

A ninth release gate checks that the built bundle carries its icon and that the
disk image carries its window. It exists because every gate was green while both
were missing.

## [0.1.0] — 2026-08-12

**Beta.** Verified on one machine; see the release notes for what that means for
yours.

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
