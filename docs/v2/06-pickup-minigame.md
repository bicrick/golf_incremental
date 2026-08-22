# v2 Pickup Mini-Game (v2.0 MVP)

## Trigger

- **Voluntary**, not forced: a left-click on the gameplay background (anywhere that isn't a UI button) enters harvest at any time in strike, with any ball count — including 0.
- Balls still unhit in the bucket are **stashed** (`GameState.harvest_stash`) and merge back in when the player returns to strike.
- Strike input (Space) is disabled while in harvest — clicking Space instead exits harvest (see Exit below).

## Visual (down-the-line)

Litter sprites cluster **up-screen** along fairway stripes (see screenshot reference in design discussions). Multiple balls overlap — **expected**.

```
     · · ·     ← click targets (inflated hitbox)
    · · ·
   🐀    [Bucket 3/6]  ← inventory = stash + collected
```

## Interaction (v2.0 — ship this first)

1. **Range picker cursor** (shag-bag) replaces the hand pointer during harvest
2. A **dashed circle** on the ground under the cursor shows collection radius (~ball-sized at start)
3. **One click = one ball** inside the circle; if multiple overlap, collect the ball **closest to circle center**
4. On collect:
   - Ball tweens in arc toward **bucket UI** (bottom corner)
   - Plink SFX, bucket counter ++, combo timer refresh
5. When `stash + collected == capacity` (bucket fully replenished):
   - Bucket full chime
   - Summary: balls collected, best combo, pickup $
   - Clear remaining litter nodes
   - Return to **strike phase**, bucket refilled to full capacity

## Exit (voluntary or forced)

| Exit | Trigger | Result |
|------|---------|--------|
| **Early** | Hit button (icon bar) or **Space** | Return to strike now; `bucket_remaining = stash + collected` — litter stays on the fairway |
| **Free return** | Click bucket counter while incomplete | Restore a **full** bucket with **$0** for any still-missing balls (litter, vanished, or despawned), clear fairway litter / unresolved flights, return to strike |
| **Full** | Auto, when `stash + collected` reaches bucket capacity | Return to strike; bucket refills to full capacity, remaining litter clears |

No swinging in harvest, ever — Space always exits to strike instead of starting a swing, regardless of how many balls have been collected.

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

- Bucket icon with fill `n/capacity` — during harvest `n = stash + collected` (inventory you keep on exit), not collect-progress alone
- While incomplete in harvest, the bucket card **pulses/bobs** (click affordance); clicking it free-returns **all** missing balls and refills the bucket to capacity
- Combo counter
- **Hit button** (icon bar, bottom-right, next to the bucket counter) — visible only during harvest; returns to strike immediately, same as pressing Space
- Phase label: `STRIKE` / `COLLECT`
- Pixel font via existing `PixelFont`

## NOT in v2.0 MVP

- Gopher steal timer
- Gnome auto-collect
- Rat walk to ball
- Hold-to-sweep vacuum cleaner (future upgrade tier)
- Separate pickup scene / modal

Add in v2.1 per [07-implementation-phases.md](07-implementation-phases.md).

## Technical hooks (Godot)

| Component | Notes |
|-----------|-------|
| `LitteredBalls` node | Already exists; add metadata `collectible = true` |
| `PlacementDebug` | Unrelated; keep separate |
| `EventBus` | `ball_collected`, `bucket_completed`, `phase_changed` |
| Save | Bucket count resets on load OK for v2.0; optional persist later |

## Range picker circle

A **dashed ground ring** follows the mouse on the fairway alongside the range-picker OS cursor. The ring is offset so the cursor tip sits on its bottom rim (not the center). Pickup uses the same ground point as the ring center. Over **fog-of-war** (cursor tip past the reveal line — 1 yd past furthest rest) or **off the grass**, the ring swaps to a tiny projected **X** at the tip.

## Harvest fog of war

While harvest view is ready (ortho pickup), the fairway past the player's **lifetime max carry** is veiled in a soft mist bank:

| Rule | Value |
|------|-------|
| Reveal line | `max(18 yd, max_carry + 1 yd)` |
| Tracked as | `GameState.lifetime.max_carry_yards` (player + Ratina shots) |
| Look | Pearl/sage mist bank on the grass shader — not Godot volumetric fog |
| Strike phase | Fully clear (no fog) |
| Enter | Fog is already fully on when harvest appears (no green→mist fade-in) |
| Max label | Quiet right-edge `N yd` (thin outline, low alpha); harvest-only; moves with new bests |
| Markers | Yard signs fade through the bank instead of hard-hiding |
| Birds | Ambient birds past the reveal line get the same cool mist modulate |

Future loot / partners past the fog stay out of scope for now — the mist is the exploration teaser.

## Related docs

- Core loop: [01-core-loop.md](01-core-loop.md)
- Camera cluster: [02-ball-flight-and-camera.md](02-ball-flight-and-camera.md)
- Atmosphere: [../design/07-art-and-atmosphere.md](../design/07-art-and-atmosphere.md)
