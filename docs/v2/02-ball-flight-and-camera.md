# v2 Ball Flight and Camera

## Down-the-line constraint

Camera is fixed **over the rat's shoulder** toward the horizon. Ball flight moves **up-screen** with perspective scale-down. Side scatter is minimal; **depth scatter** dominates.

### What the player sees (reference)

All landed balls occupy a **similar screen region** — a cluster along the centerline stripes, deeper shots slightly farther up-screen and smaller. This is **correct**, not a bug.

```
        · · ·  ← litter cluster (depth)
       · · ·
      · · ·
   🐀———⚪     ← tee / striker
```

Implications:

- Pickup mini-game clicks **overlapping** balls — use hit-area inflation by depth or "collect topmost under cursor."
- Do not expect left/right field coverage for litter gameplay.
- Target zones (v2.2+) use **depth bands** and small horizontal scatter — not wide fairway width.

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

**Gameplay yards** and **screen depth** decouple early.

| Contact result | Visual landing (early game) | Gameplay yards (example) |
|----------------|----------------------------|---------------------------|
| Thin / chunk (Miss) | Dribble or hop near tee | ~0–5 |
| OK+ (incl. slightly fat) | At least **first depth band** (~50yd marker visually) | 15–30 |
| Pure Perfect / Good | Same floor early; higher arc | capped by stats |
| Pure + carry tier upgrade | Absurd depth (late game) | high |

### Implementation notes (current codebase)

- `Economy.visual_depth_t()` and `BallFlightRenderer.yards_to_p()` apply heavy compression — **retune for v2** so OK+ hits meet a `VISUAL_MIN_LANDING_Y` or minimum `persp_p`.
- `Balance.VISUAL_MAX_YARDS` (300) stays the far horizon reference; early shots should **not** use raw low yards for depth.
- Suggested: `visual_landing_y = max(visual_landing_y, VISUAL_FLOOR_Y)` for non-whiff tiers.

Constants to add/tune in `balance.gd` (when implementing):

| Constant | Purpose |
|----------|---------|
| `VISUAL_FLOOR_Y` | Minimum landing Y for OK+ (screen space) |
| `VISUAL_FLOOR_P` | Minimum perspective `p` for OK+ |
| `WHIFF_MAX_P` | Cap whiff depth near tee |

## Scatter on landing

Keep small horizontal jitter (`landing_scatter_x`) but **reduce** relative to depth so cluster stays readable. Optional: **stack offset** — new litter sprite nudges +2px if within 8px of existing (fan pattern).

## Arc and juice

- OK+ (pure or slightly fat): minimum arc height so flight never reads as "ground skid"
- Pure Perfect: tier color flash, optional camera nudge (existing jackpot shake)
- Thin: skid particles / low trajectory; chunk: exaggerated hop squash — comedy on miss only
- Carry tier upgrades (pure only): ball may leave visible band briefly — late-game comedy goal

## Ball flight time

Keep flight tween; duration can scale mildly with visual depth, not raw early yards.

## Litter sprite

Reuse Dinky `Ball-Lay` or equivalent; scale from landing perspective sample (already in `_leave_litter_ball`).

## Related docs

- Pickup clicking cluster: [06-pickup-minigame.md](06-pickup-minigame.md)
- Economy yards vs visual: [03-economy.md](03-economy.md)
- Migration: [07-implementation-phases.md](07-implementation-phases.md) → Phase B
