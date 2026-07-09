# v2 Economy

## Currency

**Range Bucks (`$`)** — unchanged internal key `currency`. Display `$` prefix.

## Income streams (v2)

| Stream | Phase | Description |
|--------|-------|-------------|
| `pickup` | v2.0 | **Primary income** — per-ball collected at harvest using formula below |
| `bucket_complete` | deferred | Removed by default; optional late Pickup upgrade later |
| `passive_range` | shipped | Ball count + golden balls — upgrade tree (`ball_count`, `golden_ball`) |
| `passive_crew` | shipped | Ratina + Rattlings hire nodes on upgrade tree |
| `target_bonus` | deferred | Zone mult (later) |

**Money is earned at pickup, not at contact.** Swings capture `quality` (1–6) and `yardage` on each litter ball; payout is computed when the ball is collected, using **live stats at pickup time**.

Early game: flat **`$0.25`** per ball (6 balls = **$1.50** per bucket) until branch upgrades stack on top.

## Upgrade tree access gate

The icon-bar **Upgrade Tree** button costs **$1.50** once to unlock permanently — exactly one full bucket at start.

**Base Pay Lv.1** also costs **$1.50** and raises flat pay ($0.25 → ~$0.34 at proposed curves). See [Growth curves](#growth-curves-per-branch) below — **do not use paired ×2** on effect and cost; that makes every spine level cost exactly one bucket and collapses the session.

## Flight yards (distance-pays)

Contact decides how far the ball flies. Distance decides how much it pays.

```
contact = apply_sweet_spot(strike_quality, stats)
yards   = base_yards × contact × perfect_power_mult(contact, stats)
```

- **Sweet Spot** pulls high contact toward Perfect (flight only).
- **Perfect Pop** multiplies yards on near-Perfect contact (ramps from Great band).
- Steep Perfect→Miss gap via `Balance.TIER_MULTS` (1.0 → ~0.08).
- No `carry_multiplier` upgrades; `pay_per_yard` / `base_amount` do **not** affect flight.

## Pickup payout formula

**Era 0:** `payout = base_amount`

**+ Distance Pay:** `payout = base_amount + base_amount × pay_per_yard × stored_yards`

**No quality $ term** — tier/quality no longer multiplies cash at pickup.

**+ Pickup branch:** apply `pickup_multiplier` and `pickup_flat_bonus` when unlocked

**+ Combo Bonus:** `× (1 + combo_mult_per_tier × (tier − 1))` — off until upgraded

| Stat | Default | Axis |
|------|---------|------|
| `base_amount` | $0.25 | flat pay |
| `pay_per_yard` | 0.1 → ~10.0 max | $ bonus per yard (Yardage Pay) |
| `base_yards` | 30 | flight baseline |
| `sweet_spot_bonus` | 0 | contact pull (flight) |
| `perfect_power_bonus` | 1.0 | Perfect Pop (flight) |

## Branch unlock (fan-out at Base Pay Lv.1)

| Branch head | Role |
|-------------|------|
| Power | Yardage Pay (`pay_per_yard`) → Raw Power (`base_yards`) |
| Quality / Sweet Spot | Contact power + timing QoL + Perfect Pop |
| Pickup | Harvest bonuses + combo |

## Cost curve

```
cost(level) = floor(baseCost × growthRate^level × 100) / 100
```

Effect scaling (multiply nodes):

```
stat(level) = baseStat × effectGrowth^level
```

**Important:** `growthRate` (cost) and `effectGrowth` (stat) are **independent**. Paired ×2 on both makes every Base Pay level cost exactly one bucket of current income — fun for five minutes, then the run is over.

## Growth curves (per branch)

Design goal: **exponential forever, but not doubling.** Money branches can grow faster than power; power should feel like a slow climb (1.12–1.18×), not nuclear (×2).

| Axis | Role | effectGrowth | cost growthRate | Payback target |
|------|------|--------------|-----------------|----------------|
| **Money spine** | `base_amount` | **1.35** | **1.42** | 1–2 buckets early, 3–6 mid |
| **Yardage Pay** | `pay_per_yard` (0.1 → ~10.0) | **1.20** | **1.28** | 2–4 buckets |
| **Money branches** | `pickup_multiplier` | **1.25–1.28** | **1.28–1.32** | 2–4 buckets |
| **Contact / Sweet Spot** | `sweet_spot_bonus`, `perfect_power_bonus` | additive / **1.08** | **1.28–1.34** | 2–6 buckets |
| **Raw Power** | `base_yards` | +3 yd/lvl | **1.20–1.22** | 3–8 buckets |
| **Skill / QoL** | timing windows, combo | additive | **1.20–1.32** | 3–10 buckets |
| **Tempo** | `swing_cooldown_ms` (×0.5/lvl) | fixed | **1.30** | 5–12 buckets |

### Why these numbers

| Curve | Lv.10 stat mult | Feel |
|-------|-----------------|------|
| ×2 (legacy) | **1024×** | Session over in ~15 min |
| Money 1.35 | **~20×** | Strong income, still climbing |
| Perfect Pop 1.08 | **~2.2×** | Late Perfect fantasy without cash double-dip |
| Raw Power +3 yd | linear | Visible distance gains |

### Early pacing (proposed)

| Milestone | Cost | Income per bucket (flat era) | Payback |
|-----------|------|--------------------------------|---------|
| Tree unlock | $1.50 | $1.50 (6 × $0.25) | 1 bucket |
| Base Pay Lv.1 | $1.50 | ~$2.03 (6 × $0.34) | ~1 bucket |
| Base Pay Lv.3 | ~$4 | ~$3.69 | ~1.1 buckets |
| Branch head Lv.1 | $6.00 | ~$3.69 after Base Pay Lv.3 | ~1.6 buckets |
| First branch stack (Lv.4 base + 1 branch) | varies | ~$40–60/bucket | choices matter |

After ~**12 buckets** (~25 min): player should sit around **$50–80/bucket** with 3 branches started — not millions.

## Session arc targets

| Phase | Buckets | Player state | Feel |
|-------|---------|--------------|------|
| Opening | 1–3 | Tree + Base Pay 1–2 | "Numbers tick up" |
| Branching | 4–8 | Pick 1–2 branch heads | "Which build am I?" |
| Stacking | 9–20 | Depth in 2–3 branches | "I'm optimizing" |
| Mid-game | 20–60 | Iron Set, combo, quality depth | "Big harvests" |
| Crew gate | ~$250k lifetime | Rat crew unlock (see below) | "I can hire help" |
| Late | 60+ | Deep tree + passive crew | "Range tycoon" |

Always surface **next milestone** and **3–5 affordable upgrades across branches**.

## Passive crew (Rat friends — v2.2)

Deferred in code; design hook for long-tail engagement.

| Gate | Requirement | Why |
|------|-------------|-----|
| **Rat Friend bay** | $250,000 lifetime earnings | Manual pickup still fun; hiring is aspirational |
| **Second friend** | $2M lifetime | Range is visibly busy |
| **Crew payout tuning** | passive ≈ 15% of player pickup at hire | Does not replace active play early |
| **Crew upgrades** | slow effect growth (1.08–1.12) | Passive scales over hours, not minutes |

Passive income uses live `PlayerStats` at collection time — crew swings mediocre timing but volume. Synergy: player combo active → crew +25% that harvest cycle (from [05-characters-and-crew.md](05-characters-and-crew.md)).

Income streams when crew ships:

```
totalIncome ≈ manualPickupPerHarvest + passiveSwingsPerSec × avgPassivePayout
```

## Tuning workflow

1. Change numbers in `scripts/game/upgrades/definitions.gd` only (data-driven).
2. Run `verify_upgrade_tree.gd`, `verify_upgrade_effects.gd`, `verify_pickup.gd`.
3. Playtest one full bucket cycle after each branch unlock — target **2–5 buckets** to afford the next meaningful node.
4. If income still explodes when branches stack, **lower effectGrowth** before raising costs (cost-only fixes feel grindy).
