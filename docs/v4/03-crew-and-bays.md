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

**Canonical prefab:** [`scenes/range/hitting_cell.tscn`](../../scenes/range/hitting_cell.tscn)

This scene is the reusable hitting-bay rig. Future `HittingBayController` (Phase E) should instance this prefab (or equivalent node tree) per bay, offset by grid `cell_to_world()`.

**Cell footprint:** one **2×2 yd** square — `X ∈ [-1, +1]`, `Z ∈ [0, -2]` (near edge at `Z = 0`, depth toward `-Z`). Bay origin / tee line at `(0, 0, 0)` on the near-edge center.

### Sprite layout (author in `hitting_cell.tscn` only)

Tune golfer and ball in the reference rig; `range_view.tscn` is **not** synced until you explicitly port. Both sprites should start on the **near-edge line (`Z = 0`)** — depth into the cell is negative Z only.

| Node | Notes |
|------|-------|
| `Golfer` | Position + `FOOT_OFFSET`; scale `(1.3, 1.3, 1.3)` typical |
| `Ball` | Address position relative to golfer; scale `(0.55, 0.55, 0.55)` typical |

**Billboard:** both nodes `billboard = BILLBOARD_ENABLED`, `alpha_cut = DISCARD`, `texture_filter = NEAREST`.

### Editor alignment checklist

Open `hitting_cell.tscn` → tune until golfer feet sit on the near-edge grid line and the ball reads at the strike position:

1. `Golfer` → Transform → Position (Y may need small lift for foot contact on ground).
2. `Golfer` → Offset (pivot at feet via `FOOT_OFFSET`).
3. `Ball` → Position relative to golfer at address pose.
4. Toggle `show_grid_overlay` on `HittingCell` root to verify 2-yard alignment.
5. When locked, read transforms via `golfer_local_offset()` / `ball_local_offset()` on the rig script — port to `range_view` manually in a later step.

Helper methods on the rig script: `golfer_local_offset()`, `ball_local_offset()`, `golfer_local_scale()`, `ball_local_scale()` in [`scripts/range/hitting_cell.gd`](../../scripts/range/hitting_cell.gd).

## Implementation against current code

### What exists today

- **Reference prefab:** `hitting_cell.tscn` — sole source for atomic cell layout (in progress).
- **Live scene:** `range_view.tscn` still uses its own hand-placed transforms; not synced from the rig yet.
- `ratina_controller.gd` — template for generalized `HittingBayController`; duplicated flight pipeline vs. `range_view.gd::_fly_ball()`.

### Suggested approach

1. **Tune atomic cell** in `hitting_cell.tscn` — in progress.
2. **Port offsets** to `range_view.tscn` once locked.
3. **Phase E:** extract `HittingBayController` from `ratina_controller.gd`; instance `hitting_cell.tscn` per crew bay at `bay_origin()`.
4. **Phase F:** generalize `ratina_unlocked` → `hired_bays` collection in `GameState`/`SaveManager`.

## Related docs

- Camera / reference rig workflow: [01-camera-and-world.md](01-camera-and-world.md)
- Grid coordinates: [02-grid-and-placement.md](02-grid-and-placement.md)
- Phasing: [05-migration-and-phasing.md](05-migration-and-phasing.md)
