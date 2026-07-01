# Economy & Progression Findings

**Status:** Research + simulation (July 2026). Code still uses ×2 paired curves in `definitions.gd` until v3 balance pass lands.

## Executive summary

The v2 upgrade tree applies **×2 stat growth and ×2 cost growth on all 14 nodes**. That pairing makes every Base Pay level cost exactly **one bucket** of current income and causes **multiplicative explosion** when Power, Quality, Pickup, and Distance Pay stack. Sessions end in minutes instead of hours.

**Recommendation:** Keep exponential progression, but use **different rates per branch**. Cost growth should **slightly exceed** effect growth (`costRate / effectRate ≈ 1.04–1.08`). Money branches (~1.28× effect) can outpace power (~1.12× effect).

---

## Current state (code audit)

All definitions in `scripts/game/upgrades/definitions.gd`:

| Node | Branch | Effect | Cost growth | Base cost |
|------|--------|--------|-------------|-----------|
| `base_pay` | Base Pay | ×2 `base_amount` | ×2 | $1.50 |
| `power` | Power | ×2 `carry_multiplier` | ×2 | $6 |
| `distance_pay` | Power | unlock + ×2 `pay_per_yard` | ×2 | $12 |
| `iron_set` | Power | ×2 `base_yards` | ×2 | $24 |
| `power_surge` | Power | ×2 `carry_multiplier` | ×2 | $24 |
| `quality` | Quality | unlock + ×2 `quality_multiplier` | ×2 | $6 |
| `metronome` | Quality | +8 ms Perfect window | ×2 cost | $12 |
| `great_eye` | Quality | +10 ms Great window | ×2 cost | $24 |
| `quick_reset` | Quality | ×0.5 cooldown | ×2 cost | $24 |
| `pickup` | Pickup | unlock + ×2 `pickup_multiplier` | ×2 | $6 |
| `tip_jar` | Pickup | +$0.25 flat/ball | ×2 cost | $12 |
| `combo_bonus` | Pickup | +10% combo/tier | ×2 cost | $12 |
| `quick_hands` | Pickup | +0.15 s combo window | ×2 cost | $12 |
| `magnetic_glove` | Pickup | stub | ×2 cost | $48 |

**Income formula** (`scripts/game/economy.gd`):

```
payout = base_amount
       + base_amount × pay_per_yard × stored_yards   (Distance Pay)
       × quality × quality_multiplier                 (Quality)
       × pickup_multiplier + flat_bonus               (Pickup)
       × combo_mult
```

**Flight** (separate from `$`): `carry_yards = base_yards × carry_multiplier × strike_quality`

Early baseline: **$0.25/ball**, 6 balls = **$1.50/bucket**. Tree unlock = **$1.50**.

---

## Problem 1: Paired doubling on Base Pay

When effect and cost both double:

| Level | Cost | Income/bucket | Payback |
|-------|------|---------------|---------|
| 0→1 | $1.50 | $1.50 | **1.0 buckets** |
| 1→2 | $3.00 | $3.00 | **1.0 buckets** |
| 5→6 | $48 | $48 | **1.0 buckets** |

Payback is **always 1.0** — no saving phase, no tension, no "one more bucket" stretch.

---

## Problem 2: Branch stacking

Simulated **21-purchase realistic path** (unlock → spine → branch heads → depth):

| Curve set | Buckets | Time (~16 s/bkt) | Final $/bucket |
|-----------|---------|------------------|----------------|
| **×2 paired (current)** | ~8 | ~2 min | **~$3.3M** |
| **Engagement-tuned (proposed)** | ~14 | ~4 min | **~$291** |

Same player choices, **~14,000×** income difference.

Single branch at Lv.8:

| Branch | ×2 income/bucket | Engagement income/bucket |
|--------|------------------|--------------------------|
| Base Pay | $384 | ~$11 |
| Power + Distance Pay | ~$3,135 | ~$5 |
| Quality | ~$1,536 | ~$18 |
| Pickup | $384 | ~$6 |

---

## External research

### Genre math (incremental games)

| Source | Finding |
|--------|---------|
| [Anthony Pecorella — Math of Idle Games, Part I](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i) | Costs grow exponentially; production usually **linear or polynomial**. Multiple generators with **shifting priority** keep choices interesting. |
| [Cookie Clicker paper (Demaine et al.)](https://arxiv.org/abs/1808.07540) | Building cost multiplier **α = 1.15** per purchase — applies to **cost**, not matched stat doubling. |
| AdVenture Capitalist (same article) | Lemonade stand cost rate **1.07**; production **linear per owned**. |
| [Idle Game Generator](https://idlegamegenerator.toolpile.dev/) | Target first growth in **2–5 min**; meaningful decisions every **60–90 s** in core loop. |
| [Idle Idol balancing (Game Developer)](https://www.gamedeveloper.com/design/balancing-tips-how-we-managed-math-on-idle-idol) | Spreadsheets need playtest; **UI/tutorial gaps** can feel like bad curves. |

### Engagement psychology

| Source | Finding |
|--------|---------|
| [MIT Kao et al. 2012 — Reward Preference in Video Games](https://people.csail.mit.edu/dkao/pdf/kao2012rewardpreference.pdf) | Players prefer **variable** reward schedules over fixed (same mean). |
| [Friendly GameDev — Reward Schedules](https://friendlygamedev.com/reward-schedules-in-video-games/) | Onboarding = frequent rewards; core = varied meaningful rewards; endgame = rare high-value rewards. |

**Implication for Golf Incremental:** Variable reinforcement is **already built in** via timing tiers (Perfect → Miss) and harvest combo. Economy should **amplify** skill variance, not grow so fast that upgrades swamp it.

### Built-in skill variance (no upgrades)

| Tier | Flat $/ball | + Distance Pay | + Quality |
|------|-------------|----------------|-----------|
| Perfect | $0.25 | $0.40 | **$2.40** |
| Great | $0.25 | $0.37 | $1.85 |
| Good | $0.25 | $0.34 | $1.36 |
| Miss | $0.25 | $0.27 | $0.27 |

---

## Core balance metric: payback period

```
payback_buckets = upgrade_cost / current_income_per_bucket
```

**Golden rule:**

```
costRate / effectRate  >  1.0   (target 1.04 – 1.08)
```

| Curve set | Avg cost/effect ratio | Spine payback at Lv.10 |
|-----------|----------------------|-------------------------|
| ×2 paired | **1.000** (broken) | 1.0 buckets |
| Engagement-tuned | **~1.041** | **~1.5 buckets** |

### Payback targets by phase

| Phase | Payback (buckets) | Real time (@ ~16 s/bucket) |
|-------|-------------------|----------------------------|
| Onboarding | 1.0 – 1.5 | 16 – 24 s |
| Core loop | 1.5 – 3.0 | 24 – 49 s |
| Side / QoL branches | 2.0 – 5.0 | 32 – 81 s |
| Deep / pre-crew | 5.0 – 10.0 | 1.4 – 2.7 min |

---

## Recommended curves (v3 target)

| Node group | effectGrowth | cost growthRate | Rationale |
|------------|--------------|-----------------|-----------|
| **Base Pay** | **1.28** | **1.34** | Money spine; payback stretches over time |
| **Distance Pay, Pickup mult** | **1.18 – 1.20** | **1.22 – 1.24** | Harvest / yardage money |
| **Quality mult** | **1.15** | **1.20** | Skill expression |
| **Power, Power Surge** | **1.12** | **1.17** | Slowest — visible distance |
| **Iron Set** | **1.10** | **1.15** | Baseline yards |
| **QoL (add)** | additive | **1.20 – 1.25** | Metronome, Tip Jar, Combo, Quick Hands |
| **Quick Reset** | ×0.5 cooldown | **1.30** | Strong tempo upgrade |

### Stat growth at Lv.10 (comparison)

| Rate | Lv.10 multiplier |
|------|------------------|
| ×2 (current) | **1024×** |
| 1.35 (fast money) | ~20× |
| 1.15 (power) | ~4× |
| 1.22 (quality) | ~7× |

---

## Branch roles (design intent)

| Branch | Player fantasy | Growth speed |
|--------|----------------|--------------|
| **Base Pay** | "My range pays better" | Fastest money |
| **Pickup** | "Harvesting feels great" | Fast money + QoL |
| **Quality** | "Clean contact pays" | Medium |
| **Power** | "I hit it farther" | **Slowest** |

**Pecorella principle:** Branches should **take turns** being the best buy — not all inflate at ×2 simultaneously.

---

## Session arc targets

| Phase | Buckets | Player state |
|-------|---------|--------------|
| Opening | 1–3 | Tree unlock + Base Pay 1–2 |
| Branching | 4–8 | Pick Power / Quality / Pickup |
| Stacking | 9–20 | Depth in 2–3 branches |
| Mid-game | 20–60 | Iron Set, combo, quality depth |
| Crew gate | ~$250k lifetime | Rat friend hire |
| Late | 60+ | Deep tree + passive crew |

With ×2 curves, **$250k lifetime** arrives in minutes — breaking crew as a long-tail hook. With engagement curves, crew lands around **session 2 (~60–90 min)**.

---

## Crew / passive income (long-tail)

From [v2/05-characters-and-crew.md](../../v2/05-characters-and-crew.md); v3 tuning:

| Gate | Requirement | Passive role |
|------|-------------|--------------|
| First Rat friend | **$250k lifetime** | ~15% of active pickup at hire |
| Second friend | **$2M lifetime** | Volume + visible second bay |
| Crew upgrades | effect **1.08 – 1.12** | Slow scale over hours |
| Synergy | player combo active | crew **+25%** that harvest |

Passive uses live stats at collection — crew swings mediocre timing but volume. Must not replace active play until very late.

---

## Implementation checklist

1. Apply per-node rates to `scripts/game/upgrades/definitions.gd`
2. Update `verify_upgrade_tree.gd` and `verify_upgrade_effects.gd` expected values
3. Playtest: one full bucket cycle after each branch unlock — target **1.5–3 buckets** payback
4. Optional: `tools/simulate_economy.gd` for payback sweeps
5. Align crew milestone gates after curves land in code

---

## References

- [Pecorella — Math of Idle Games, Part I](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i)
- [Pecorella — Part III (prestige)](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii)
- [Demaine et al. — Cookie Clicker (arXiv:1808.07540)](https://arxiv.org/abs/1808.07540)
- [Kao et al. 2012 — Reward Preference in Video Games (MIT)](https://people.csail.mit.edu/dkao/pdf/kao2012rewardpreference.pdf)
- [Idle Idol balancing — Game Developer](https://www.gamedeveloper.com/design/balancing-tips-how-we-managed-math-on-idle-idol)
- Project: [v2/03-economy.md](../../v2/03-economy.md), [v2/04-upgrade-tree.md](../../v2/04-upgrade-tree.md)
