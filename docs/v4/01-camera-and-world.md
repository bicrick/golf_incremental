# v4 Camera and World

## Design ideal

### Camera policy

| Property | Policy |
|----------|--------|
| **Rotation** | **Locked** project-wide — `V4CameraConfig.LOCKED_BASIS` |
| **Position** | **Home** at reference rig; tunable at runtime via WASD pan |
| **Ortho `size`** | **Home** at `8.0`; tunable at runtime via scroll zoom |
| **Projection** | Orthographic only in v4 |

All ground, fence, and prop art is authored against this locked rotation.

### Source of truth

**[`ratina_bay_cell.tscn`](../../scenes/range/cells/ratina_bay_cell.tscn)** → `EditorOnly/Camera3D` is the reference rig.

Constants live in [`scripts/config/v4_camera_config.gd`](../../scripts/config/v4_camera_config.gd). When retuning the camera, edit ratina bay in the editor first, then re-sync that file.

`player_bay_cell.tscn` and `range_view.tscn` consume `V4CameraConfig`. **Ratina bay still uses its scene camera directly** until verified — do not point ratina at the global config yet.

Root exports on [`bay_cell.gd`](../../scripts/range/bay_cell.gd): `camera_position`, `camera_size` — applied via `V4CameraConfig.apply_locked_rotation()` for player bay only.

**Editor note:** Godot has no "align view to camera." Use split viewport + Preview to see camera output while editing sprites in the main pane.

### Locked rotation

From `ratina_bay_cell.tscn` `EditorOnly/Camera3D` → `V4CameraConfig.REFERENCE_HOME_TRANSFORM.basis` (columns of the transform matrix):

```
|  0.9608136  -0.06625118   0.26916188 |
|  0.0         0.97101825   0.23900528 |
| -0.27719548 -0.2296395    0.93296754 |
```

When syncing from the editor, paste the full `Transform3D(...)` line into `v4_camera_config.gd` — do not hand-build a `Basis` from the first three floats.

Approximate euler (informational only): **(13.36°, -18.58°, -4.44°)**.

### Camera home rig

| Constant | Value | Notes |
|----------|-------|-------|
| `HITTING_CELL_DEFAULT_POSITION` | `(1.470, 1.517, 2.156)` | From ratina reference camera |
| `HITTING_CELL_DEFAULT_SIZE` | `8.0` | From ratina reference camera |
| `RANGE_HOME_POSITION` | same as above | Range starts here |
| `RANGE_HOME_SIZE` | same as above | Range zoom floor |

```gdscript
V4CameraConfig.apply_locked_rotation(camera, position, ortho_size)
```

Live range framing beyond the home cell uses scroll zoom-out and WASD pan (`range_camera_controller.gd`).

### Character sprites

Billboarded `AnimatedSprite3D` — tune position/offset/scale in the bay cell `.tscn`; `range_view` instances `player_bay_cell.tscn` at `RangeGrid.player_bay_origin()`.

### World / ground

- Full range grid: 25×150 cells (50×300 yd) — see [02-grid-and-placement.md](02-grid-and-placement.md).
- Per-cell 2×2 yd floor via `CellGround.build_grid_mesh()` on range `Ground`.
- Flat green surround plane under the cell grid (`FairwayGrassTiles3D.apply_surround()`).

## Implementation against current code

| Asset | Status |
|-------|--------|
| `scenes/range/cells/ratina_bay_cell.tscn` | **Reference** camera rig (not yet on global config) |
| `scripts/config/v4_camera_config.gd` | Constants copied from ratina reference |
| `scenes/range/cells/player_bay_cell.tscn` | Uses `V4CameraConfig` |
| `scenes/range/range_view.tscn` | Uses `V4CameraConfig` |
| `scripts/range/range_camera_controller.gd` | WASD pan + scroll zoom |

### Remaining

- Wire ratina bay to `V4CameraConfig` after visual verification
- Instance crew bays on the buildable strip
- Fence reorientation for dimetric angle (visual polish)

## Related docs

- Bays: [03-crew-and-bays.md](03-crew-and-bays.md)
- Grid: [02-grid-and-placement.md](02-grid-and-placement.md)
