# v4 Economy and Progression

## Design ideal

### No new economic mechanic

v4 does not introduce a new currency, resource, or income type. Hitting balls (active, contact-timing) remains the primary earner. Passive income continues to come from exactly the sources it already comes from in v2/v3:

- Character/club upgrades (existing upgrade tree)
- Hiring crew (Ratina and, in v4, additional crew hired into bay slots)
- Buying more balls / bucket capacity for the range

v4's contribution is **physical**: "hiring crew" changes from "buy an upgrade-tree node, layout is hardcoded" to "buy a bay slot, then click an empty grid cell to place it." The money math underneath (crew payout scaling, cost curves) does not change in kind — it changes in *presentation and gating structure*.

### Bay slots as a new gate, not a new curve

Where v3's crew unlocks were gated purely by lifetime-earnings milestones (`docs/v3/02-long-tail-content.md`: "$250k lifetime → first rat friend"), v4 adds a **physical slot** as a second gate alongside the existing cost:

1. Unlock the bay *slot* itself (may be the same lifetime-earnings milestone as today, or a separate small unlock cost — decide during balance pass, don't invent a new curve shape).
2. Place a crew member into that slot (existing per-crew-member cost/upgrade curve, e.g. Ratina's Base Pay / Power / Quality / Frequency tree, unchanged).

This preserves v3's balance work (`docs/v3/findings/economy-progression-findings.md`) — the *existing* cost/effect curves for crew still apply once a crew member is placed; v4 just adds "where" on top of "how much."

### Numbers to fill in during implementation, not invented here

Per [00-vision.md](00-vision.md#open-design-questions-tracked-not-yet-resolved), exact slot count (3–6 planning target) and slot unlock costs are **not** finalized in this doc — they should be derived using the same payback-period methodology as `docs/v3/findings/economy-progression-findings.md`, not guessed fresh. Treat additional bay slots as another entry in that findings doc's milestone table (`docs/v3/02-long-tail-content.md`'s milestone list), not a parallel balance system.

## Implementation against current code

### What exists today

- `GameState.ratina_unlocked: bool` (`scripts/autoload/game_state.gd:8`) is the entire "crew slot" model today — a single boolean, one hardcoded crew member, no concept of multiple slots.
- Ratina's own progression (Base Pay / Power / Quality / Frequency) lives in `scripts/game/ratina/definitions.gd`, merged into the unified radial upgrade tree via `scripts/game/upgrades/graph.gd`. Ratina hire is `ratina_hire` on the player tree (Base Pay Lv.3, $100).
- `SaveManager` persists `ratina_unlocked` directly (`scripts/autoload/save_manager.gd:44,120`) — a flat field, not a collection.
- Milestone/gate numbers live in `docs/v3/02-long-tail-content.md` and the underlying findings doc — this is the authoritative place for cost-curve methodology; v4 should extend it, not replace it.

### Suggested approach

1. Generalize `ratina_unlocked: bool` into a small collection (e.g. `hired_bays: Array` or a dictionary keyed by cell index) as described in [03-crew-and-bays.md](03-crew-and-bays.md) — Ratina's existing unlock becomes the first entry, migrated via `SaveManager` (needs a save-version bump / migration path for existing save files, not just a schema change).
2. Add a slot-unlock cost value per additional bay to `Balance`/`Economy`, following the same authoring pattern as existing upgrade costs (`scripts/game/upgrades/definitions.gd`) — do not hardcode costs inside UI or placement-controller code.
3. Reuse `EventBus.ratina_upgrade_purchased`-style signals, generalized to carry a bay/slot identifier, so the upgrade panel and placement UI both react to "a crew member's stats changed" without bay-specific signal names proliferating.
4. When the balance pass happens, run it through the same simulation/validation approach referenced in `docs/v3/findings/economy-progression-findings.md` rather than hand-picking numbers — this keeps v4's new gate consistent with the rest of the payback-period-driven curve work.

## Related docs

- v3 economy findings (methodology to reuse): [../v3/findings/economy-progression-findings.md](../v3/findings/economy-progression-findings.md)
- v3 long-tail milestones (extend, don't replace): [../v3/02-long-tail-content.md](../v3/02-long-tail-content.md)
- Crew/bay entity model: [03-crew-and-bays.md](03-crew-and-bays.md)
