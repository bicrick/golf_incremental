# v2 Economy

## Currency

**Range Bucks (`$`)** — unchanged internal key `currency`. Display `$` prefix.

## Income streams (v2)

| Stream | Phase | Description |
|--------|-------|-------------|
| `manual_hit` | v2.0 | Small $ per resolved swing (contact tier × mults) |
| `pickup` | v2.0 | Per-ball collected + bucket complete bonus + combo |
| `passive_range` | v2.1+ | Range quality, bays, amenities — $/sec while playing |
| `passive_crew` | v2.2+ | Rat friends / gnome efficiency — pickup assist or bay swings |
| `target_bonus` | v2.2+ | Zone mult on landing in depth band / bullseye |

Early game **pickup share target:** 40–60% of bucket cycle income. Hits feel meaningful visually; money comes from **running the range**.

## Payout formula (per swing)

```
yards = contact_quality_curve(timing) × carry_tier_cap(stats)
       (NOT raw base_yards × hold_power)

payout = yards × tier_mult × club_mult × ball_mult × target_zone_mult
       × outfit_mult × global_mult × dollars_per_yard
       + flat_bonus_per_swing
```

### v2 changes from v1

| v1 | v2 |
|----|-----|
| `yards_from_quality(hold_duration)` | `yards_from_contact(release_delta_ms)` |
| Distance branch: `base_yards`, `max_yards` early | **Sweet spot / carry tier** branch; slow `max_yards` growth |
| Every hit reloads tee | Hit only when `bucket > 0` |

### Pickup payout (per harvest cycle)

```
pickup_payout = sum(per_ball_value × combo_mult(ball_index))
              + bucket_complete_bonus
              - stolen_ball_opportunity_cost   (v2.1 gophers)
```

Tune so one full bucket cycle (6 hits + pickup) ≈ first upgrade cost × 0.8–1.2.

## Cost curve

Unchanged structure:

```
cost(level) = floor(baseCost × growthRate^level)
```

**Slower early progression intent:** slightly higher `growthRate` on economy branch OR higher first-upgrade costs; bucket pacing gates income without invisible nerfs.

## Milestone gates (v2 examples)

| Milestone | Unlocks |
|-----------|---------|
| First bucket cleared | Pickup combo visible |
| $500 lifetime | +2 bucket capacity |
| $2,000 | Range patch upgrade (visual) |
| $10,000 | Gnome hire (v2.1) |
| $100,000 | Target zone chapter (v2.2) |

## Feedback tiers

Unchanged enum; triggers add:

| FeedbackTier | v2 trigger |
|--------------|------------|
| `whisper` | OK hit, small pickup |
| `warm` | Perfect contact |
| `jackpot` | Bucket combo ≥4, bullseye, absurd carry tier |
| `milestone` | Range tier unlock, zone unlock |

## Related docs

- Upgrade branches: [04-upgrade-tree.md](04-upgrade-tree.md)
- Pickup numbers: [06-pickup-minigame.md](06-pickup-minigame.md)
- v1 formula reference: [../design/03-economy.md](../design/03-economy.md)
