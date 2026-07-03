# Golf Incremental — v4 Design

**Design source of truth for the orthographic range-tycoon redesign.** v2/v3 docs describe the shipped bucket → contact-swing → pickup loop and its economy tuning; this folder describes turning the *range itself* into a small buildable grid — literally placing hitting bays, RCT/Sims-style — without touching that core loop.

## One-liner

Same range rat superintendent, same one-hand contact swing, same bucket/pickup/upgrade economy — but the camera goes orthographic, the world reads as a grid, and "hiring crew" becomes **physically placing a hitting bay** in a small buildable strip beside the player instead of an abstract unlock.

## Relationship to v2/v3

| v2/v3 (current foundation) | v4 (this doc set) |
|---|---|
| Perspective `Camera3D`, over-the-shoulder | Orthographic `Camera3D`, 2:1 dimetric angle |
| One fixed diorama; camera never moves | Same fixed-size range; a small **buildable strip** beside the tee is grid-based |
| Crew (Ratina) = one bespoke hardcoded bay via `ratina_controller.gd` | Crew bays = instances of a generalized `HittingBayController`, placed on the grid |
| "Range amenities" = abstract upgrade-tree stat purchases | Unchanged in v4 — pickers/amenities stay abstract; only **hitting bays** are physical objects |
| Hire crew = buy upgrade node, layout hardcoded via `Marker3D` | Hire crew = buy a bay slot, click an empty grid cell, confirm placement |
| Single shared fairway lane down `-Z` | Each bay gets its own nominal parallel lane down `-Z`; lateral scatter can still cross into a neighbor's lane |
| Economy: hitting balls (active) + upgrade-tree passive multipliers | **Unchanged** — hitting balls stays the primary earner; passive income still comes from upgrades, hiring crew, buying more balls. No new economic mechanic, just a physical placement layer on top |

**Explicit non-goals** (see [00-vision.md](00-vision.md#what-we-are-not)): no Sims-style wandering/pathing, no growing/expanding world, no placeable pickers/amenities/decorations in v4, no replacement of the contact-swing minigame.

## Doc map

| Doc | Read if you are working on… |
|-----|----------------------------|
| [00-vision.md](00-vision.md) | Pillars, scope boundaries, what v4 is and isn't |
| [01-camera-and-world.md](01-camera-and-world.md) | Orthographic camera, dimetric angle, bay cell `EditorOnly/Camera3D` |
| [02-grid-and-placement.md](02-grid-and-placement.md) | Buildable strip, grid unit, placement UX |
| [03-crew-and-bays.md](03-crew-and-bays.md) | Generalized hitting-bay entity, multi-bay swinging, lanes |
| [04-economy-and-progression.md](04-economy-and-progression.md) | How bay purchase/placement plugs into existing economy |
| [05-migration-and-phasing.md](05-migration-and-phasing.md) | Phased build order against current code, in-place vs. parallel decision |

## Reading order

1. [00-vision.md](00-vision.md)
2. [01-camera-and-world.md](01-camera-and-world.md)
3. [02-grid-and-placement.md](02-grid-and-placement.md)
4. [03-crew-and-bays.md](03-crew-and-bays.md)
5. [04-economy-and-progression.md](04-economy-and-progression.md)
6. [05-migration-and-phasing.md](05-migration-and-phasing.md) before writing any code

## Agent rules (v4 additions)

1. **Contact-swing loop is untouched** — v4 is a camera/world/placement layer, not a mechanics rewrite.
2. **Economy formulas do not change** — bay purchase costs and per-bay income plug into existing `Balance`/`Economy`/`PlayerStats`, no new currency or resource type.
3. **In-place migration, not a parallel codebase** — see [05-migration-and-phasing.md](05-migration-and-phasing.md) for why. Use a branch or worktree for isolation while in flux.
4. **Additive before subtractive** — new camera/grid/ground code lands alongside the old fixed-diorama code; old code is deleted only after the new path is verified, not in a big-bang swap.
5. **Every doc in this set has two halves** — the design ideal, then how it maps onto current code (files, scripts, known seams). Keep both current as the migration proceeds.
6. **Buildable strip is the only placeable area** — the rest of the range (fairway, surrounding ground, fences) is fixed set-dressing in v4 scope.
7. v2/v3 docs are not deleted or superseded outside the camera/world/placement surface — the loop and economy docs remain authoritative.

## Third-party / assets

Unchanged from [main README](../README.md#third-party-assets).
