# v2 Core Loop

## Overview

Every session alternates **strike** and **harvest** phases inside a longer **build** loop.

```mermaid
flowchart LR
  subgraph strike [Strike phase]
    B[Bucket has balls] --> Swing[Contact swing]
    Swing --> Litter[Litter on fairway]
    Litter --> B
  end
  B -->|empty| harvest[Harvest phase]
  harvest --> Refill[Bucket refilled]
  Refill --> Spend[Upgrades / range]
  Spend --> strike
```

## Phases

### 1. Strike phase (bucket has balls)

| Rule | Value |
|------|-------|
| Bucket size (early) | **6** balls (tune in `balance.gd`) |
| Input | **Space** — contact timing (see below) |
| Per-swing cooldown | Short (~1s) **inside** bucket — keeps burst snappy |
| Ball consumed | 1 per resolved swing |
| Litter | Each landing adds sprite to fairway cluster |

When bucket hits **0**, strike input disabled → harvest phase.

### 2. Harvest phase (pickup mini-game)

See [06-pickup-minigame.md](06-pickup-minigame.md).

Summary: click litter on fairway → tween into bucket UI → combo bonus → bucket full → return to strike.

**v2.0 MVP:** click pickup only. No gophers, no gnome.

### 3. Spend phase (implicit)

After harvest payout, player opens upgrade tree or buys range tile upgrades (when implemented). No hard gate — natural pause between buckets.

## Swing: contact timing (replaces hold-to-charge)

| v1 | v2 |
|----|-----|
| Hold Space ~0.5s, release at peak | Press/hold through wind-up; **release at contact window** aligned to rat swing frame 9 |
| Power bar + shrinking rings primary | Contact flash / small sweet band; rings optional or simplified |
| `charge_progress` → wind-up frames 0–7 | Same anim mapping; quality from **release vs contact**, not hold duration |
| Overshoot decay → OK/Miss tiers | Single **timing axis** (early / pure / late) → tier + flavor |

**Contact timing is the v2 swing system.** There is no second skill check (no separate thin/fat grid, no chunk subsystem). One release-vs-contact axis drives tier, payout, and visual flavor.

### Contact timing axis

Player aim: release during the **pure** band at frame 9.

| Timing | Player read | Resolves to |
|--------|-------------|-------------|
| **Early** | Released before contact | Miss → **thin** flavor |
| **Pure** | Release in sweet band | Perfect / Good |
| **Late** | Released after contact | Miss → **chunk** flavor; OK tier can read **slightly fat** |

Early and late are the same axis as pure — not a parallel mechanic.

### Timing tiers and contact flavor

Tier labels are **Perfect / Great / Good / Okay / Bad / Miss** for HUD and payout — a six-rung ladder so distance and payout visibly separate between a weak real hit and a clean one. **Perfect is intentionally rare** (tight ms window by default); the Rhythm branch's Metronome upgrade widens it over time. **Flavor** names describe what the player *sees* on the fairway.

| Tier | Timing | Contact flavor | Feel | Payout mult |
|------|--------|----------------|------|-------------|
| Perfect | Pure (very tight window, rare) | **Pure** | Clean strike, satisfying arc | 1.0× |
| Great | Pure (wider window) | **Pure** | Crisp contact, high arc | ~0.8× |
| Good | Pure (wider still) | **Pure** | Solid contact, normal arc | ~0.6× |
| Okay | Pure edge or slightly late, still contacted | **Slightly fat** | Chunky but forward | ~0.4× |
| Bad | Weak real contact, near the edge of the timing window | **Slightly fat** | Barely got there, short and low | ~0.2× |
| Miss (early) | Too early | **Thin** | Skid, low dribble near tee | ~0.1× pity |
| Miss (late) | Too late | **Chunk** | Fat hop off turf, comedic short hop | ~0.1× pity |

**Fortune Mill chill rule retained:** Miss never zero.

**Do not implement:** a full early/late × thin/fat grid, or chunk/fat as a separate subsystem. Flavor follows tier + timing side (early vs late miss only).

### Depth rule (carry is always real)

Visual flight distance is **always exactly the gameplay yards** for every tier — no artificial floor or cap. A weak Bad/Okay hit visibly travels less than a Great or Perfect hit, and a whiff dribbles near the tee. This makes the ball's flight an honest readout of contact quality instead of a fixed "look" that's the same across most tiers.

**Perfect does not go stupid deep early.** Long carry unlocks through distance/power upgrades (`base_yards`, `max_yards`), not from Perfect timing alone at game start.

### Sweet spot upgrades (progression)

Upgrades widen the **pure** contact band (Perfect/Good windows) and unlock higher **carry tiers** on pure contact — not raw `base_yards` inflation early. See [04-upgrade-tree.md](04-upgrade-tree.md).

## Session rhythm (target feel)

| Time | Player state |
|------|----------------|
| 0–2 min | Learn contact; 6-ball buckets; pickup clicky |
| 2–8 min | First upgrades: bucket +1, sweet spot, pickup bonus |
| 8–20 min | Range visual tier 1 (patch crack); income mix shifts |
| 20+ min | Gnome/gopher (v2.1+), targets (v2.2+), ridiculous carry (late sweet spot) |

Early income is **intentionally slow per hit**; pickup bonus and bucket complete matter.

## Camera

Fixed **down-the-line** — golfer lower-left, ball toward horizon. Litter clusters **up-screen** along stripe centerline. Pickup clicks target overlapping sprites (generous hit areas). See [02-ball-flight-and-camera.md](02-ball-flight-and-camera.md).

## Events (Godot)

Extend `EventBus` when implementing:

| Signal | When |
|--------|------|
| `bucket_changed(count, capacity)` | Ball added/removed from bucket |
| `phase_changed(strike \| harvest)` | Mode switch |
| `ball_collected(world_pos, combo)` | Pickup mini-game |
| `bucket_completed(bonus)` | Harvest done |
| `swing_resolved` | Keep; add contact tier + visual yards |

## v1 checklist superseded

- ~~Hold begins charge and power curve~~ → contact release at frame 9
- ~~Infinite tee reload~~ → bucket + pickup refill
- Add: bucket empty triggers harvest
- ~~Visual carry floor on OK+ contacts~~ → removed; flight is always proportional to actual yards

## Related docs

- Pickup: [06-pickup-minigame.md](06-pickup-minigame.md)
- Flight: [02-ball-flight-and-camera.md](02-ball-flight-and-camera.md)
- Economy: [03-economy.md](03-economy.md)
