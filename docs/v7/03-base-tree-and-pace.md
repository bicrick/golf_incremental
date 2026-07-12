# v7 Base (Play) Tree & Pace

## Role of the Play tree

Cash upgrades = **honest climb**: stronger payouts, farther carries, cleaner contact. Not the home of broken tempo / harvest multipliers.

## Keep on Play tree (cash)

| ID | Name | Role |
|----|------|------|
| `base_pay` | Base Pay | Flat $/ball |
| `distance_pay` | Yardage Pay | $/yard |
| `iron_set` | Raw Power | Base yards |
| `quality` | Sweet Spot | Contact → distance |
| `metronome` | Metronome | Timing windows |
| `perfect_pop` | Perfect Pop | Near-perfect distance mult |
| `pickup` | Pickup | Pickup multiplier |
| `range_picker` | Range Picker | Harvest QoL (keep — not OP) |

Shop items that remain cash (if still separate): tune **More Balls / Golden** — see removals below.

## Remove from Play tree (move to cheese or hide)

| ID / system | Action |
|-------------|--------|
| `quick_reset` | **Remove** from Play defs; cheese tree only |
| `combo_bonus` | **Remove** from Play defs; cheese tree only |
| `ball_count` / More Balls | **Remove** from free shop climb **or** gate: only available after cheese **Deep Bucket** unlocks the right to buy — **preferred v7:** capacity stays **6** on Play; **Deep Bucket** on cheese raises permanent capacity / max |
| `golden_ball` | Strong stacking → cheese **Golden Tee** for permanent rate; optional weak shop remnant — **preferred:** golden chance from cheese (+ maybe tiny base 0) |
| `ratina_hire` + Ratina subtree | **Hide** from UI / graph; no purchase on Play tree |
| Rattling namespace | **Hide** from UI / graph; controllers dormant |

Default bucket capacity remains **6** unless cheese Deep Bucket says otherwise.

## Combo / Quick Reset behavior when locked

- Combo multiplier stays **0** until cheese **Combo Hands** purchased.
- Swing cooldown stays at default until cheese **Quick Reset** purchased.
- Do not leave orphan nodes visible on the Play graph.

## Pace: reach $500 faster

Goal: a focused run can hit prestige threshold **without** grinding the deep tree.

Tune in `Balance` / upgrade `base_cost` / `growth_rate` / early `base_amount` (document final numbers in PR):

| Lever | Direction |
|-------|-----------|
| Early Base Pay / Yardage costs | Cheaper or slower growth |
| Starting `base_amount` | Slightly higher if needed |
| Early yardage unlock | Reachable quickly |
| Deep max levels | Can stay deep for long-tail *after* multiple prestiges |

**Acceptance pace (soft):** competent play reaches $500 on hand quickly on a fresh save with no cheese OP — exact target TBD in playtest, but “way under 45 minutes” is mandatory.

## Graph / UI

- Play tab shows only Play nodes (and remaining shop nodes if any).
- Prestige tab shows only cheese tree + prestige button.
- Existing `UpgradeGraph` may gain a tab filter or a second graph instance — see [05-ui.md](05-ui.md) and [06-workstreams.md](06-workstreams.md).
