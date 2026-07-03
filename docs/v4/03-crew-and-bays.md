# v4 Crew and Bays

## Design ideal

### Hitting bay as the one placeable entity type

v4 introduces exactly one placeable category: the **hitting bay**. The player's own tee is bay #0 (fixed, not replaceable/movable); every additional bay placed in the buildable strip is a **rat crew member**, generalized from what Ratina is today.

- **Static in place** — no wandering, no pathing. Animated in-place (idle/swing/follow-through).
- **Independent swing cadence per bay** — multiple simultaneous asynchronous swings.
- Crew keep their own upgrade progression (Ratina-style trees) — v4 changes *where* they stand, not *how* stats grow.

### Lanes

- Each bay fires down its **own nominal parallel lane** on `-Z`, offset on `X` by grid cell position.
- Lanes are reference lines, not hard rails — `Balance.LANDING_SCATTER_YARDS` lateral scatter can drift shots into neighboring lanes (intentional).
- Pickup uses world positions only; no per-lane litter logic needed.

### What doesn't change

- Contact-swing timing, tiers, payout formulas — per-bay instances of existing mechanics.
- Single `GameState` currency — no per-bay wallets.

## Atomic hitting-cell template

**Editor rig (same scene as player bay):** [`scenes/range/hitting_cell.tscn`](../../scenes/range/hitting_cell.tscn) — alias of the player bay; open either this or `player_bay_cell.tscn` to tune.

**Runtime prefabs** (each is a full cell rig: `WorldEnvironment`, `Sun`, `Camera3D`, `Ground`, `GridOverlay`, optional sprites):

| Prefab | Contents |
|--------|----------|
| [`base_cell.tscn`](../../scenes/range/cells/base_cell.tscn) | **Exact copy of `player_bay_cell.tscn` with `Golfer` + `Ball` nodes removed** — same camera, ground, grid, subresources |
| [`player_bay_cell.tscn`](../../scenes/range/cells/player_bay_cell.tscn) | Identical to `hitting_cell.tscn` — Range Rat + ball |
| [`ratina_bay_cell.tscn`](../../scenes/range/cells/ratina_bay_cell.tscn) | **Copy of player bay** — only the golfer sprite sheet swapped to Ratina; ball and rig unchanged |

Embedded camera/lighting is **active in the editor** so you can align sprites as they will read in-game. When instanced under `range_view`, `set_embedded_rig_active(false)` hides the per-cell rig so the range camera and sun take over.

One **2×2 yd** cell. Root origin = bay tee point at the near-edge center `(0, 0, 0)`.

| Axis | Cell span |
|------|-----------|
| **X** | `-1` … `+1` yd |
| **Z** | `0` (near / tee line) … `-2` (deep) yd |
| **Y** | ground at `0` |

### Locked sprite layout (local to bay cell root)

Player bay sprites were copied from the locked `hitting_cell.tscn` rig. Ratina bay uses the same starting transforms but can be tuned in `ratina_bay_cell.tscn` without touching the player cell.

| Node | Position (local) | Scale | Other |
|------|------------------|-------|-------|
| `Golfer` | `(0.131, 1.692, -0.196)` | `(1.3, 1.3, 1.3)` | offset `(0, -26)`, pixel_size `0.024` |
| `Ball` | `(0.638, 0.166, -0.565)` | `(0.55, 0.55, 0.55)` | pixel_size `0.021` |

**Billboard:** `BILLBOARD_ENABLED`, `alpha_cut = DISCARD`, `texture_filter = NEAREST`.

### Placing a bay on the range

```
bay_cell.position = RangeGrid.bay_origin(col, row)
```

Sprites are authored inside the prefab at local positions; no per-frame layout copy step at runtime.

Player bay: cell `(12, 0)` → origin `(0, 0, 0)` — cell root sits at world origin.

### Re-tuning workflow

1. **Player layout:** edit sprites in `hitting_cell.tscn` (reference rig), then mirror transforms into `player_bay_cell.tscn`.
2. **Ratina layout:** edit `ratina_bay_cell.tscn` directly — independent of player bay.
3. **Camera:** tune in `hitting_cell.tscn` only; sync constants to `range_view.tscn` when satisfied.

## Implementation against current code

| Asset | Status |
|-------|--------|
| `hitting_cell.tscn` | Editor-only camera + layout reference rig |
| `cell_ground.gd` | Shared 2×2 grass quad builder |
| `base_cell.tscn` / `base_cell.gd` | Grass-only atomic floor |
| `player_bay_cell.tscn` / `player_bay_cell.gd` | Player bay prefab |
| `ratina_bay_cell.tscn` / `ratina_bay_cell.gd` | Ratina bay prefab |
| `range_view.gd` | Instances bays under `$Bays` at `player_bay_origin()` / `ratina_bay_origin()` |
| `ratina_controller.gd` | Binds to `ratina_bay_cell` via `setup(range_view, bay_cell)` |

## Related docs

- Camera: [01-camera-and-world.md](01-camera-and-world.md)
- Grid: [02-grid-and-placement.md](02-grid-and-placement.md)
- Phasing: [05-migration-and-phasing.md](05-migration-and-phasing.md)
