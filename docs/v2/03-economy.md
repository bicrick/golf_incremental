# v2 Economy

## Currency

**Range Bucks (`$`)** — unchanged internal key `currency`. Display `$` prefix.

## Income streams (v2)

| Stream | Phase | Description |
|--------|-------|-------------|
| `pickup` | v2.0 | **Primary income** — per-ball collected at harvest using formula below |
| `bucket_complete` | deferred | Removed by default; optional late Pickup upgrade later |
| `passive_range` | deferred | Range amenities — Shop (later) |
| `passive_crew` | deferred | Ratina / crew — Shop (later) |
| `target_bonus` | deferred | Zone mult (later) |

**Money is earned at pickup, not at contact.** Swings capture `quality` (1–6) and `yardage` on each litter ball; payout is computed when the ball is collected, using **live stats at pickup time**.

Early game: flat **`$0.25`** per ball (6 balls = **$1.50** per bucket) until branch upgrades stack on top.

## Upgrade tree access gate

The icon-bar **Upgrade Tree** button costs **$1.50** once to unlock permanently — exactly one full bucket at start.

**Base Pay Lv.1** also costs **$1.50** and **doubles** flat pay ($0.25 → $0.50). Each further Base Pay level doubles again ($1.00, $2.00, …) with cost doubling in lockstep (~one bucket per level on the spine).

## Flight yards (carry — stats + strike quality only)

```
carry_yards = base_yards × carry_multiplier × strike_quality
```

No gameplay cap. `pay_per_yard` and `base_amount` do **not** affect flight.

## Pickup payout formula

**Era 0:** `payout = base_amount`

**+ Distance Pay:** `payout = base_amount + base_amount × pay_per_yard × stored_yards`

**+ Quality:** multiply shot value by `quality × quality_multiplier`

**+ Pickup branch:** apply `pickup_multiplier` and `pickup_flat_bonus` when unlocked

**+ Combo Bonus:** `× (1 + combo_mult_per_tier × (tier − 1))` — off until upgraded

| Stat | Default | Axis |
|------|---------|------|
| `base_amount` | $0.25 | flat pay |
| `pay_per_yard` | 0.02 | $ bonus per yard (not carry) |
| `carry_multiplier` | 1.0 | flight only |
| `quality_multiplier` | 1.0 | tier pay bonus |

## Branch unlock (fan-out at Base Pay Lv.1)

| Branch head | Role |
|-------------|------|
| Power | Carry (`carry_multiplier`); chain includes Distance Pay (`pay_per_yard`) |
| Quality | Timing windows + tier pay |
| Pickup | Harvest bonuses + combo |

## Cost curve

```
cost(level) = floor(baseCost × growthRate^level × 100) / 100
```

**Paired doubling:** most nodes use `growthRate = 2.0` and stat effects that **×2 per level**. Early pacing:

| Milestone | Cost | Income per bucket (flat era) |
|-----------|------|------------------------------|
| Tree unlock | $1.50 | $1.50 (6 × $0.25) |
| Base Pay Lv.1 | $1.50 | $3.00 (6 × $0.50) |
| Base Pay Lv.2 | $3.00 | $6.00 |
| Branch head Lv.1 (Power / Quality / Pickup) | $6.00 | $3.00 after Base Pay Lv.1 |

Branch heads cost ~**2 buckets** after the first Base Pay buy — hot start, but you cannot buy all three branches instantly.

Multiplicative stat gains + multiplicative costs → fast early progress with escalating payback as branches stack.
