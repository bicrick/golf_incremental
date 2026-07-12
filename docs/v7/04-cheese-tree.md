# v7 Cheese (Prestige) Tree

OP-only skill tree. Bought with **cheese**. Persists across prestiges. Never spends cash.

## Layout (logical)

```text
                         [Cheese Press]     root — more cheese per prestige
                                |
              +-----------------+-----------------+
              |                                   |
        [Ambition]                          [Hot Streak]
     higher threshold                      unlocks Perfect Chain
     + bigger base payout                         |
              |                                   |
              +--------+--------+--------+--------+
              |        |        |        |        
        Quick Reset  Combo   Deep     Golden Tee
         (hitting)  Hands   Bucket
```

Exact radial/grid positions are an implementation detail; **parent / prerequisite edges** above are design-required.

## Nodes

### Meta

| ID | Name | Max | Prerequisite | Effect |
|----|------|-----|--------------|--------|
| `cheese_press` | Cheese Press | 10+ | — (root) | +base cheese granted each prestige |
| `ambition` | Ambition | 5+ | `cheese_press` ≥ 1 | Raises `prestige_threshold` (5k → 10k → …) **and** increases base cheese payout for that tier |

Starting Ambition table (tune in Balance):

| Level | Threshold | Notes |
|-------|-----------|-------|
| 0 | 5000 | Default |
| 1 | 10000 | |
| 2 | 20000 | |
| 3 | 40000 | |
| … | roughly ×2 | Keep payout scaling so higher tiers are worth waiting |

### Hitting

| ID | Name | Max | Prerequisite | Effect |
|----|------|-----|--------------|--------|
| `prestige_quick_reset` | Quick Reset | 5 | `cheese_press` ≥ 1 | Multiply swing cooldown (e.g. ×0.85/level — **weaker than old ×0.5^level**, still strong). Unlock only via cheese |

### Pickup

| ID | Name | Max | Prerequisite | Effect |
|----|------|-----|--------------|--------|
| `prestige_combo` | Combo Hands | 5 | `cheese_press` ≥ 1 | Sets/adds `combo_mult_per_tier` (e.g. +0.08/level). Combo **off** until level ≥ 1 |

### Bucket

| ID | Name | Max | Prerequisite | Effect |
|----|------|-----|--------------|--------|
| `prestige_deep_bucket` | Deep Bucket | 4 | `cheese_press` ≥ 1 | +1 permanent bucket capacity per level (6 → 7 → …). Default life always starts at `6 + levels` |

### Spike

| ID | Name | Max | Prerequisite | Effect |
|----|------|-----|--------------|--------|
| `prestige_golden_tee` | Golden Tee | 10 | `cheese_press` ≥ 1 | +golden ball chance per level (e.g. +2%/level; define base 0 or small floor in Balance) |

### Skill streak

| ID | Name | Max | Prerequisite | Effect |
|----|------|-----|--------------|--------|
| `prestige_perfect_chain` | Perfect Chain | 1 (or small stack) | `cheese_press` ≥ 1; optional child of a “Hot Streak” stub or direct from root | After **3 Perfect swings in a row**, subsequent teed balls are **golden while the Perfect streak remains unbroken**. Miss the streak → golden-from-chain ends until 3 Perfects again |

**Perfect Chain tracking:** increment on Perfect resolve; reset on any non-Perfect swing (including Miss). Golden flag applied at tee-prep when `perfect_streak >= 3` and perk owned. Does not replace shop/cheese golden chance — chain goldens are guaranteed while active.

## Explicitly not on this tree (v7)

- Pay Primer / Yardage Primer
- Caddy’s Whistle
- Ratina / Rattling unlocks
- Landlord / due modifiers

## Costs

Use same style as cash upgrades: `Economy.upgrade_cost`-like curve with cheese as currency. Starting point: cheap root (1–2 cheese), branching nodes 2–5+, Ambition expensive. Exact numbers in `Balance` / prestige definitions — playtest after Workstream 0 constants land.

## Purchase rules

- Can buy anytime the Prestige tab is open (including mid-run), if `cheese` ≥ cost.
- Spending cheese never blocks the $5k cash gate (different currency).
- No refunds.
