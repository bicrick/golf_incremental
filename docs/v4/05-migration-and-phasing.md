# v4 Migration and Phasing

## In-place vs. parallel codebase

**Decision: build in-place, in the same repo, isolated via a git branch or worktree while in flux — not a second Godot project.**

Rationale:

- A large, actively-tuned share of the codebase is **camera/scene-layout-independent** and must survive untouched: `GameState`, `PlayerStats`, `Balance`, `Economy`, the upgrade-tree data (`scripts/game/upgrades/`), save format, `EventBus`, day/night palette, SFX, and `BallFlight3D`'s trajectory math. None of this cares about camera projection.
- What's genuinely being reworked is concentrated in a handful of files: `range_view.gd`'s camera/ground/marker-position responsibilities, `fairway_ground_3d.gd`/`fairway_grass_tiles_3d.gd`, `forest_fence.gd`, `placement_debug.gd`, and `ratina_controller.gd` (generalizing into `HittingBayController`). That's a large orchestration script and a few geometry scripts, not "everything."
- A second codebase would duplicate `project.godot`, every asset, and every autoload script — and since v3's economy balance is still actively being tuned, any tweak made during a parallel build has to be manually ported both ways or the two copies of `Balance`/`PlayerStats` diverge and become expensive to reconcile at merge time.
- A branch or worktree gives the same practical isolation (freedom to experiment, clean diffs, easy abandonment of dead ends) without asset/autoload duplication, and matches how this repo already handles big structural shifts — `docs/v2/07-implementation-phases.md` is the same pattern (2.5D → real-3D perspective) done once already, in-place, in phases.

## Migration principle: additive before subtractive

Land new camera/grid/ground/bay code **alongside** the existing fixed-diorama code first; delete the old camera/ground/marker-based code only after the new path is verified in the editor and in play. Do not attempt a big-bang swap in one phase.

## Phases

Build in order. Each phase should be playable/verifiable before starting the next, per the project's standing Godot-verify workflow (headless smoke + relevant `tools/verify_*.gd` scripts after every phase).

### Phase A — Design only (this doc set)

- [x] v4 docs in `docs/v4/`
- [x] Bay cell prefabs `player_bay_cell.tscn` + `ratina_bay_cell.tscn`
- [ ] Confirm remaining open questions in [00-vision.md](00-vision.md#design-decisions-resolved--in-progress) before Phase F (economy numbers)

### Phase B — Orthographic camera swap

**Goal:** Camera reads as orthographic/dimetric; reference rig for tuning.

| Task | Files | Status |
|------|-------|--------|
| Bay cell prefabs (camera in `EditorOnly`, ship floor + sprites) | `player_bay_cell.tscn`, `ratina_bay_cell.tscn`, `bay_cell.gd` | done |
| `Camera3D.projection = PROJECTION_ORTHOGONAL`, locked rotation via `V4CameraConfig` | `v4_camera_config.gd`, `player_bay_cell.tscn`, `range_view.tscn` | done |
| Tune cell camera position/size in editor (rotation fixed) | `player_bay_cell.tscn` `EditorOnly/Camera3D` | done |
| Verify `unproject_position()` screen FX under ortho | `range_view.gd`, `pickup_controller.gd` | manual playtest pending |
| Port player sprite layout from atomic cell | `player_bay_cell.tscn`, `range_view.gd` | done |
| Tune range camera position/size for full grid | `range_view.tscn` | tune in editor |

**Exit:** Headless smoke passes; camera baseline locked in reference rig; sprites aligned in rig and ported to live scene; old perspective transform recoverable from git history.

### Phase C — Surrounding ground + fence rework

**Goal:** World doesn't look like it ends at the fairway edge; fences bound the full grid.

| Task | Files | Status |
|------|-------|--------|
| Extend fairway ground to 50×300 yd | `fairway_grass_tiles_3d.gd`, `range_view.gd`, `range_grid.gd` | done |
| Add `ForestFence` node, populate at full grid size | `range_view.tscn`, `range_view.gd` | done |
| Rework fence quads for dimetric angle (visual) | `forest_fence.gd` | open |

**Exit:** Full grass grid visible; fences run full depth. Dimetric fence art polish remains optional.

### Phase D — Buildable strip + grid system

**Goal:** Grid helpers and runtime bay placement exist; placement UI still deferred.

| Task | Files | Status |
|------|-------|--------|
| Shared `cell_ground.gd` + ship-ready bay prefabs (`player_bay_cell`, `ratina_bay_cell`) | `scripts/range/cell_ground.gd`, `scenes/range/cells/` | done |
| Player bay via `player_bay_cell.tscn` at `player_bay_origin()` | `player_bay_cell.tscn`, `range_view.gd` | done |
| Crew bay (Ratina) via `ratina_bay_cell.tscn` at `ratina_bay_origin()` | `ratina_bay_cell.tscn`, `range_view.gd`, `ratina_controller.gd` | done |
| Placement UI / purchase flow | Phase F | deferred |

### Phase E — Generalize `RatinaController` → `HittingBayController`

**Goal:** Ratina's existing behavior is reproduced through a reusable controller, proving the abstraction before adding new bays.

| Task | Files |
|------|-------|
| Parameterize home markers, sprite node paths, unlock/upgrade identifiers | `ratina_controller.gd` → generalized controller |
| Player's flight/litter/payout pipeline shares code with the generalized controller's pipeline (input handling stays bespoke) | `range_view.gd`, new/renamed controller |
| Verify Ratina behaves identically post-extraction | manual playtest + existing verify scripts |

**Exit:** Ratina still works exactly as before, now running through the generalized controller with zero visible behavior change.

### Phase F — Placement UX + economy hookup

**Goal:** Player can click an empty strip cell, see a context menu, pay, and place a new crew bay.

| Task | Files |
|------|-------|
| Click/context-menu placement flow | new small controller (e.g. `placement_controller.gd`) + new UI scene |
| Generalize `ratina_unlocked: bool` → `hired_bays` collection, with save migration | `game_state.gd`, `save_manager.gd` |
| Slot-unlock cost values authored per [04-economy-and-progression.md](04-economy-and-progression.md) methodology | `balance.gd`, `scripts/game/upgrades/definitions.gd` |

**Exit:** Player can hire and place a second crew bay (beyond Ratina) end-to-end, with persisted state across save/load.

### Phase G — Multi-bay lanes and scatter

**Goal:** 3+ simultaneous bays feel like a real (small) driving range, not visual noise.

| Task | Files |
|------|-------|
| Per-bay lane offset derived from grid cell position | generalized bay controller, `ball_flight_3d.gd` call sites |
| Verify existing lateral scatter can visibly cross into a neighbor's lane without breaking pickup | `ball_flight_3d.gd`, pickup/litter code (should need no changes — verify only) |
| Playtest calm-vs-noise balance with full slot count occupied | manual, informs [00-vision.md](00-vision.md) pillar check |

**Exit:** Full buildable strip occupied plays as calm ambience, matching [07-art-and-atmosphere.md](../design/07-art-and-atmosphere.md)'s calm-default pillar.

### Phase H — Sunset old fixed-diorama code

**Goal:** Remove now-dead code paths once the grid-based system is the only path.

| Task | Files |
|------|-------|
| Remove hardcoded `Marker3D`-based Ratina layout path once fully replaced by grid placement | `range_view.gd::_apply_ratina_unlocked_layout()` and related markers |
| Remove any temporary compatibility shims from Phase E/F | wherever introduced |

**Exit:** No remaining code path assumes a single hardcoded crew bay.

## Migration notes from v2/v3

| v2/v3 system | v4 action |
|---|---|
| Perspective `Camera3D` | Replaced in Phase B; do not keep both projections at runtime |
| `FairwayGround3D`/`FairwayGrassTiles3D` | Kept — fairway itself is unchanged; new ground is additive, not a replacement |
| `ForestFence` | Reworked in Phase C for the new angle |
| `ratina_controller.gd` | Generalized in Phase E, not deleted — Ratina is the proof case, not a special exception |
| `ratina_unlocked: bool` | Generalized to a collection in Phase F, with save-file migration |
| v2/v3 economy curves (`Balance`, upgrade `definitions.gd`) | Unchanged; extended with slot-unlock costs only in Phase F |
| `placement_debug.gd` | Reference/study for Phase D-F tooling; not necessarily reused as-is |

## Related docs

- Acceptance criteria: to be written per-phase once Phase A is confirmed (mirror `docs/v2/specs/v2-acceptance.md` pattern)
- Agent workstreams: update `../technical/03-agent-workstreams.md` when Phase B starts, if multiple agents work v4 in parallel
- Full doc set: [README.md](README.md)
