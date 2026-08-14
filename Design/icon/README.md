# Boreas — Application Icon

> Last updated: 2026-08-03 — M08
> Source: blueprint §9.1 · Decision: [ADR 0002](../../docs/architecture/adr/0002-product-name.md)

## Files

| File | Role |
|---|---|
| `boreas-background.svg` | Back layer — full-canvas gradient fill |
| `boreas-foreground.svg` | Front layer — four blades + hub, transparent background |
| `preview.html` | Size scale, Dock context, dark theme preview |
| `render/*.png` | Reference renders (not the source — the SVGs are the source) |

## Design

Four wide, swept blades and a prominent hub. A cold blue gradient (the north wind).

**Why this shape:**

- **The blades are wide.** Thin strips read as a "spider" or an "X". The wide angular span of the outer arc (70°) makes the shape read as a fan at first glance.
- **Four blades.** On a square canvas, 4-fold symmetry sits more naturally than 3-fold; three blades can be confused with a pinwheel or a recycling symbol.
- **30° sweep.** The sense of rotation is conveyed without motion blur — the Liquid Glass render would clash with blur.
- **The hub swallows the blade roots.** The root arc is r=130, the hub disc r=145; blade and hub form a single silhouette.

## Technical specification

| Parameter | Value |
|---|---|
| Canvas | 1024 × 1024 |
| Centre | (512, 512) |
| Hub disc | r = 145 |
| Blade root arc | r = 130, 26° span |
| Blade outer arc | r = 385, 70° span |
| Sweep | outer arc centre +30° from the root centre |
| Outer bound | r = 385 → 127 px of margin inside the canvas |
| Blade count | 4, `rotate(n × 90)` |

## Liquid Glass rules followed

- ❌ **No platform mask** — the system applies the rounded rectangle
- ❌ **No baked-in shadow** — the system renders depth
- ❌ **No specular highlight** — the system renders light
- ❌ **No gradient on the front layer** — a single flat fill, so the four appearance variants (default / dark / clear / tinted) derive cleanly
- ✅ **The front layer has a transparent background**
- ✅ **No text** — nothing to convert to outlines
- ✅ **Rounded corners** — light refracts badly at sharp corners

## Building with Icon Composer

Icon Composer ships with Xcode 26 (inside `/Applications/Xcode.app`).

1. Open Icon Composer and create a new document.
2. Import `boreas-background.svg` as the **back layer**.
3. Import `boreas-foreground.svg` as the **front layer**.
4. Enable the Liquid Glass material on the front layer; leave the specular and shadow settings at the system defaults.
5. Preview the four appearance variants (default, dark, clear, tinted).
6. Export as `Boreas.icon` and add it to the application target.

> **Note:** the `.icon` file is not kept in this directory; it is added under `App/Resources/` when the application target is created in P6. This directory holds the **source** assets.

## What actually ships, and why it is not the above (P8.11)

The Icon Composer route describes macOS 26. This product's minimum is macOS
14.0 (invariant T2), and macOS 14 and 15 cannot read a `.icon` at all — a bundle
carrying only one would show the generic placeholder on most of the Macs this
project supports. **`App/Resources/Boreas.icns` is what ships**, built by
`make icon` (`scripts/make-icon.sh`) from `render/boreas-1024.png`.

Two of the rules above are inverted for that format, because a classic `.icns`
gets nothing applied to it by the system:

| Rule for `.icon` | What `.icns` needs | Why |
|---|---|---|
| No platform mask | The rounded rectangle is **baked in** | Finder applies none |
| No baked-in shadow | A restrained shadow is **baked in** | Apple's own icons carry theirs in the artwork |
| Full-bleed, edge to edge | Plate **inset to 824×824 of 1024×1024** | Apple's macOS grid. The full-bleed source measures x 0–1023, y 0–1023, and an icns built straight from it stands about a quarter wider than every icon beside it |

None of this touches the source SVGs, which remain full-bleed and mask-free and
stay correct for the Icon Composer build whenever macOS 26 becomes the floor.

**This gap went unnoticed for one release.** M08 delivered the design and
closed; no task ever wired it into a bundle, so v0.1.0 shipped with the
placeholder. Release gate 9 now checks that the built bundle carries an icon.

## About the renders

The PNGs under `render/` are **reference** images produced with ImageMagick. Because ImageMagick does not render SVG gradients, the background was produced separately and composited in. For the true appearance, rely on `preview.html` (WebKit) or the Icon Composer preview.

## Production method and provenance

This icon is **hand-written SVG geometry** — no generative image AI was used.

Rationale: the copyright origin of images produced with generative models is unclear. The project's legal stance ([`LEGAL.md`](../../LEGAL.md)) requires the origin of every asset to be clear. A parametrically defined vector file, with the reasoning for every number written in its comments, meets that requirement beyond dispute.

Design process: five narrow-blade variants were produced and rejected (they all read as an "X" or a vortex), then five more variants were tried with the wide-blade geometry. Rasterizing at full resolution revealed a junction gap invisible at preview size, and it was fixed.

## Reproducing

```bash
cd Design/icon
magick -size 1024x1024 gradient:'#5FC8F5-#123E86' /tmp/bg.png
magick -background none boreas-foreground.svg -resize 1024x1024 /tmp/fg.png
magick /tmp/bg.png /tmp/fg.png -composite render/boreas-1024.png
```
