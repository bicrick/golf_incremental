# v4 Camera and World

## Design ideal

### Camera policy

| Property | Policy |
|----------|--------|
| **Rotation** | **Locked** project-wide — `V4CameraConfig.LOCKED_BASIS` |
| **Position** | **Scene-authored** on each `Camera3D` (or bay `@export`); tunable at runtime via WASD pan |
| **Ortho `size`** | **Scene-authored** on each `Camera3D`; tunable at runtime via scroll zoom |
| **Projection** | Orthographic only in v4 |

All ground, fence, and prop art is authored against this locked rotation.

### Source of truth

**Rotation:** [`ratina_bay_cell.tscn`](../../scenes/range/cells/ratina_bay_cell.tscn) → `EditorOnly/Camera3D` basis → [`scripts/config/v4_camera_config.gd`](../../scripts/config/v4_camera_config.gd) `LOCKED_BASIS`. Re-sync **basis only** when the dimetric angle changes.

**Position / size:** saved in each scene's `Camera3D` node — [`range_view.tscn`](../../scenes/range/range_view.tscn) for the live range, bay cell scenes for per-bay preview rigs. Code never overwrites these at runtime except to enforce locked rotation.

`player_bay_cell.tscn` and `range_view.tscn` call `V4CameraConfig.apply_locked_rotation_only()` (range) or `apply_locked_rotation()` with bay exports (cells). **Ratina bay still uses its scene camera directly** until verified — do not point ratina at the global config yet.

Root exports on [`bay_cell.gd`](../../scripts/range/bay_cell.gd): `camera_position`, `camera_size` — applied via `V4CameraConfig.apply_locked_rotation()` for player bay only.

**Editor note:** Godot has no "align view to camera." Use split viewport + Preview to see camera output while editing sprites in the main pane. To fix bottom sky bleed, move the camera back (+Z) and up (+Y) in the editor and adjust ortho `size`; save the scene.

### Locked rotation

From `ratina_bay_cell.tscn` `EditorOnly/Camera3D` → basis columns of the transform matrix:

```
|  0.9608136  -0.06625118   0.26916188 |
|  0.0         0.97101825   0.23900528 |
| -0.27719548 -0.2296395    0.93296754 |
```

When syncing from the editor, paste the basis columns into `v4_camera_config.gd` — do not hand-build a `Basis` from the first three floats.

Approximate euler (informational only): **(13.36°, -18.58°, -4.44°)**.

### Runtime API

```gdscript
# Range / any scene-owned Camera3D — preserve editor position + size:
V4CameraConfig.apply_locked_rotation_only(camera)

# Bay cells — position/size from @export fields:
V4CameraConfig.apply_locked_rotation(camera, position, ortho_size)
```

Pan/zoom home rig is whatever the scene camera holds at load; `range_camera_controller.gd` reads position and size from the camera on setup.

Live range framing beyond the home cell uses scroll zoom-out and WASD pan (`range_camera_controller.gd`).

### Character sprites

Billboarded `AnimatedSprite3D` — tune position/offset/scale in the bay cell `.tscn`; `range_view` instances `player_bay_cell.tscn` at `RangeGrid.player_bay_origin()`.

### World / ground

- Full range grid: 25×150 cells (50×300 yd) — see [02-grid-and-placement.md](02-grid-and-placement.md).
- Per-cell 2×2 yd floor via `CellGround.build_grid_mesh()` on range `Ground`.
- Flat green surround plane under the cell grid (`FairwayGrassTiles3D.apply_surround()`), sized from scene camera ortho `size`.

## Implementation against current code

| Asset | Status |
|-------|--------|
| `scenes/range/cells/ratina_bay_cell.tscn` | **Reference** camera rig (not yet on global config) |
| `scripts/config/v4_camera_config.gd` | `LOCKED_BASIS` only; rotation lock helpers |
| `scenes/range/cells/player_bay_cell.tscn` | Bay exports + locked rotation |
| `scenes/range/range_view.tscn` | Scene Camera3D is position/size source of truth |
| `scripts/range/range_camera_controller.gd` | WASD pan + scroll zoom |

### Remaining

- Wire ratina bay to `V4CameraConfig` after visual verification
- Instance crew bays on the buildable strip
- Fence reorientation for dimetric angle (visual polish)

## Related docs

- Bays: [03-crew-and-bays.md](03-crew-and-bays.md)
- Grid: [02-grid-and-placement.md](02-grid-and-placement.md)
