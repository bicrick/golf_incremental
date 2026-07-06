# v2 Pickup Mini-Game (v2.0 MVP)

## Trigger

- `bucket_count == 0` after a resolved swing
- Strike input (Space) disabled
- UI: **"Bucket empty — collect your balls"**

## Visual (down-the-line)

Litter sprites cluster **up-screen** along fairway stripes (see screenshot reference in design discussions). Multiple balls overlap — **expected**.

```
     · · ·     ← click targets (inflated hitbox)
    · · ·
   🐀    [Bucket 0/6]
```

## Interaction (v2.0 — ship this first)

1. Each litter sprite is **clickable** (Area2D or manual hit test with generous radius)
2. If multiple under cursor: collect **topmost** (highest z) or nearest to click
3. On collect:
   - Ball tweens in arc toward **bucket UI** (bottom corner)
   - Plink SFX, bucket counter ++, combo timer refresh
4. When `collected == capacity`:
   - Bucket full chime
   - Summary: balls collected, best combo, pickup $
   - Clear remaining litter nodes
   - Return to **strike phase**, bucket refilled

## Vanish horizon (auto-collect)

Shots that land beyond **220 yards** do not spawn litter — they show a star twinkle at the landing spot instead. These balls are **auto-collected**:

- Payout uses the same pickup formula (quality + yardage at vanish time)
- Floating `+$` text appears at the star location
- Ball icon flies to the bucket UI; bucket counter increments
- Mid-bucket vanishes credit **`pending_vanish_collects`** during strike; applied when harvest begins
- Last-ball vanishes credit **`harvest_collected`** directly (may complete harvest if bucket fills)

Combo tier for vanish auto-collect is always **1** (no combo chain).

## Combo

| Rule | Value |
|------|-------|
| Combo window | 0.8s + Quick Hands upgrades |
| Mult | Off until **Combo Bonus** purchased |
| Display | Golden number near bucket |

## Economy (starter tune)

| Source | Example $ |
|--------|-----------|
| Per ball (start) | $0.25 flat |
| + Distance Pay @ 30yd | $0.25 + distance bonus |
| Bucket complete | $0 (no default bonus) |
| Combo | Gated behind Pickup branch |

Adjust so first upgrade affordable after **2–4 full cycles**.

## UI elements

- Bucket icon with fill `n/capacity`
- Combo counter
- Phase label: `STRIKE` / `COLLECT`
- Pixel font via existing `PixelFont`

## NOT in v2.0 MVP

- Gopher steal timer
- Gnome auto-collect
- Rat walk to ball
- Hold-to-sweep magnetic glove
- Separate pickup scene / modal

Add in v2.1 per [07-implementation-phases.md](07-implementation-phases.md).

## Technical hooks (Godot)

| Component | Notes |
|-----------|-------|
| `LitteredBalls` node | Already exists; add metadata `collectible = true` |
| `PlacementDebug` | Unrelated; keep separate |
| `EventBus` | `ball_collected`, `bucket_completed`, `phase_changed` |
| Save | Bucket count resets on load OK for v2.0; optional persist later |

## Click hitbox in perspective

Hit radius matches ~95% of the ball's projected screen size (4px floor for tiny far sprites). Clicks must land on or very near the ball. Multiple fly-to-bucket icons can run concurrently — no input lock between pickups.

## Related docs

- Core loop: [01-core-loop.md](01-core-loop.md)
- Camera cluster: [02-ball-flight-and-camera.md](02-ball-flight-and-camera.md)
