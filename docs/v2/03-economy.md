# v2 Economy

## Currency

**Range Bucks (`$`)** — unchanged internal key `currency`. Display `$` prefix.

## Income streams (v2)

| Stream | Phase | Description |
|--------|-------|-------------|
| `pickup` | v2.0 | **Primary income** — per-ball collected at harvest using formula below |
| `bucket_complete` | v2.0 | Flat bonus when harvest finishes |
| `passive_range` | deferred | Range amenities — Shop (later) |
| `passive_crew` | deferred | Ratina / crew — Shop (later) |
| `target_bonus` | deferred | Zone mult (later) |

**Money is earned at pickup, not at contact.** Swings capture `quality` (1–6) and `yardage` on each litter ball; payout is computed when the ball is collected, using **live stats at pickup time**.

Early game is intentionally slow: `base_amount` starts at **$0.25** per ball with no yardage or quality terms active.

## Upgrade tree access gate

The icon-bar **Upgrade Tree** button costs **$1.50** once to unlock permanently. Until then the button is disabled/greyscale with a `$1.50` tooltip. After unlock, the tree opens normally.

## Flight yards (display only at swing)

```
yards = min(base_yards × yard_multiplier × timing_quality(release_delta_ms), max_yards)
```

Yards drive ball flight and the litter metadata stored on each ball. They do not grant currency at swing time.

## Pickup payout formula (progressive unlock)

Formula terms unlock when the player buys the matching **branch head** node (each head is level 1 of that branch):

```
Era 0 (start):     payout = base_amount × combo_mult

+ Yardage head:    payout = base_amount × yardage × yardage_multiplier × combo_mult

+ Quality head:    payout = base_amount × yardage × yardage_multiplier
                          × quality × quality_multiplier × combo_mult
```

Evaluated at **pickup time** using the ball's stored `quality`/`yardage` and the player's **current** stats.

| Variable | Default | Type | Notes |
|----------|---------|------|-------|
| `base_amount` | $0.25 | anchor | Leveled by Base Pay branch |
| `yardage` | from swing | per-ball | Stored on litter at landing |
| `yardage_multiplier` | 0.02 | rate constant | Not a 1.0-start bonus mult |
| `quality` | 1–6 | per-ball | Miss=1 … Perfect=6 |
| `quality_multiplier` | 1.0 | bonus mult | Type-1 multiplier |
| `combo_mult` | 1.0 + 0.1×(tier−1) | pickup streak | Unchanged combo window |

Power branch affects **flight distance only** (`yard_multiplier`, `base_yards`, `max_yards`) — not pickup formula directly.

## Bucket complete bonus

```
bucket_complete_bonus = BUCKET_COMPLETE_BONUS × global_multiplier
```

## Cost curve

```
cost(level) = floor(baseCost × growthRate^level)
```

## Branch unlock (fan-out at Base Pay Lv.1)

| Branch head | Unlocks | Prerequisite |
|-------------|---------|--------------|
| *(none)* | Base Pay only | game start |
| Yardage | yardage payout term + `yardage_multiplier` levels | Base Pay Lv.1 |
| Quality | quality payout term + `quality_multiplier` levels | Base Pay Lv.1 |
| Power | flight distance chain | Base Pay Lv.1 |

## Deferred (Shop — not upgrade tree)

- Bucket capacity, balls, clubs, clothing/outfits
- Ratina / crew hire
- Range tycoon visual upgrades

## Related docs

- Upgrade branches: [04-upgrade-tree.md](04-upgrade-tree.md)
- Pickup flow: [06-pickup-minigame.md](06-pickup-minigame.md)
