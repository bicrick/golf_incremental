# v2 Economy

## Currency

**Range Bucks (`$`)** — unchanged internal key `currency`. Display `$` prefix.

## Income streams (v2)

| Stream | Phase | Description |
|--------|-------|-------------|
| `pickup` | v2.0 | **Primary income** — per-ball collected at harvest using formula below |
| `bucket_complete` | v2.0 | Flat bonus when harvest finishes |
| `passive_range` | deferred | Range amenities — Shop / tycoon (later) |
| `passive_crew` | deferred | Ratina / crew — Shop (later) |
| `target_bonus` | deferred | Zone mult (later) |

**Money is earned at pickup, not at contact.** Swings capture `quality` (1–6) and `yardage` on each litter ball; payout is computed when the ball is collected, using **live stats at pickup time**.

Early game is intentionally slow: `base_amount` starts at **$0.25** per ball with no yardage or quality terms active.

## Flight yards (display only at swing)

```
yards = min(base_yards × yard_multiplier × timing_quality(release_delta_ms), max_yards)
```

Yards drive ball flight and the litter metadata stored on each ball. They do not grant currency at swing time.

## Pickup payout formula (progressive unlock)

Formula terms unlock via **key upgrades** in the upgrade tree (not lifetime-$ thresholds):

```
Era 0 (start):     payout = base_amount × combo_mult

+ Yardage Markers: payout = base_amount × yardage × yardage_multiplier × combo_mult

+ Contact Awareness:
                   payout = base_amount × yardage × yardage_multiplier
                          × quality × quality_multiplier × combo_mult
```

Evaluated at **pickup time** using the ball's stored `quality`/`yardage` and the player's **current** stats.

| Variable | Default | Type | Notes |
|----------|---------|------|-------|
| `base_amount` | $0.25 | anchor | Leveled by Base Pay branch |
| `yardage` | from swing | per-ball | Stored on litter at landing |
| `yardage_multiplier` | 0.02 | rate constant | Not a 1.0-start bonus mult — converts raw yards to $ |
| `quality` | 1–6 | per-ball | Miss=1 … Perfect=6 (`Balance.QUALITY_FOR_TIER`) |
| `quality_multiplier` | 1.0 | bonus mult | Type-1 multiplier; only climbs above 1.0 |
| `combo_mult` | 1.0 + 0.1×(tier−1) | pickup streak | Unchanged combo window |

### Bucket complete bonus

```
bucket_complete_bonus = BUCKET_COMPLETE_BONUS × global_multiplier
```

## Cost curve

```
cost(level) = floor(baseCost × growthRate^level)
```

Deep branches (Base Pay, Yardage Mult, Quality Mult) use high `max_level` (50–100+) with gentle growth for long runway.

## Key upgrade gates

| Key upgrade | Unlocks | Prerequisite |
|-------------|---------|--------------|
| *(none)* | Base Pay branch only | game start |
| Yardage Markers | `yardage × yardage_multiplier` terms | Base Pay Lv.15 |
| Contact Awareness | `quality × quality_multiplier` terms | Yardage Mult Lv.15 |

## Deferred (Shop — not upgrade tree)

- Balls, clubs, clothing/outfits (tiered one-time purchases)
- Ratina / crew hire
- Range tycoon visual upgrades

## Feedback tiers

| FeedbackTier | Trigger |
|--------------|---------|
| `whisper` | Non-Perfect swing contact |
| `warm` | Perfect contact |
| `jackpot` | Large pickup payout or big combo (at harvest) |
| `milestone` | Key upgrade purchased |

## Related docs

- Upgrade branches: [04-upgrade-tree.md](04-upgrade-tree.md)
- Pickup flow: [06-pickup-minigame.md](06-pickup-minigame.md)
- Core loop: [01-core-loop.md](01-core-loop.md)
