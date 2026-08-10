# Diagnostics

> Last updated: 2026-08-10 — P7.03
> Source: blueprint §13

Hardware health is presented as an **honest view that makes no overclaims**.

## Checks

| Check | Method | Output |
|---|---|---|
| **Fan response** | Deviation between target and actual RPM is tracked over time | Tracking the command / lagging / not responding |
| **Fan balance** | RPM difference between fans on multi-fan models | Balanced / abnormal difference |
| **Sensor validity** | Sensors stuck at a value, out of range, or disappearing | Healthy / suspect reading |
| **Thermal history** | Time spent in `serious`/`critical` state during the session | Duration and peak values |
| **Battery health** | Cycle count, capacity ratio, temperature | Informational summary |
| **Storage health** | Basic NVMe SMART fields | Informational summary |

## Honesty rule

> **The application never states as certain what it cannot know for certain.**

It does **not** say "the fan is faulty". Instead:

> *"The fan is not responding to commands as expected — the cause may be dust build-up, a cable connection or a hardware fault."*

and it suggests next steps to the user.

**Rationale:** a false positive "faulty" label sends the user to an unnecessary repair. In this category, the cost of a wrong diagnosis is higher than the cost of making no diagnosis.

**Implementation (P6.09): the rule is enforced by the type, not by the wording.** [`Core/Presentation/Diagnostics.swift`](../../Packages/Core/Sources/Core/Presentation/Diagnostics.swift) has **no case for "faulty"** — the strongest verdict is `needsAttention` — and one cannot be constructed without at least one possible cause, because an accusation with no explanation beside it is exactly what the rule forbids; a caller who tries gets `indeterminate`. A test asserts that no finding on any code path contains the words *faulty, broken, defective, failed, damaged, dead*, so a future branch cannot reintroduce them by accident. The presentation is [`App/Sources/Window/DiagnosticsTab.swift`](../../App/Sources/Window/DiagnosticsTab.swift); the discovered-hardware summary is [`SystemSummary.swift`](../../App/Sources/Window/SystemSummary.swift).

**What this build checks (P7.03): all six.** Fan response, fan balance, sensor
validity and thermal history came in P6.09 from data the monitor already
collects; battery and storage health arrived in P7.03 and read hardware the
application does not otherwise touch — behind `HealthSource`, with a Live and a
Mock like every other hardware access (M2). The checks are in
[`Core/Presentation/HealthChecks.swift`](../../Packages/Core/Sources/Core/Presentation/HealthChecks.swift),
the readers in
[`LiveHealthSource.swift`](../../Packages/HardwareKit/Sources/HardwareKit/Live/LiveHealthSource.swift).

### What is readable without privileges, measured rather than assumed

The design of both new checks follows from probing the machine, because guessing
would have produced a confident-looking stub:

| Field | Readable? | How |
|---|---|---|
| Battery installed / cycles / capacity / temperature | **yes** | `AppleSmartBattery` publishes them in the IO registry |
| Drive capacity and free space | **yes** | `URLResourceKey` volume values |
| Drive **wear** (NVMe SMART) | **no** | The drive advertises `NVMe SMART Capable = 1` and its user client even opens unprivileged, but the values are not published — reading them needs an undocumented user-client protocol whose selectors would have to be guessed at |

Three consequences, each deliberate:

- **"This Mac has no battery" is a definite answer, not an unknown.**
  `AppleSmartBattery` answers on desktops too, reporting `BatteryInstalled = 0`.
  So `batteryAbsent` (`notApplicable`) and `batteryUnreadable` (`indeterminate`)
  are different findings and must never share a sentence — one is a fact about
  the machine, the other a failure to read it.
- **Drive wear gets its own row** rather than a footnote on the storage check. A
  healthy verdict about *capacity* must not be read as a healthy verdict about
  the drive's life, and one combined sentence would invite exactly that.
- **The helper was not widened for it.** Reading SMART would mean guessing at
  kernel selectors or adding a fifth XPC method (M4). Neither is justified by an
  informational summary, and the check says the figure is unavailable instead.

### Wording, where it matters most

A battery notice is the easiest place in this product to accidentally accuse
hardware. Two rules hold it:

- **A worn battery leads with normal ageing.** 71% capacity after 940 cycles is a
  battery doing what batteries do; the first cause offered says so, and a test
  asserts that ordering.
- **A battery reporting 0% design capacity reads as *unreadable*, not as a dead
  battery.** It is almost certainly a failed read, and calling it a failure would
  be the exact false positive this rule exists to prevent.
- A warm battery is information only — a fan cannot cool a battery, so its next
  steps never suggest changing a fan profile, and a test checks that too.

**80% is the worn threshold** because it is the figure Apple's own service
documentation uses for the end of a battery's rated life — the one number here a
user may already have seen. A different threshold would be this project inventing
a standard.

**False positives are the risk that was tested.** A tolerance set too tight would tell every healthy owner their fan is not following commands. The application's `--diagnostics-drill` drives a known-good fan and insists the check comes back healthy: measured on the development machine, the fan followed its targets to within **69 rpm** on average against a 400 rpm tolerance.

## Coverage limit

**Multi-fan balance and the laptop battery branches cannot be verified** on the
development hardware (R8) — a single-fan Mac mini with no battery. They are
covered by `MockHealthSource` and by the Core tests, and marked "awaiting
community verification" in the README (manual task M07).
→ `docs/development/testing.md`

What the development hardware **can** verify, and does, in `--diagnostics-drill`:
the desktop battery path answers `notApplicable` with `batteryAbsent` — not
`indeterminate`, which would mean the read had failed — and the storage check
produces a real verdict rather than degrading, because capacity is readable
without privileges. Measured on this machine: 37% free at 39 °C, fan response
tracking to within **4 rpm**.
