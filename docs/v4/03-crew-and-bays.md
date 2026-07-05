# v4 Crew and Bays

## Design ideal

### Hitting bay as the one placeable entity type

v4 introduces exactly one placeable category: the **hitting bay**. The player's own tee is bay #0 (fixed, not replaceable/movable); every additional bay placed in the buildable strip is a **rat crew member**, generalized from what Ratina is today.

- **Static in place** — no wandering, no pathing. Animated in-place (idle/swing/follow-through).
- **Independent swing cadence per bay** — multiple simultaneous asynchronous swings.
- Crew keep their own upgrade progression (Ratina-style trees) — v4 changes *where* they stand, not *how* stats grow.

### Lanes

- Each bay fires down its **own nominal parallel lane** on `-Z`, offset on `X` by grid cell position.
- Lanes are reference lines, not hard rails — `Balance.LANDING_MAX_OFFLINE_DEG` offline angle can drift shots into neighboring lanes (intentional).
- Pickup uses world positions only; no per-lane litter logic needed.

### What doesn't change

- Contact-swing timing, tiers, payout formulas — per-bay instances of existing mechanics.
- Single `GameState` currency — no per-bay wallets.

## Bay prefabs (ship what you tune)

Two scenes — open, align sprites, save, run:

| Prefab | Purpose |
|--------|---------|
| [`player_bay_cell.tscn`](../../scenes/range/cells/player_bay_cell.tscn) | Player bay — Range Rat + ball |
| [`ratina_bay_cell.tscn`](../../scenes/range/cells/ratina_bay_cell.tscn) | Ratina bay — tune sprites independently |

### Scene layout

```
PlayerBayCell / RatinaBayCell  (bay_cell.gd)
├── EditorOnly                 ← freed at runtime (camera, sun, grid)
│   ├── WorldEnvironment
│   ├── Sun
│   ├── Camera3D
│   ├── GridOverlay
│   └── TeeMarker
├── Ground                     ← 2×2 grass (ships)
├── Golfer
└── Ball
```

Sprite frames are assigned in script; the `.tscn` stores transforms, offset, and scale only.

One **2×2 yd** cell. Root origin = bay tee point at the near-edge center `(0, 0, 0)`.

| Axis | Cell span |
|------|-----------|
| **X** | `-1` … `+1` yd |
| **Z** | `0` (near / tee line) … `-2` (deep) yd |
| **Y** | ground at `0` |

### Editor workflow

1. Open `player_bay_cell.tscn` or `ratina_bay_cell.tscn`.
2. Use split viewport + **Preview** on `EditorOnly/Camera3D` to align `Golfer` / `Ball`.
3. Save — `range_view` instances the same scene at `RangeGrid.bay_origin()`.

`EditorOnly` is active in the editor; at runtime it is `queue_free()`'d so the range camera and sun take over.

### Placing a bay on the range

```
bay_cell.position = RangeGrid.bay_origin(col, row)
```

Player bay: cell `(12, 0)` → origin `(0, 0, 0)`.

Ratina bay: cell `(10, 0)` → origin `(-4, 0, 0)`.

## Implementation against current code

| Asset | Status |
|-------|--------|
| `cell_ground.gd` | Shared 2×2 grass quad builder |
| `bay_cell.gd` | Ground, editor rig, sprite API |
| `player_bay_cell.tscn` / `player_bay_cell.gd` | Player bay |
| `ratina_bay_cell.tscn` / `ratina_bay_cell.gd` | Ratina bay |
| `range_view.gd` | Instances bays under `$Bays` |
| `ratina_controller.gd` | `setup(range_view, ratina_bay)` |

## Related docs

- Camera: [01-camera-and-world.md](01-camera-and-world.md)
- Grid: [02-grid-and-placement.md](02-grid-and-placement.md)
- Phasing: [05-migration-and-phasing.md](05-migration-and-phasing.md)
