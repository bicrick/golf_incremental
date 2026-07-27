# v4 Camera and World

## Design ideal

### Camera policy

| Property | Policy |
|----------|--------|
| **Rotation** | **Locked** project-wide — `V4CameraConfig.LOCKED_BASIS` |
| **Position** | **Scene-authored** on each `Camera3D` (or bay `@export`); tunable at runtime via WASD pan |
| **Ortho `size`** | **Scene-authored** on each `Camera3D`; tunable at runtime via scroll zoom |
| **Projection** | Orthographic only for harvest / build (strike still uses perspective) |

All ground, fence, and prop art is authored against this locked rotation.

### Angle contract (PixelLab-compatible)

Harvest / build ortho is **true 2:1 dimetric**:

| Euler (Godot YXZ) | Value |
|-------------------|-------|
| Pitch | **-26.565°** (`arctan(1/2)`) |
| Yaw | **45°** |
| Roll | **0°** |

This matches PixelLab `create_tiles_pro(tile_type="isometric")` diamonds and Godot TileSet `tile_size = Vector2i(32, 16)`. Future buildable terrain, fence, and bay kits must be authored for this projection only.

Strike / flight still uses `PerspectiveCamera` — do not apply `LOCKED_BASIS` to it.

### Source of truth

**Rotation:** [`scripts/config/v4_camera_config.gd`](../../scripts/config/v4_camera_config.gd) `LOCKED_BASIS`. Scenes and bay editor cameras sync from this constant. Runtime always re-applies it via `apply_locked_rotation_only()`.

**Position / size:** saved in each scene's `Camera3D` node — [`range_view.tscn`](../../scenes/range/range_view.tscn) for the live range, bay cell scenes for per-bay preview rigs. Code never overwrites these at runtime except to enforce locked rotation.

`range_view.tscn` and bay cells (`bay_cell.gd`) call `V4CameraConfig.apply_locked_rotation_only()` / `apply_locked_rotation()`. Ratina and player bay editor previews use the same lock.

Root exports on [`bay_cell.gd`](../../scripts/range/bay_cell.gd): `camera_position`, `camera_size` — applied via `V4CameraConfig.apply_locked_rotation()`.

**Editor note:** Godot has no "align view to camera." Use split viewport + Preview to see camera output while editing sprites in the main pane. To fix framing, move the camera along the look-back ray (opposite of look ≈ `(-0.63, -0.45, -0.63)`) and adjust ortho `size`; save the scene. Do not change roll or yaw.

### Locked rotation

Basis columns of `LOCKED_BASIS` (`rotation_degrees = Vector3(-26.565, 45.0, 0.0)`):

```
|  0.70710678  -0.31622720   0.63245581 |
|  0.0          0.89442759   0.44721280 |
| -0.70710678  -0.31622720   0.63245581 |
```

`.tscn` Transform3D layout is `(xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz)`. Basis columns are `(xx,yx,zx)`, `(xy,yy,zy)`, `(xz,yz,zz)`.

When changing the angle, update `LOCKED_BASIS` first, then paste the same basis into every ortho `Camera3D` transform — do not hand-build a `Basis` from the first three floats.

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

- Full range grid: see [02-grid-and-placement.md](02-grid-and-placement.md).
- Per-cell 2×2 yd floor via `CellGround.build_grid_mesh()` on range `Ground`.
- **Obsolete:** green apron surround + 3D forest impostors removed. Build/forest dressing lives in the 2D isometric view — see [06-isometric-build-view.md](06-isometric-build-view.md).

## Implementation against current code

| Asset | Status |
|-------|--------|
| `scripts/config/v4_camera_config.gd` | `LOCKED_BASIS` = 2:1 dimetric; rotation lock helpers |
| `scenes/range/range_view.tscn` | Scene Camera3D is position/size source of truth; basis synced |
| `scenes/range/cells/player_bay_cell.tscn` | Bay exports + locked rotation |
| `scenes/range/cells/ratina_bay_cell.tscn` | Editor preview uses same locked basis |
| `scripts/range/range_camera_controller.gd` | WASD pan + scroll zoom |
| `scenes/iso/iso_view.tscn` | Standalone 2D isometric build view |

### Remaining

- Instance crew bays on the buildable strip
- Pass 2: migrate harvest pickup into IsoView

## Related docs

- Bays: [03-crew-and-bays.md](03-crew-and-bays.md)
- Grid: [02-grid-and-placement.md](02-grid-and-placement.md)
