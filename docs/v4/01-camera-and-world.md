# v4 Camera and World

## Design ideal

### Camera policy

| Property | Policy |
|----------|--------|
| **Rotation** | **Locked** project-wide — stored in [`V4CameraConfig`](../../scripts/config/v4_camera_config.gd) |
| **Position** | **Tunable** per scene (bay cell vs. full range framing) |
| **Ortho `size`** | **Tunable** per scene (zoom) |
| **Projection** | Orthographic only in v4 |

All ground, fence, and prop art is authored against this locked rotation.

### Bay cell tuning camera

Tune in [`scenes/range/cells/player_bay_cell.tscn`](../../scenes/range/cells/player_bay_cell.tscn) → `EditorOnly/Camera3D`, or the same node in `ratina_bay_cell.tscn`.

Root exports on [`bay_cell.gd`](../../scripts/range/bay_cell.gd): `camera_position`, `camera_size` — apply locked rotation via `V4CameraConfig`.

**Editor note:** Godot has no "align view to camera." Use split viewport + Preview to see camera output while editing sprites in the main pane.

### Locked rotation (source of truth)

Defined in [`scripts/config/v4_camera_config.gd`](../../scripts/config/v4_camera_config.gd) as `LOCKED_BASIS`:

```
|  0.9507437  -0.07534615   0.30068162 |
|  0.0         0.97000897   0.24306919 |
| -0.3099782  -0.23109649   0.9222299  |
```

Approximate euler (informational only): **(13.36°, -18.58°, -4.44°)**.

### Camera presets

| Scene | Position | Ortho `size` | Notes |
|-------|----------|--------------|-------|
| Bay cell (`player_bay_cell.tscn` `EditorOnly/Camera3D`) | `(1.565, 2.851, 4.203)` | `8.0` | Frames one 2×2 yd cell |
| Full range (`range_view.tscn`) | `(0, 12, 12)` | `18.0` | Same rotation; frames 50×300 yd grid |

```gdscript
V4CameraConfig.apply_locked_rotation(camera, position, ortho_size)
```

### Character sprites

Billboarded `AnimatedSprite3D` — tune position/offset/scale in the bay cell `.tscn`; `range_view` instances the prefab at grid origin.

### World / ground

- Full range grid: 25×150 cells (50×300 yd) — see [02-grid-and-placement.md](02-grid-and-placement.md).
- Per-bay 2×2 floor via `cell_ground.gd` on each bay's `Ground` node.
- Surrounding ground / fences: extended to full grid (fence dimetric art polish still open).

## Implementation against current code

| Asset | Status |
|-------|--------|
| `scripts/config/v4_camera_config.gd` | Locked basis + range/cell defaults |
| `scenes/range/cells/player_bay_cell.tscn` | Cell camera + player sprite layout |
| `scenes/range/cells/ratina_bay_cell.tscn` | Same camera; Ratina sprite layout |
| `scenes/range/range_view.tscn` | Range camera; instances bay prefabs |

### Remaining

- Tune `range_view` camera position/size for full fairway framing (rotation fixed)
- Fence reorientation for dimetric angle (visual polish)

## Related docs

- Bays: [03-crew-and-bays.md](03-crew-and-bays.md)
- Grid: [02-grid-and-placement.md](02-grid-and-placement.md)
