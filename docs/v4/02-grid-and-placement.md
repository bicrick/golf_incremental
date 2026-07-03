# v4 Grid and Placement

## Design ideal

### Full-range grid (world coordinate system)

The entire range uses a single **2-yard cell** grid:

| Axis | World span | Cells | Notes |
|------|------------|-------|-------|
| **X** (width) | 50 yd | 25 | Centered on range midline; `X ∈ [-25, +25]` yd |
| **Z** (depth) | 300 yd | 150 | Near edge at `Z = 0` (camera/tee side); deep edge at `Z = -300`; balls fly **down `-Z`** |

- **1 cell = 2 yards** — matches `FairwayGrassTiles3D.STRIPE_WIDTH_YARDS` / `TILE_SIZE_YARDS`.
- World unit remains **1 yard**; grid is a placement/coordinate layer on top.
- Range is **full-size from day one** — the grid does not grow. Unowned cells may be locked visually but the coordinate space is fixed.

### Player hitting cell placement

The player's atomic hitting cell sits on the **near edge** (`Z ≈ 0`), **centered on X** (midline of the 25-cell width). This is the anchor everything else is laid out from.

```
        deep edge (Z = -300)
              |
    · · · · · · · · · · · · · · · · · · · · · · · · · · ·
              |
         fairway / range body
              |
    [bay][bay][PLAYER][bay][bay]   ← near edge (Z ≈ 0), buildable row
              |
           camera
```

### Buildable strip (subset of the grid)

Only a **single row on the near edge** (`Z ≈ 0`) is buildable for hitting bays:

- Runs sideways along **X**, beside the player — same row Ratina occupies today.
- Small handful of slots — planning target **3–6 total bays including the player**.
- Slots are fixed in count from day one; empty slots start locked until purchased.
- **Only hitting bays** are placeable here — pickers/amenities stay abstract upgrade-tree purchases.

### Placement UX

1. Click an **empty grid cell** in the buildable strip.
2. Context menu shows what can go there (hitting bays only in v4) + cost.
3. Confirm → pay + place in one step.
4. No drag-and-drop, no auto-placement.

### Out of scope

- No placeable pickers, amenities, decorations, or paths on the grid.
- No moving a bay after placement.
- No grid cells outside the near-edge strip are player-placeable (rest is ground/layout bookkeeping).

## Implementation against current code

### What exists today

- **Bay cells:** [`player_bay_cell.tscn`](../../scenes/range/cells/player_bay_cell.tscn) and [`ratina_bay_cell.tscn`](../../scenes/range/cells/ratina_bay_cell.tscn) — 2×2 yd floor + sprites; tune and ship the same file.
- **Live range ground:** `range_view.gd` builds **50×300 yd** fairway via `FairwayGrassTiles3D.apply_palette()` with `RangeGrid.HALF_WIDTH_YARDS` (25) and `RangeGrid.DEPTH_YARDS` (300).
- **Forest fences:** `ForestFence.populate()` on `range_view.tscn` `ForestFence` node at full grid width/depth.
- **Grid helpers:** [`scripts/range/range_grid.gd`](../../scripts/range/range_grid.gd) — `bay_origin()`, `player_bay_origin()`, `ratina_bay_origin()`.
- **Runtime:** `range_view.gd` instances bay prefabs at `RangeGrid.player_bay_origin()` and `ratina_bay_origin()`.

### Coordinate convention (implemented)

- **Cell origin** for a hitting bay = center of the cell's near edge, at `Y = 0`.
- Player at grid cell **`(12, 0)`** → world bay origin `(0, 0, 0)`.
- Ratina at grid cell **`(10, 0)`** → world bay origin `(-4, 0, 0)`.
- Additional bays occupy neighboring X cells on row `Z = 0`.

### Still deferred

- Buildable-strip purchase/lock state and placement UI (Phase F).
- `world_to_cell()` helper (add when placement input lands).

## Related docs

- Camera / reference rig: [01-camera-and-world.md](01-camera-and-world.md)
- Atomic cell: [03-crew-and-bays.md](03-crew-and-bays.md)
- Phasing: [05-migration-and-phasing.md](05-migration-and-phasing.md)
