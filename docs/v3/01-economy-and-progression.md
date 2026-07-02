# v3 Economy & Progression

High-level direction for balance work. **Full audit, research, and numbers:** [findings/economy-progression-findings.md](findings/economy-progression-findings.md).

## Goal

Make the game **fun for an hour**, not **done in five minutes** — while keeping exponential growth, multiplicative branches, and jackpot spikes on Perfect/combo moments.

## Three rules

1. **Unpair effect and cost growth** — never ×2 on both for the same node.
2. **Power slow, money medium, QoL additive** — see findings table.
3. **Payback period rises over time** — if every upgrade costs exactly one bucket, the curve is wrong.

## What stays the same

- Pickup-time payout formula (v2)
- 14-node fan-out tree structure
- $1.50 tree unlock = one bucket
- Skill layers: contact timing + harvest combo

## What changes (v3)

- ~~Per-branch `effectGrowth` and `growthRate` in `definitions.gd`~~ **Landed**
- ~~Per-level cost stretch (`UPGRADE_COST_LEVEL_STRETCH`)~~ **Landed**
- ~~Compounding sim gate (`tools/simulate_economy.gd`)~~ **Landed**
- Milestone / crew gates tuned to multi-session lifetime earnings

## Tuning workflow

1. Change numbers in `definitions.gd` only.
2. Run `verify_upgrade_tree.gd`, `verify_upgrade_effects.gd`, `verify_pickup.gd`.
3. Playtest one bucket cycle per branch unlock.
4. Adjust **effect** before **cost** if income still explodes (cost-only fixes feel grindy).

## Related docs

- [findings/economy-progression-findings.md](findings/economy-progression-findings.md)
- [02-long-tail-content.md](02-long-tail-content.md)
- v2 formula reference: [v2/03-economy.md](../v2/03-economy.md)
