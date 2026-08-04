# Glossary

> Last updated: 2026-07-31 — P0.13
> Source: blueprint §22

| Term | Definition |
|---|---|
| **Duty** | The fan's position between its minimum and maximum speed, 0.0–1.0. `rpm = fanMin + (fanMax − fanMin) × duty` |
| **Curve** | The piecewise linear function that maps temperature to duty. At least 2, at most 16 control points |
| **Control point** | A `(temperature, duty)` pair defining the curve |
| **Hysteresis** | Using different thresholds in the rising and falling directions to prevent oscillation. In Boreas, via the dual-curve method |
| **Slew limiting** | Constraining how much the output may change per unit of time. In Boreas it is **asymmetric**: rising is fast, falling is slow |
| **EWMA** | Exponentially weighted moving average — an input smoothing method |
| **Profile** | A named configuration set made of curves, parameters and triggers |
| **Trigger** | The condition under which a profile becomes active (power source, application, time of day, thermal state, etc.) |
| **Arbitration** | The process of selecting the active profile among several candidates |
| **Aggregate** | The method that produces a single value from a sensor group: `max`, `mean`, `p95` |
| **Safety chain** | The protection layers the engine output passes through before it reaches the hardware (K1–K5) |
| **Dead man's switch** | The mechanism that returns to a safe state automatically when the heartbeat stops |
| **Heartbeat** | The liveness signal the application sends to the daemon at regular intervals |
| **Takeover** | Fan control passing from the firmware to the software |
| **Handback** | Fan control being returned from the software to the firmware |
| **Thermal pressure** | The system-wide thermal state reported by the operating system (`nominal`/`fair`/`serious`/`critical`) |
| **Panic threshold** | The temperature above which the output is unconditionally 100% (K3) |
| **Gate** | A check that enforces an invariant by machine and blocks in CI |
| **Fake gate** | A check that appears to work but in fact verifies nothing |
| **Atomic task** | A task that can be finished in a single session and has a single piece of acceptance evidence |
| **Frozen source** | The copy of the initial specification that is never edited |
| **Live / Mock / Replay** | The three implementations of the hardware protocols: real, fake, and replaying from a log |
