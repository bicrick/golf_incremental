# v2 Ball Flight and Camera

## Down-the-line constraint (now real 3D)

The range moved from a hand-rolled 2.5D perspective illusion to a **real `Node3D`/`Camera3D` scene** (world unit = 1 yard, tee at origin, `-Z` down the fairway). Camera is fixed **over the golfer's shoulder** toward the horizon, same composition as before — but now it's a real perspective projection, not screen-space math. Ball flight is real projectile motion flying toward `-Z`; side scatter is on `X`, arc on `Y`. Side scatter is still minimal relative to depth; **depth (distance down `-Z`) still dominates** the visual spread.

### What the player sees (reference)

All landed balls still occupy a **similar screen region** once projected by the camera — a cluster along the centerline stripes, deeper shots farther down `-Z` (which the camera renders smaller and higher on screen). This is **correct**, not a bug, and now falls out of real perspective projection instead of a tuned formula.

```
        · · ·  ← litter cluster (depth, -Z)
       · · ·
      · · ·
   🐀———⚪     ← tee / striker (origin)
```

Implications:

- Pickup mini-game clicks project each litter's real `Vector3` world position to screen space via `Camera3D.unproject_position()` — overlapping screen-projections still happen at depth, so pickup uses "collect nearest-to-camera under cursor" (depth-sorted) rather than hit-area inflation tricks.
- Do not expect left/right field coverage for litter gameplay — `Balance.LANDING_SCATTER_YARDS` keeps X-scatter small relative to `-Z` depth.
- Target zones (v2.2+) use **depth bands down `-Z`** and small `X` scatter — not wide fairway width.

## Contact flavor → flight and depth

Contact timing resolves to tier + **flavor** (see [01-core-loop.md](01-core-loop.md#timing-tiers-and-contact-flavor)). Flight renderer reads flavor for arc and `p`, not a second thin/fat skill check.

| Flavor | Arc / motion | Visual `p` (early game) |
|--------|--------------|-------------------------|
| **Pure** (Perfect / Good) | Normal carry arc; Perfect slightly higher | Floor for OK+; extra depth only with carry tier upgrades |
| **Slightly fat** (OK) | Lower, blunter arc; still forward | **Visual carry floor** — same minimum band as pure OK+ |
| **Thin** (Miss early) | Ground skid, low dribble | Near tee; `WHIFF_MAX_P` cap |
| **Chunk** (Miss late) | Fat hop off turf, comedic bounce | Near tee; short hop, low `p` |

OK+ always meets the floor regardless of slightly-fat read. Miss flavors never inherit the OK+ floor.

## Visual carry floor (non-negotiable)

**Gameplay yards** and **visual world-space distance** still decouple early — now expressed directly in world-space yards instead of a screen-space perspective fraction.

| Contact result | Visual landing (early game) | Gameplay yards (example) |
|----------------|----------------------------|---------------------------|
| Thin / chunk (Miss) | Dribble or hop near tee | ~0–5 |
| OK+ (incl. slightly fat) | At least **`VISUAL_FLOOR_YARDS`** world-space carry | 15–30 |
| Pure Perfect / Good | Same floor early; higher arc | capped by stats |
| Pure + carry tier upgrade | Real long carry down `-Z` (late game) | high |

### Implementation (current codebase, `ball_flight_3d.gd`)

- `BallFlight3D.resolve_visual_yards(yards, timing_tier)` replaces the old `Economy.visual_depth_t()` / `BallFlightRenderer.yards_to_p()` screen-space compression — it works directly in world-space yards, no perspective inversion needed.
- Whiff (Miss tier): clamped to `[0, Balance.WHIFF_MAX_YARDS]`.
- Non-whiff: `max(yards, Balance.VISUAL_FLOOR_YARDS)` — the floor is a real world distance now, not a screen Y coordinate.
- `Balance.VISUAL_MAX_YARDS` (300) still normalizes depth fraction for scatter-range scaling, but landing position is a real `Vector3`, not a perspective sample.

Constants in `balance.gd` (implemented):

| Constant | Purpose |
|----------|---------|
| `VISUAL_FLOOR_YARDS` | Minimum world-space carry (yards) for OK+ |
| `WHIFF_MAX_YARDS` | Cap whiff carry (yards) near tee |
| `LANDING_SCATTER_YARDS` | Max lateral (`X`) scatter on landing, yards |

## Scatter on landing

`BallFlight3D.build_path()` applies a real `X`-axis scatter (`Balance.LANDING_SCATTER_YARDS`, scaled by depth fraction) rather than a screen-space horizontal jitter — same "keep it small relative to depth" goal, now literally a `Vector3` offset. Optional future: **stack offset** — new litter sprite nudges along `X` if too close to existing litter in world space (fan pattern).

## Arc and juice

- OK+ (pure or slightly fat): `Balance.FLIGHT_APEX_RATIO` keeps a minimum apex height so flight never reads as "ground skid"
- Pure Perfect: tier color flash, optional camera nudge (existing jackpot shake, now `Camera3D` frustum offset)
- Thin: low apex ratio (skid); chunk: short-hop apex ratio — comedy on miss only
- Carry tier upgrades (pure only): real long carry down `-Z` — late-game comedy goal, no longer needs a "leave the visible band" trick since the world is real 3D space

## Ball flight time

`BallFlight3D` derives flight time from the apex height physics (`t = 2·v_y0/g`), then clamps to `Balance.FLIGHT_TIME_MIN_SEC`/`FLIGHT_TIME_MAX_SEC` for arcade pacing — scales naturally with visual distance since higher apex (farther shots) takes longer.

## Litter sprite

Reuse Dinky `Ball-Lay` or equivalent as a `Sprite3D`, placed at the real landing `Vector3` (`_leave_litter_ball` in `range_view.gd`) — Camera3D projection handles the scale-down, no manual perspective-sample scaling needed.

## Related docs

- Pickup clicking cluster: [06-pickup-minigame.md](06-pickup-minigame.md)
- Economy yards vs visual: [03-economy.md](03-economy.md)
- Migration: [07-implementation-phases.md](07-implementation-phases.md) → Phase B
