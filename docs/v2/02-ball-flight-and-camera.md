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

Contact timing resolves to tier + **flavor** (see [01-core-loop.md](01-core-loop.md#timing-tiers-and-contact-flavor)). Flight renderer reads flavor (and, at the top of the ladder, tier) for arc, not a second thin/fat skill check.

| Flavor | Arc / motion |
|--------|--------------|
| **Pure** (Perfect / Great / Good) | Normal carry arc; Perfect/Great arc a little higher than Good |
| **Slightly fat** (Okay / Bad) | Lower, blunter arc; still forward |
| **Thin** (Miss early) | Ground skid, low dribble |
| **Chunk** (Miss late) | Fat hop off turf, comedic bounce |

Visual distance always tracks the tier's actual computed yards — see below.

## Proportional flight (no visual floor)

**Visual world-space distance always equals gameplay yards exactly**, for every tier including Miss. There is no floor or cap decoupling the two — a Bad hit visibly travels less than a Good hit, which travels less than a Great or Perfect hit, and a whiff genuinely dribbles near the tee.

| Contact result | Visual landing | Gameplay yards (example, early game) |
|----------------|----------------|---------------------------------------|
| Miss (thin/chunk) | Near tee, proportional to its (very low) yards | ~1–3 |
| Bad | Short, visibly farther than a whiff | ~2–6 |
| Okay | Modest carry | ~6–17 |
| Good | Solid carry | ~17–26 |
| Great | Strong carry | ~26–29 |
| Perfect | Best carry at current stats | ~29–30 |

Long carry beyond these bands comes from distance/power upgrades (`base_yards`, `max_yards`), not from an artificial floor.

### Implementation (current codebase, `ball_flight_3d.gd`)

- `BallFlight3D.resolve_visual_yards(yards, timing_tier)` returns `yards` unmodified (clamped only to non-negative) — replaces the old `Economy.visual_depth_t()` / `BallFlightRenderer.yards_to_p()` screen-space compression and the later world-space floor/cap.
- `BallFlight3D.apex_ratio_for(contact_flavor, timing_tier)` applies the flavor's base apex ratio (`Balance.FLIGHT_APEX_RATIO`) plus a small multiplier for Perfect/Great so the cleanest pure-flavor hits arc a bit higher than a plain Good.
- `Balance.VISUAL_MAX_YARDS` (300) still normalizes depth fraction for scatter-range scaling, but landing position is a real `Vector3` computed directly from yards, not a perspective sample.

Constants in `balance.gd` (implemented):

| Constant | Purpose |
|----------|---------|
| `LANDING_SCATTER_YARDS` | Max lateral (`X`) scatter on landing, yards |
| `FLIGHT_MIN_APEX_YARDS` | Minimum apex so even a tiny whiff arcs slightly above ground |

## Scatter on landing

`BallFlight3D.build_path()` applies a real `X`-axis scatter (`Balance.LANDING_SCATTER_YARDS`, scaled by depth fraction) rather than a screen-space horizontal jitter — same "keep it small relative to depth" goal, now literally a `Vector3` offset. Optional future: **stack offset** — new litter sprite nudges along `X` if too close to existing litter in world space (fan pattern).

## Arc and juice

- Okay and above (pure or slightly fat): `Balance.FLIGHT_APEX_RATIO` plus `Balance.FLIGHT_MIN_APEX_YARDS` keep a minimum apex height so flight never reads as "ground skid"
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
