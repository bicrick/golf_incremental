# World and Range

## Visual model: real 3D, pixel-art billboards

The range is a **real `Node3D` scene** — `Camera3D` projection does the vanishing-point/depth work that used to require hand-rolled 2.5D parallax math. Golfer, ball, and litter stay pixel art via `AnimatedSprite3D`/`Sprite3D` billboards (always face the camera), so the look is close to the original 2.5D range, but positions, distances, and landing spots are now real `Vector3` world coordinates instead of faked screen-space perspective.

The player still reads depth naturally because:

- The camera's real perspective projection shrinks and converges distant objects toward the horizon automatically
- Ball flight is real projectile motion (gravity + initial velocity), arcing away from the tee toward `-Z`
- Ground stripes and the forest fence recede into the distance like real geometry, not tuned parallax layers

## Coordinate model

- World unit = 1 yard. Tee sits at world origin `(0, 0, 0)`.
- `-Z` = down the fairway (away from camera). `X` = left/right scatter. `Y` = height/arc.
- Fairway corridor half-width: `Balance.FAIRWAY_HALF_WIDTH_YARDS` (15yd either side of centerline).

## Camera

- **Down-the-line view**: `Camera3D` fixed behind/above the tee, pitched down slightly — same over-the-shoulder composition as the old 2.5D range, but real perspective now does the vanishing-point work for free
- Golfer near the tee at world origin; ball flight recedes down `-Z`
- Camera is fixed for v1 (no orbit/free-look); brief `h_offset`/`v_offset` shake punch on jackpot only

## Scene structure (`scenes/range/range_view.tscn`)

```
RangeView (Node3D)
├── WorldEnvironment      — flat background color + ambient light + fog (day/night driven)
├── Sun (DirectionalLight3D) — angle/color/energy drive day-night mood
├── Camera3D              — fixed, over-shoulder, tilted down
├── Ground (MeshInstance3D) — striped fairway mesh, vertex-colored, rebuilt on palette change
├── ForestFence (Node3D)  — two tall textured quads along the fairway edges
├── Foreground (Node3D)
│   ├── LitteredBalls (Node3D) — Sprite3D children at real landing positions
│   ├── Golfer (AnimatedSprite3D, billboard)
│   └── Ball (AnimatedSprite3D, billboard)
├── ChargeMeter (Node2D)  — screen-space UI overlay, unaffected by the 3D move
├── FxLayer (Node2D)      — screen-space hit-poof / float-cash-text / distance-twinkle overlays
└── JackpotFeedback (CanvasLayer) — already screen-space, unaffected
```

See [../technical/01-architecture.md](../technical/01-architecture.md).

## Ball flight (real projectile motion)

On each swing resolve, `scripts/range/ball_flight_3d.gd` computes a real trajectory from gameplay yards + timing tier + contact flavor:

1. Apex height derived from visual travel distance × a per-flavor ratio (`Balance.FLIGHT_APEX_RATIO`) — pure contact arcs highest, thin/chunk stay low skids/hops.
2. Solve `v_y0 = sqrt(2·g·h)`, `t = 2·v_y0/g`, `v_z0 = distance / t` (tuned arcade gravity in `Balance.FLIGHT_GRAVITY`, not real-world g).
3. `position(t) = origin + velocity0 · t + Vector3(0, -0.5·g·t², 0)` — sampled every frame to drive the `AnimatedSprite3D`'s real `Vector3.position`.
4. Landing point is just `position(flight_time)` — a real `Vector3`, no perspective inversion needed.

Camera3D projection handles scale-down/convergence automatically; no manual scale tween is needed the way the old 2.5D renderer needed one.

## Starting state (v1)

- Fairway ground mesh with alternating light/dark mower-stripe bands receding down `-Z`
- Forest fence along both edges of the fairway corridor
- Single effective target zone (mechanical; bullseye rings in v1.5)
- Crappy balls = short flight cap, high variance

## Progression visuals

| Upgrade / milestone | Visual change |
|---------------------|---------------|
| Extend range | Fairway/fence length can grow down `-Z`; markers placed at real world distances |
| Bigger net | Target zone mesh/billboard scales up at its real world position |
| New bullseyes | Concentric rings placed at real distance tiers down the fairway |
| Time-of-day shift | `DirectionalLight3D` color/energy + background color shift |

**Extend range** unlocks depth — not just bigger numbers.

## Target zones and bullseyes (v1.5+)

Bullseyes provide **zone multipliers** in the payout formula. In 3D these become plain world-space distance bands / `Area3D` checks instead of screen-space perspective bands.

| Zone | Example multiplier | Skill demand |
|------|-------------------|--------------|
| Outer net | 1.0× | Forgiving |
| Middle ring | 2.0× | Good timing + distance |
| Center bullseye | 5.0×+ | Perfect timing + upgrades |

Center bullseye hits are primary **jackpot feedback** triggers.

## Time-of-day cycle

Progression-driven — not real-time clock. Unlocked via range upgrades / milestones. Timing/phase curves are unchanged (`DayNightPalette.sample_at`); only how they're *applied* changed (see Implementation notes below).

| Phase | Mood | Example unlock |
|-------|------|----------------|
| **Soft morning** | Cool greens, light mist | Game start |
| **Bright midday** | Clear sky, crisp shadows | First club upgrade or $ milestone |
| **Golden evening** | Amber light, long shadows | Distance / bullseye milestone |
| **Blue hour** | Cool low light, cozy mood | Late economy branch |

### Implementation notes

- `DayNightPalette` keeps its existing keyframe/timing functions (`sample_at`, `celestial_alpha`, `phase_name_at`) — those are pure data and didn't need to change.
- `RangeView.apply_atmosphere(cycle_time)` now drives: `WorldEnvironment.environment.background_color` (flat sky color), `DirectionalLight3D.light_color`/`light_energy`/`rotation_degrees` (sun angle + warmth), and the ground mesh palette (`FairwayGround3D.apply_palette`) — replacing the old per-layer `Polygon2D`/`CanvasModulate` tint stack and the hand-drawn sun/moon/star/cloud `_draw()` scripts.
- Crossfade still reads smoothly frame-to-frame since the same smoothed `DayNightPalette` curves drive it; triggers `milestone` feedback tier same as before.

## Ambient motion (always on)

- Sun angle/energy drift continuously via `DirectionalLight3D` over the day/night cycle
- Grass stripe palette shifts with time of day
- Range lamp flicker during blue hour (future: a small point light)

Motion stays **subtle** — calm baseline, not distracting from rhythm ring.

## World does NOT change during jackpot spikes

Ground/fence/sky unchanged during jackpot. Frenzy in UI layer, particles, brief `Camera3D.h_offset`/`v_offset` shake — see [07-art-and-atmosphere.md](07-art-and-atmosphere.md).

## v1 scope

- Down-the-line layout with real 3D ground mesh + forest fence geometry
- Ball flight: real projectile motion (gravity + initial velocity)
- Single target zone (implicit); no bullseye rings yet
- Static morning palette

## v1.5 scope

- Bullseye rings with zone multiplier (world-space distance bands)
- Time-of-day unlocks (at least 2 phases)
- Extend range → deeper world-space geometry

## Related docs

- Art direction: [07-art-and-atmosphere.md](07-art-and-atmosphere.md)
- Godot architecture: [../technical/01-architecture.md](../technical/01-architecture.md)
- Range upgrades: [04-upgrade-tree.md](04-upgrade-tree.md) → Branch 5
- Payout zones: [03-economy.md](03-economy.md)
