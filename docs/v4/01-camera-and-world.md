# v4 Camera and World

## Design ideal

### Camera policy

| Property | Policy |
|----------|--------|
| **Rotation** | **Locked** project-wide — set once in `hitting_cell.tscn`, stored in [`V4CameraConfig`](../../scripts/config/v4_camera_config.gd) |
| **Position** | **Tunable** per scene (atomic cell vs. full range framing) |
| **Ortho `size`** | **Tunable** per scene (zoom) |
| **Projection** | Orthographic only in v4 |

All ground, fence, and prop art is authored against this locked rotation. Changing rotation requires re-checking art in `hitting_cell.tscn`.

### Canonical reference rig

**`scenes/range/hitting_cell.tscn`** — open directly in the editor to tune sprite layout and cell-rig camera position/size. Not instanced into `main.tscn`.

Script: [`scripts/range/hitting_cell.gd`](../../scripts/range/hitting_cell.gd) — applies locked rotation via `V4CameraConfig`; only `camera_position` and `camera_size` exports are editable on the root node.

### Locked rotation (source of truth)

Defined in [`scripts/config/v4_camera_config.gd`](../../scripts/config/v4_camera_config.gd) as `LOCKED_BASIS`:

```
|  0.9507437  -0.07534615   0.30068162 |
|  0.0         0.97000897   0.24306919 |
| -0.3099782  -0.23109649   0.9222299  |
```

Approximate euler (informational only — use `LOCKED_BASIS` in code): **(13.36°, -18.58°, -4.44°)**.

Locked via **Align Transform With View** in the atomic cell rig (2026-03-06).

### Default camera presets (position + size — tunable)

| Scene | Position | Ortho `size` | Constant |
|-------|----------|--------------|----------|
| Atomic cell rig (`hitting_cell.tscn`) | `(1.061, 1.330, 1.896)` | `8.0` | `HITTING_CELL_DEFAULT_*` |
| Full range (`range_view.tscn`) | `(0, 12, 12)` | `18.0` | `RANGE_VIEW_DEFAULT_*` |

Apply locked rotation in code:

```gdscript
V4CameraConfig.apply_locked_rotation(camera, position, ortho_size)
```

### Character sprites

Billboarded `AnimatedSprite3D` — rotation locked on camera does not rotate sprites; tune position/offset/scale in the reference rig.

### World / ground

- Full range grid: 25×150 cells (50×300 yd) — see [02-grid-and-placement.md](02-grid-and-placement.md).
- Atomic cell rig: one 2×2 yd cell.
- Surrounding ground / fences: extended to full grid in Phase C (fence dimetric art polish still open).

### Depth cue

Flat orthographic size; depth via grid position. No distance-based sprite scaling.

## Implementation against current code

| Asset | Status |
|-------|--------|
| `scripts/config/v4_camera_config.gd` | Locked basis + helpers |
| `scenes/range/hitting_cell.tscn` | Reference rig with locked rotation |
| `scenes/range/range_view.tscn` | Live camera uses same `LOCKED_BASIS`; position/size are range defaults (tune for full fairway) |
| `hitting_cell.gd` | Enforces locked rotation on `_apply_camera()` |

### Remaining

- Fence *reorientation* for dimetric angle (visual style — quads extended to full size only)
- Phase E: instance `hitting_cell.tscn` per bay via `HittingBayController`

## Related docs

- Atomic cell sprites: [03-crew-and-bays.md](03-crew-and-bays.md)
- Grid: [02-grid-and-placement.md](02-grid-and-placement.md)
