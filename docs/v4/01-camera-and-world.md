# v4 Camera and World

## Design ideal

### Camera policy

| Property | Policy |
|----------|--------|
| **Rotation** | **Locked** project-wide — authored in `hitting_cell.tscn`, stored in [`V4CameraConfig`](../../scripts/config/v4_camera_config.gd) |
| **Position** | **Tunable** per scene (atomic cell vs. full range framing) |
| **Ortho `size`** | **Tunable** per scene (zoom) |
| **Projection** | Orthographic only in v4 |

All ground, fence, and prop art is authored against this locked rotation. Changing rotation requires re-checking art in `hitting_cell.tscn`.

### Canonical reference rig

**`scenes/range/hitting_cell.tscn`** — open directly in the editor to tune sprite layout and cell-rig camera position/size. Not instanced into `main.tscn`.

Script: [`scripts/range/hitting_cell.gd`](../../scripts/range/hitting_cell.gd) — applies locked rotation via `V4CameraConfig`; `camera_position` and `camera_size` exports on the root node.

### Locked rotation (source of truth)

Defined in [`scripts/config/v4_camera_config.gd`](../../scripts/config/v4_camera_config.gd) as `LOCKED_BASIS`:

```
|  0.9507437  -0.07534615   0.30068162 |
|  0.0         0.97000897   0.24306919 |
| -0.3099782  -0.23109649   0.9222299  |
```

Approximate euler (informational only — use `LOCKED_BASIS` in code): **(13.36°, -18.58°, -4.44°)**.

Locked via **Align Transform With View** in the atomic cell rig.

### Camera presets (locked in `hitting_cell.tscn`, commit `6bf2867`)

| Scene | Position | Ortho `size` | Notes |
|-------|----------|--------------|-------|
| Atomic cell rig (`hitting_cell.tscn`) | `(1.565, 2.851, 4.203)` | `8.0` | Frames one 2×2 yd cell |
| Full range (`range_view.tscn`) | `(0, 12, 12)` | `18.0` | Same rotation; tune to frame 50×300 yd grid |

Code reads cell camera values from the packed scene via [`V4AtomicCell`](../../scripts/config/v4_atomic_cell.gd). Range camera uses `RANGE_VIEW_DEFAULT_*` constants until tuned in editor.

```gdscript
V4CameraConfig.apply_locked_rotation(camera, position, ortho_size)
```

### Character sprites

Billboarded `AnimatedSprite3D` — tune position/offset/scale in `hitting_cell.tscn` only; range reads them through `V4AtomicCell`.

### World / ground

- Full range grid: 25×150 cells (50×300 yd) — see [02-grid-and-placement.md](02-grid-and-placement.md).
- Atomic cell rig: one 2×2 yd cell.
- Surrounding ground / fences: extended to full grid (fence dimetric art polish still open).

## Implementation against current code

| Asset | Status |
|-------|--------|
| `scripts/config/v4_camera_config.gd` | Locked basis + range/cell defaults |
| `scripts/config/v4_atomic_cell.gd` | Reads sprite layout from packed `hitting_cell.tscn` |
| `scenes/range/hitting_cell.tscn` | Locked cell camera + golfer/ball layout |
| `scenes/range/range_view.tscn` | Same `LOCKED_BASIS`; range position/size separate from cell rig |

### Remaining

- Tune `range_view` camera position/size for full fairway framing (rotation fixed)
- Fence reorientation for dimetric angle (visual polish)
- Phase E: instance `hitting_cell.tscn` per crew bay

## Related docs

- Atomic cell sprites: [03-crew-and-bays.md](03-crew-and-bays.md)
- Grid: [02-grid-and-placement.md](02-grid-and-placement.md)
