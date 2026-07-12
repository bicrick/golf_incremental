# Golf Incremental — v7 Design

**Design source of truth for prestige / cheese.** Strike → harvest → cash upgrades stay the core loop. v7 adds an early prestige at **$5,000 on hand**, a **cheese** currency, and a **separate Prestige tab** in the upgrade menu with OP perks. Landlord days, dual shop restructure, and field consumables are **out of scope** (parked for a later version).

## One-liner

Same driving-range incremental — but you can cash out a run early for **cheese**, reset the normal tree, and spend cheese on **game-changing prestige perks** so the next climb to 5k is faster and weirder.

## Relationship to prior versions

| Prior (foundation) | v7 (this doc set) |
|---|---|
| Continuous cash climb; no prestige | Prestige at $5k on hand → cheese → reset normal progress |
| One upgrade tree (cash) | **Play** tab (cash tree) + **Prestige** tab (cheese tree) |
| Quick Reset, Combo, More Balls, Ratina, Rattlings on/near main tree | OP toys move to cheese (or are hidden pending rework) |
| ~45 min toward deep distance | Faster early economy so 5k is reachable without maxing the tree |
| v4 camera / bay placement | Untouched — not part of v7 |

**Explicit non-goals (v7):** landlord / day-night dues, field consumables, vacuum, Caddy’s Whistle, primers, Ratina/Rattling rework (hide only), dual “shop vs identity” restructure.

## Doc map

| Doc | Read if you are working on… |
|-----|----------------------------|
| [00-vision.md](00-vision.md) | Pillars, scope, what v7 is / isn’t |
| [01-prestige-loop.md](01-prestige-loop.md) | $5k gate, reset rules, cheese payout |
| [02-currencies-and-save.md](02-currencies-and-save.md) | Cheese, prestige count, save schema |
| [03-base-tree-and-pace.md](03-base-tree-and-pace.md) | What stays on cash tree, removals, faster 5k |
| [04-cheese-tree.md](04-cheese-tree.md) | Prestige OP skill tree nodes |
| [05-ui.md](05-ui.md) | Upgrade menu tabs, prestige button, cheese header |
| [06-workstreams.md](06-workstreams.md) | Parallel agent splits and file ownership |
| [specs/v7-acceptance.md](specs/v7-acceptance.md) | Testable done criteria |
| [Implementation plan](../superpowers/plans/2026-07-12-v7-prestige-cheese.md) | Task-by-task build order (Parts 0–4) |

## Reading order

1. [00-vision.md](00-vision.md)
2. [01-prestige-loop.md](01-prestige-loop.md)
3. [03-base-tree-and-pace.md](03-base-tree-and-pace.md)
4. [04-cheese-tree.md](04-cheese-tree.md)
5. [05-ui.md](05-ui.md)
6. [02-currencies-and-save.md](02-currencies-and-save.md)
7. [06-workstreams.md](06-workstreams.md) before parallel implementation
8. [specs/v7-acceptance.md](specs/v7-acceptance.md) before calling v7 done

## Agent rules (v7 additions)

1. **Core loop unchanged** — strike / harvest / contact swing stay; v7 is progression + UI + economy gating.
2. **Two currencies, two tabs** — cash only on Play tree; cheese only on Prestige tab.
3. **Data-driven prestige defs** — new definitions under `scripts/game/prestige/` (or similar), not hardcoded in scenes.
4. **Hide crew, don’t delete yet** — Ratina / Rattlings removed from player-facing base tree; controllers may remain dormant for a later rework.
5. **Contract-first** — freeze `GameState` / `EventBus` / save fields in Workstream 0 before UI and tree agents split; see [06-workstreams.md](06-workstreams.md).
6. **Verify** — headless smoke + any new `verify_prestige` / existing upgrade verifies after changes.
