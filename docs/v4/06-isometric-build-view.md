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

### Editor preview

`IsoView` is `@tool` (same idea as `RangeView`): open `scenes/iso/iso_view.tscn` in the **2D** workspace (not 3D). The fairway paints automatically. **Pixel origin is the player address pose** (`IsoGrid.view_origin_yards()` → `(0,0)`), so the editor opens on the rat. `Camera2D` + `EditorFocus` sit at the origin. Inspector checkbox **Editor Repaint Preview** forces a repaint. Painted cells are cleared on save so the `.tscn` stays small.

**Actor tuning:** `ActorLayer/PlayerGolferPlaceholder` (`idle_out_of_balls`) and `PlayerBallPlaceholder` (lay ball) are editable — move/scale them to set the live iso mirror pose. At runtime the player mirrors sit exactly on those authored pixels while idle (3D strike-home as rest), then track iso motion from there. Placeholders are hidden in-game; **ball placeholder scale** drives tee ball, in-flight balls, and litter.

```
IsoView (Node2D)
  Camera2D + IsoCameraController   # zoom steps 0.5/1/2/3/4, drag + WASD pan, ball follow
  Terrain (TileMapLayer)           # fairway only (range_iso.tres)
  Paths   (TileMapLayer)
  Objects (Node2D, y_sort)         # buildings / props + actor mirrors
  LitteredBalls / Flights / Trails # harvest litter + in-flight balls + tracers
  Overlay                          # placement ghost
  ActorLayer / FlightLayer         # 3D→iso mirrors
  PlacementController
```

## Grid / texture contract

- Logical range: still `RangeGrid` **19×200** @ 2 yd
- Iso paint grid: `SUBCELLS = 1` → TileMap **19×200** (**1:1** with RangeGrid)
- Godot cell: `tile_size = Vector2i(64, 32)` (2:1). One RangeGrid cell = one TileMap cell
- Art authored at **64px** wide and displayed 1:1
- **Depth flip:** RangeGrid row increases downrange; iso Y decreases so the tee sits toward screen **bottom-left** and shots aim **top-right** (matches the live range read). Use `IsoGrid.iso_cell_from_range_cell` / `range_cell_from_iso_cell`.
- **View origin:** `iso_px_from_*` is shifted so the player address pose is `(0,0)`. Terrain/Paths use `position = -view_origin_px_raw()` so tiles stay aligned.

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

Iso fairway PNGs are authored to perspective-sampled hitting-view greens: light `#267408`, dark `#1e5c06` (iso-only — 3D `DayNightPalette` fairway stays `#6db505` / `#3f9d02`). Hitting mats use a single authored tile `fairway_mat.png` (edit that file for borders / color).

Seams: PixelLab often paints a darker diamond rim. Flatten that 1px perimeter to interior green before packing so abutting tiles do not read as a grid. Prompts: no edge bevel / seamless. Prefer `outline_mode=segmentation` + `tile_depth_ratio=0`. `tools/recolor_iso_fairway.py` also unifies light/dark diamond silhouettes so mixed variants do not leave 1px sky gaps.

## Fairway stripes + day/night

- Author plain fairway light variants (`fairway_light_0.png`…) — no mower stripes in the prompt
- Build matching `fairway_dark_N.png` from light using palette means (`#1e5c06` / `#267408`)
- Author bay mats as `fairway_mat.png` only — recolor tool does not overwrite mats
- Batch recolor helper: `python3 tools/recolor_iso_fairway.py` then `godot --headless --script res://tools/build_iso_tileset.gd`
- Atlas pack: light `[0..N)`, dark `[N..2N)`, mat `[2N]` (`fairway_mat.png`)
- Paint: stripe by **RangeGrid column** (even light band, odd dark band) **and** scatter light/dark variant atlas by `hash(col,row)`; overwrite player/Ratina **and all empty player-row bay cells** with `FAIRWAY_ATLAS_MAT`
- `IsoView.apply_atmosphere(cycle_time)` washes terrain/paths at `ISO_TERRAIN_TOD_WASH` (0.55) so night still reads after brighter authored means; props/litter get moonlight; actor/flight mirrors stay untinted parents and copy 3D `modulate` 1:1
- `DayNightCycle` advances while RangeView **or** IsoView is visible

## Assets

| Path | Contents |
|------|----------|
| `assets/sprites/iso/terrain/` | `fairway_light_N` / `fairway_dark_N` variants + `fairway_mat.png` |
| `assets/sprites/iso/props/` | Props (`pine_tree`) |

TileSet: `assets/tilesets/range_iso.tres` — rebuilt by:

```bash
godot --headless --script res://tools/build_iso_tileset.gd
```

## Bays

- No forest / pine border — Terrain paints the fairway grid only
- Bay cells `PLAYER_CELL` `(9,5)` / `RATINA_CELL` `(8,5)` stay reserved; those plus every empty bay on the player row paint **`fairway_mat`** — not separate prop sprites

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
- Ground-projected fine-dashed picker ellipse (1 screen-px hairline, stretch-compensated) + `IsoPickupController` (same yards radius / GameState collect APIs)
- Litter Sprite2D scale from `BayCell`/`RangeView` `BALL_PIXEL_SIZE` (0.021 yd/px) projected through `IsoGrid`
- Cash float + fly-to-bucket on `HarvestFx` CanvasLayer
- 3D `PickupController` stays idle while iso harvest is ready

## Actors + ball flight (parity mirror)

IsoView mirrors the authoritative 3D range actors/flights — it does not re-simulate physics.

| Piece | Role |
|-------|------|
| `IsoActorLayer` | Mirrors player Range Rat + tee ball, Ratina + her ball onto bay cells |
| `IsoActorMirror` | Per-frame copy of `AnimatedSprite3D` → iso px (`IsoGrid.iso_px_from_yards`) |
| `IsoFlightLayer` | Mirrors group `range_flight_ball` + `IsoBallTrail` tracers |
| `IsoCameraController.follow_world_px` | Soft follow while airborne (user pan/zoom cancels) |

- Golfers draw at **2/3 native scale** (`ACTOR_PIXEL_SCALE = 2/3`) with a half-cell downrange ground bias so feet sit on the mat center (tee `bay_origin` is the near edge)
- In-flight / litter balls reuse `IsoView.litter_sprite_scale()` and stay exact yards→iso (no ground bias)
- Iso balls stay on static lay/`idle` art (not 3D `roll`) so screen size stays constant through flight and bounce
- Bounce, rest, and litter still come from `BallFlight3D` + `RangeView` / `RatinaController`
- Strike Space charge/release still routes through `RangeView` while IsoView is showing
- `RangeView/FxLayer` is hidden when RangeView is hidden so 3D trails do not smear over iso

## Catalog

`scripts/iso/iso_catalog.gd` — footprints in **RangeGrid / TileMap cells** (1:1).

## Verify

```bash
godot --headless --script res://tools/verify_iso_view.gd
```

## Still deferred

- Cross-fade 3D ↔ 2D dissolve
- Rattling collectors rendered on the iso map
- Iso HitPoof / charge-meter chrome (3D `ChargeMeter` is hidden with RangeView)
