# v4 — Isometric Build View (2D)

The orthographic side of the game is a **separate 2D isometric scene**, not the same 3D world with an ortho camera. Strike stays atmospheric 3D perspective; build/placement lives in a true Godot `TileMapLayer` isometric view.

Harvest pickup still uses the 3D ortho camera for now (pass 2 will re-home it into this view).

## Architecture

| Layer | Role |
|-------|------|
| `RangeGrid` | Shared logical grid (19×200 cells @ 2 yd) |
| `IsoGrid` | Yards ↔ cell ↔ iso pixels (`scripts/iso/iso_grid.gd`) |
| `RangeView` | 3D perspective strike + current 3D harvest |
| `IsoView` | 2D TileMapLayer build mode (`scenes/iso/iso_view.tscn`) |
| `IsoWorldModel` | Placement occupancy + serialize |

```
IsoView (Node2D)
  Camera2D + IsoCameraController   # zoom steps 0.5/1/2/3/4, drag + WASD pan
  Terrain (TileMapLayer)           # fairway only (range_iso.tres)
  Paths   (TileMapLayer)
  Objects (Node2D, y_sort)         # buildings / props
  Overlay                          # placement ghost
  PlacementController
```

## Grid / texture contract

- Logical range: still `RangeGrid` **19×200** @ 2 yd
- Iso paint grid: `SUBCELLS = 1` → TileMap **19×200** (**1:1** with RangeGrid)
- Godot cell: `tile_size = Vector2i(64, 32)` (2:1). One RangeGrid cell = one TileMap cell
- Art authored at **64px** wide and displayed 1:1
- **Depth flip:** RangeGrid row increases downrange; iso Y decreases so the tee sits toward screen **bottom-left** and shots aim **top-right** (matches the live range read). Use `IsoGrid.iso_cell_from_range_cell` / `range_cell_from_iso_cell`.

### PixelLab Create tiles (Pro)

| Control | Value | Notes |
|---------|-------|-------|
| Tile type | Isometric | |
| Tile size | **64px** (not 64×128) | Width token; height derived |
| View angle | **~30°** | Isometric (0=side … 90=top-down). Not top-down. |
| Thickness | **0%** | `tile_depth_ratio=0` — no side skirts so tops mesh |
| Top/bottom | 2px classic | `tile_flat_top_px=2` |
| Outline | segmentation / no outline | Cleaner edges |

MCP:

```text
tile_type=isometric
tile_size=64
tile_view_angle=30
tile_depth_ratio=0.0
tile_flat_top_px=2
outline_mode=segmentation
```

Independent tiles often land as **64×64** with a flat **64×32** diamond + transparent pad. Tileset jobs often emit native **64×32**. `tools/build_iso_tileset.gd` normalizes the pad when packing. Do **not** crop skirts — thickness 0% removes them at source.

Fairway palette: light `#6db505`, dark `#3f9d02` from `DayNightPalette._day()`. Iso terrain PNGs are authored to those means. Hitting mats reuse the same grass texture crushed very dark (`fairway_mat_N.png`, ~0.58 toward black from dark).

Seams: PixelLab often paints a darker diamond rim. Flatten that 1px perimeter to interior green before packing so abutting tiles do not read as a grid. Prompts: no edge bevel / seamless. Prefer `outline_mode=segmentation` + `tile_depth_ratio=0`.

Style match: form a 64×32 diamond template from live GRASS+ atlas cell `(0,0)` at `assets/sprites/iso/_proof/fairway_style_template.png`. Try `create_tiles_pro` with `style_images` first; also run shape-mode isometric 64 / view_angle 30 / depth 0. Keep the QA set with lower rim delta and no side skirts (style mode can ignore flat geometry).

## Fairway stripes + day/night

- Author **several** plain fairway light variants (`fairway_light_0.png`…) — no mower stripes in the prompt
- Build matching `fairway_dark_N.png` from light using palette dark/light channel ratios (`#3f9d02` / `#6db505`)
- Build `fairway_mat_N.png` from the same light art, recolored to a really-dark mat green (bay cells only)
- Keep `fairway_light.png` / `fairway_dark.png` / `fairway_mat.png` as aliases of variant 0
- Atlas pack: light `[0..N)`, dark `[N..2N)`, mat `[2N..3N)`
- Paint: stripe by **RangeGrid column** (even light band, odd dark band) **and** scatter variant atlas by `hash(col,row)` so neighbors are not identical wallpaper; overwrite `PLAYER_CELL` / `RATINA_CELL` with mat atlas
- `IsoView.apply_atmosphere(cycle_time)` washes layers with moonlight modulate
- `DayNightCycle` advances while RangeView **or** IsoView is visible

## Assets

| Path | Contents |
|------|----------|
| `assets/sprites/iso/_proof/` | QA staging + `fairway_style_template.png` |
| `assets/sprites/iso/terrain/` | Fairway variants `fairway_{light,dark}_{0..N}.png` |
| `assets/sprites/iso/transitions/...` | Corner tilesets (forest, gravel, path) |
| `assets/sprites/iso/props/` | Props (`pine_tree`) |

TileSet: `assets/tilesets/range_iso.tres` — rebuilt by:

```bash
godot --headless --script res://tools/build_iso_tileset.gd
```

## Bays

- No forest / pine border — Terrain paints the fairway grid only
- Bay cells `PLAYER_CELL` `(9,5)` / `RATINA_CELL` `(8,5)` stay reserved and paint **dark mat** fairway tiles (same grass, crushed value) — not separate prop sprites

## Camera

- Start: depth-flipped iso cell for `RangeGrid.PLAYER_CELL` (player bay)
- Zoom steps: `0.5, 1, 2, 3, 4` (default `1`)
- Pan: left-drag after threshold, plus **WASD** / arrow keys (screen-space, zoom-compensated)
- Session memory: last pan/zoom is kept when toggling build ↔ harvest ↔ off (resets only on restart)

## Entry (Build mode)

- HUD **Build** / keyboard **I** (disabled during harvest)
- Pan: left-drag or WASD/arrows; zoom: scroll; place on LMB release
- Digits **1–9** select catalog; **0** clears tool

## Harvest pickup (IsoView)

Player harvest hard-cuts to IsoView (`Main.set_harvest_view`):

- Litter sync via `EventBus.litter_spawned` / `litter_removed` / `litter_cleared` from `RangeView.leave_litter_ball`
- `LitteredBalls` Sprite2Ds positioned with `IsoGrid.iso_px_from_yards`
- Ground-projected fine-dashed picker ellipse + `IsoPickupController` (same yards radius / GameState collect APIs)
- Litter Sprite2D scale from `BayCell`/`RangeView` `BALL_PIXEL_SIZE` (0.021 yd/px) projected through `IsoGrid`
- Cash float + fly-to-bucket on `HarvestFx` CanvasLayer
- 3D `PickupController` stays idle while iso harvest is ready

## Catalog

`scripts/iso/iso_catalog.gd` — footprints in **RangeGrid / TileMap cells** (1:1).

## Verify

```bash
godot --headless --script res://tools/verify_iso_view.gd
```

## Still deferred

- Cross-fade 3D ↔ 2D dissolve
- Rattling / Ratina agents rendered on the iso map
