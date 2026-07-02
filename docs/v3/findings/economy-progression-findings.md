# Economy & Progression Findings

**Status:** v2 compounding fix landed (July 2026). Per-branch curves + per-level cost stretch in `definitions.gd`, `balance.gd`, and `economy.gd`. Validated by `tools/simulate_economy.gd` (~90 min full tree).

## Executive summary

The v2 upgrade tree applies **×2 stat growth and ×2 cost growth on all 14 nodes**. That pairing makes every Base Pay level cost exactly **one bucket** of current income and causes **multiplicative explosion** when Power, Quality, Pickup, and Distance Pay stack. Sessions end in minutes instead of hours.

**v1 fix (per-branch curves):** Unpaired effect/cost growth per branch — necessary but not sufficient.

**v2 fix (compounding):** Playtest still completed the full tree in **~10 minutes**. Root cause: unlocking Quality + Distance Pay + Pickup multiplies income (~10× for ~$24 spent) while per-node cost/effect ratios (~1.04) only stretch payback in isolation. Fix uses three levers: **slash money-branch effect growth**, **wider cost/effect gap (~1.25–1.32)**, **per-level cost stretch** (`UPGRADE_COST_LEVEL_STRETCH = 0.165`), and **raised branch-head base costs**.

---

## Current state (code audit)

All definitions in `scripts/game/upgrades/definitions.gd` use **v2 compounding-aware curves** (see table below). Upgrade cost includes per-level stretch via `Balance.UPGRADE_COST_LEVEL_STRETCH` in `Economy.upgrade_cost()`. Simulation gate: `tools/simulate_economy.gd` (90–150 min full tree).

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

## Problem 3: Compounding across branches (v2 diagnosis)

Per-node `costRate / effectRate ≈ 1.04` stretches payback on a **single branch in isolation**. It does not account for income jumping ~10× when three money branches unlock:

| Unlock stage | Approx income/bucket | Cumulative unlock cost |
|--------------|---------------------|------------------------|
| Fresh | $1.50 | — |
| Quality Lv1 | ~$9 | $6 |
| + Distance Pay Lv1 | ~$14 | $18 |
| + Pickup Lv1 | ~$14+ | $24 |

**Playtest (July 2026):** Even after v1 per-branch curves, a fresh run still maxed the tree in **~10 minutes**. After branch unlocks, buying cheap Lv2–3 on each branch while all multipliers are active collapses payback to **0.05–0.20 buckets**. Fix: slow money effect growth to ~1.05–1.06, widen cost/effect to ~1.25–1.32, add per-level cost stretch, raise branch-head base costs.

---

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

## Recommended curves (v2 landed in code)

Global: `UPGRADE_COST_LEVEL_STRETCH = 0.165` — each level costs `(1 + level × 0.165)×` more than pure exponential.

| Node group | effectGrowth | cost growthRate | base_cost (heads) | Rationale |
|------------|--------------|-----------------|-------------------|-----------|
| **Base Pay** | **1.15** | **1.48** | $1.50 | Money spine |
| **Quality mult** | **1.06** | **1.34** | $12 | Slowest compound mult |
| **Pickup mult** | **1.06** | **1.38** | $12 | Slow compound mult |
| **Distance Pay** | **1.06** | **1.36** | $22 | Yardage money |
| **Power / Power Surge** | **1.05** | **1.26** | $12 / $36 | Carry spectacle only |
| **Iron Set** | **1.04** | **1.24** | $36 | Baseline yards |
| **QoL (add)** | additive | **1.32** | $18 / $36 | Metronome, Tip Jar, etc. |
| **Quick Reset** | ×0.5 cooldown | **1.40** | $36 | Strong tempo |

Sim result (`simulate_economy.gd`): **~90 min** full tree, avg payback **~1.9 buckets**, late Base Pay payback **~11 buckets**.

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

**Product target (July 2026):** ~**2 hours** to max entire upgrade tree (177 level purchases + $1.50 unlock ≈ **178 buys**). At ~16 s/bucket, that requires **~2.5 buckets average payback** over the full run (early ~1–2, late ~4–8).

| Phase | Time | Player state |
|-------|------|--------------|
| Opening | 0–15 min | Tree unlock + Base Pay 1–2 |
| Branching | 15–30 min | Pick Power / Quality / Pickup |
| Stacking | 30–60 min | Depth in 2–3 branches, first shop club optional |
| Mid-game | 60–90 min | `$`/yard is main income; carry approaches cap |
| Tree complete | **~120 min** | All 14 nodes maxed |
| Crew gate | ~$250k lifetime (post-tree or late tree) | Rat friend hire |
| Long tail | Session 2+ | Crew, amenities, zones |

### Carry cap (~400 yards)

Endgame should not exceed **~400 effective yards** on Perfect contact. Use soft cap:

```
effective_yards = carry_cap × (1 − exp(−raw_yards / carry_cap))
```

Power tree upgrades raise `raw_yards` slowly; **clubs** (shop) supply high-risk/high-reward carry; **Distance Pay** converts capped yards to `$`. See [03-clubs-and-shop.md](../03-clubs-and-shop.md).

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

1. ~~Apply per-node rates to `scripts/game/upgrades/definitions.gd`~~ **Done**
2. ~~Update `verify_upgrade_tree.gd` and `verify_upgrade_effects.gd` expected values~~ **Done**
3. ~~Add `UPGRADE_COST_LEVEL_STRETCH` + per-level cost escalation~~ **Done**
4. ~~`tools/simulate_economy.gd` compounding sim (90–150 min gate)~~ **Done**
5. Playtest: confirm fresh run no longer maxes tree in ~10 min
6. Align crew milestone gates after pacing is stable in playtest

---

## References

- [Pecorella — Math of Idle Games, Part I](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i)
- [Pecorella — Part III (prestige)](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii)
- [Demaine et al. — Cookie Clicker (arXiv:1808.07540)](https://arxiv.org/abs/1808.07540)
- [Kao et al. 2012 — Reward Preference in Video Games (MIT)](https://people.csail.mit.edu/dkao/pdf/kao2012rewardpreference.pdf)
- [Idle Idol balancing — Game Developer](https://www.gamedeveloper.com/design/balancing-tips-how-we-managed-math-on-idle-idol)
- Project: [v2/03-economy.md](../../v2/03-economy.md), [v2/04-upgrade-tree.md](../../v2/04-upgrade-tree.md)
