# Boreas — Disk Image Window

> Last updated: 2026-08-15 — P8.12
> Source: `scripts/make-dmg-background.sh`, `scripts/make-dmg-layout.sh`

## Files

| File | Role | Built by |
|---|---|---|
| `background.png` | The window's picture, 640×450 | `make dmg-background` |
| `background@2x.png` | The same at 1280×900 | `make dmg-background` |
| `DS_Store` | Window size, icon positions, the background reference | `make dmg-layout` |

All three are **committed build assets**. `scripts/make-dmg.sh` copies them into
every image it builds, combines the two PNGs into `.background.tiff` with
Apple's `tiffutil`, and never regenerates any of them. That is deliberate: the
machine that builds the shipped image is a CI runner, and neither of the
producing scripts can run there.

## Layout

```
        ┌───────────────────────────────────────────────┐
        │                    Boreas                     │
        │   Fan control and temperature monitoring…     │
        │                                               │
        │     [icon]  ───────────▶   [Applications]     │   y = 195
        │                                               │
        │                 [boreas]                      │   y = 320
        │      Optional command line tool — …           │
        └───────────────────────────────────────────────┘
              x = 170          x = 470      window 640×450
```

The numbers appear in **both** producing scripts and nothing checks that they
agree. Change one, change the other, and then look at the window — no script has
an opinion about whether an arrow points at the right place.

## Why the volume is always called `Boreas`

Finder records the background picture in `.DS_Store` as an alias, and an alias
resolves by volume name and path. A volume named after the version would break
its own layout on the next release. The version lives in the file name
(`Boreas-0.1.1.dmg`); the volume is always `Boreas`.

## Why Finder is not used to produce this

`make dmg-layout` used to drive Finder over AppleScript, which is what most
projects do. On **macOS 26.5.2 that is a trap**, and the trap is quiet:

- Finder still declares `background picture` in its dictionary and still writes
  it, but the AppleScript **getter** raises `-10000` instead of answering, and
  `properties` reports `missing value` for a background that is demonstrably
  present in the bytes. A script that verifies its work through Finder therefore
  reports failure on success — and would report success on failure just as
  readily.
- Asked to place the window at `{{200, 120}, {640, 450}}`, Finder wrote
  `{{200, 870}, {640, 450}}`. On a short display that opens the window mostly
  below the screen.

`dmgbuild` writes `.DS_Store` directly and never involves Finder, which is also
why it works on a machine with no session. It is a maintainer tool: install it
where it cannot reach the product, and note that **nothing in the build depends
on it**.

```bash
python3 -m venv ~/.venvs/dmgbuild
~/.venvs/dmgbuild/bin/pip install dmgbuild
DMGBUILD=~/.venvs/dmgbuild/bin/dmgbuild make dmg-layout
```

`make dmg-layout` verifies its own output by decoding it — the alias's volume
name, the background target, the icon size and the window rectangle are read
back out of the bytes it just wrote, not asked of Finder.

## Known limitation

A disk image background is one fixed picture, and Finder draws icon labels in
the system's text colour. In dark appearance those labels are white and sit on
this light background with less contrast than they deserve. The alternative
trades the problem the other way — a dark background loses the labels in light
appearance, which is the commoner case — so this is a choice rather than an
oversight.
