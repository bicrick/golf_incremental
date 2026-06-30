# Core Loop

## Overview

Every session is a tight loop: **prepare → hold to charge → release at peak → ball flies → earn money → buy upgrades → repeat.**

```mermaid
flowchart LR
  Idle[Ring dim / static] --> Hold[Press and hold]
  Hold --> Charge[Power rises to peak]
  Charge --> Release[Release near peak]
  Release --> Tier[Timing tier resolved]
  Tier --> Flight[Ball flight + yards]
  Flight --> Payout[Money awarded]
  Payout --> Upgrades[Spend on tree]
  Upgrades --> Idle
```

## Setting

- **Driving range**, down-the-line camera (golfer facing away from player, ball toward distant targets)
- Player starts with **crappy range balls** and a **close net**
- Progression extends flight distance and unlocks farther targets

## Input: one-hand hold-release swing

| Rule | Value |
|------|-------|
| Input per swing | **One gesture** — press/hold, then release (mouse left or spacebar) |
| Press/hold | Instant wind-up; outer ring shrinks toward inner sweet spot over ~0.5s |
| Release | Release when outer aligns with inner (±perfect window); holding past peak decays tier to OK then Miss |
| Idle | Ring dim/static; no charge until next hold |
| Charge indicator (v1) | **Side charge meter** (left, x≈60) — concentric rings with fixed gold inner sweet spot; outer ring shrinks inward to overlap at peak (~0.5s); green/gold pulse + "SWEET SPOT" in release band; vertical power bar with peak tick; red pulse if held too long; hidden when idle |
| Alternate indicators (later) | Arc meter, compression bar — same timing logic |

Release while idle is ignored. A new hold during cooldown is ignored. Swing cooldown applies after resolve, before the next charge is allowed.

### Timing tiers

| Tier | Window (baseline) | Payout multiplier | Combo |
|------|-------------------|-------------------|-------|
| **Perfect** | Tightest (±50 ms from peak) | 1.0× (baseline for rhythm) | Advances combo |
| **Good** | Medium (±100 ms) | ~0.7× | May advance combo (upgradeable) |
| **OK** | Wide (±150 ms) | ~0.4× | No combo advance |
| **Miss** | Outside all windows, or release before min hold (~50 ms) | Pity payout (~0.1×) | Breaks combo |

**Fortune Mill chill rule:** Miss never pays zero. Partial credit keeps flow alive.

### Combo system

- Consecutive **Perfect** hits stack a combo counter
- Combo grants escalating multiplier (e.g. +10% per stack, cap tunable)
- **Miss** breaks combo; **Good** breaks unless "Combo keeper" upgrade owned
- Combo breakpoint (e.g. 5, 10 Perfects) can trigger **jackpot feedback tier** — see [07-art-and-atmosphere.md](07-art-and-atmosphere.md)

### Perfect strike chain (v1: 2 levels)

When `CHAIN_ENABLED` is true in `balance.gd` (default on; future upgrade gate):

| Step | Player action | Result |
|------|---------------|--------|
| 1 | Release **Perfect** on base charge | Enter **chain window** (~100 ms) — swing not resolved yet; meter flashes orange **"Again!"** |
| 2a | Press/hold within window | **Chain charge** — faster ring (~40% of base charge time), orange **"CHAIN!"** styling |
| 2b | Window expires without press | Resolve as **Perfect level 1** — normal payout, ball flies |
| 3 | Release on chain charge | Tier evaluated on faster curve; **Perfect** = **chain level 2** payout (`CHAIN_LEVEL_2_MULT`, default 2.0× on top of tier + combo); non-Perfect resolves at that tier and chain ends |

Max depth is **2** (no third ring). Audio: perfect chime → chain window tick → bigger chime on chain perfect.

## Swing cadence (separate from charge duration)

After a swing resolves, a **cooldown** gates the next valid charge input.

| Concept | Description |
|---------|-------------|
| Charge duration | Time for power to reach peak (~0.5s, tuned in `balance.gd`) |
| Swing cadence | Minimum time between resolved swings |
| Upgrades | "Faster follow-through" shrinks cooldown → more balls per minute |

This lets throughput increase without making the timing minigame stressful.

## Ball flight resolution

1. Timing tier → base accuracy modifier
2. Player stats (club, ball, power upgrades) → **yards**
3. Target zone (v1.5+) → zone multiplier
4. All mults → final payout (see [03-economy.md](03-economy.md))

Ball flight is primarily **visual** — tween along arc toward target depth. Physics simulation is not required for v1.

## Feedback tiers (game feel)

Each resolved swing emits a `FeedbackTier` used by audio/VFX:

| FeedbackTier | Typical trigger |
|--------------|-----------------|
| `whisper` | OK hit, small payout |
| `warm` | Perfect, modest combo |
| `jackpot` | Bullseye, crit, combo milestone, payout threshold |
| `milestone` | Branch unlock, time-of-day shift |

See [07-art-and-atmosphere.md](07-art-and-atmosphere.md) for spike rules.

## Passive income (v2 — stub in v1)

Not active in v1. Architecture reserves:

- `manualIncome` — player rhythm swings
- `passiveIncome` — golf friend auto-swings (see [06-characters.md](06-characters.md))

v1 economy module should not assume passive income exists, but types should allow `passiveRate: number` defaulting to 0.

## v1 core loop checklist

- [ ] Hold begins charge and power curve rises to peak
- [ ] Release registers timing against peak moment
- [ ] Tier + yards + payout calculated and emitted as event
- [ ] Combo updates on tier rules
- [ ] Swing cooldown enforced between swings
- [ ] Ball flight tween plays regardless of tier

## Related docs

- Economy math: [03-economy.md](03-economy.md)
- Range and targets: [02-world-and-range.md](02-world-and-range.md)
- Upgrades affecting rhythm: [04-upgrade-tree.md](04-upgrade-tree.md) → Branch 1
