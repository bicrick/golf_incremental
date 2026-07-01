# v3 Acceptance Criteria

Phased checklist. Economy rebalance is **v3.0**; crew and amenities follow.

## v3.0 — Economy rebalance

- [ ] All 14 upgrade nodes use per-branch rates from [findings/economy-progression-findings.md](../findings/economy-progression-findings.md) (not global ×2)
- [ ] `costRate / effectRate > 1.0` for every multiply node
- [ ] Base Pay Lv.10 payback ≥ 1.3 buckets (simulation or playtest)
- [ ] Realistic 20-purchase session: final income **< $1,000/bucket** (order-of-magnitude guard vs ×2 millions)
- [ ] `verify_upgrade_tree.gd` passes
- [ ] `verify_upgrade_effects.gd` passes
- [ ] `verify_pickup.gd` passes
- [ ] Headless smoke passes

## v3.1 — Milestones UI

- [ ] Lifetime earnings tracked in save (already in model)
- [ ] HUD or panel shows **next milestone** with $ remaining
- [ ] At least one milestone unlock fires in playtest (cosmetic or feature flag OK)

## v3.2 — First crew hire

- [ ] `$250k` lifetime gate (tunable) unlocks crew purchase
- [ ] `passive_swings_per_second > 0` after hire
- [ ] Passive income uses pickup formula at reduced efficiency
- [ ] Active play still dominant in first hour after hire

## v3.3 — Range amenities (optional)

- [ ] At least one visible prop change tied to milestone or shop purchase
- [ ] Passive or pickup bonus documented in economy doc

## Related docs

- [v3/README.md](../README.md)
- [findings/economy-progression-findings.md](../findings/economy-progression-findings.md)
