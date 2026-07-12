# v7 Currencies & Save

## Currencies

| Currency | Used where | Earned how | Spent how |
|----------|------------|------------|-----------|
| **Cash** (`GameState.currency`) | Play tree, HUD | Ball pickup (unchanged) | Play upgrades; **consumed entirely on prestige** |
| **Cheese** | Prestige tab only | Prestige payout | Prestige tree nodes only |

HUD (main game): continue showing **cash** as today.  
Prestige tab header: show **cheese** (not cash) + **prestige #**.

## Prestige count

- `prestige_count: int` — increments by 1 each successful prestige.
- Display on Prestige tab top bar (e.g. `Prestige #3`).
- May later feed formulas; v7 only requires display + save.

## GameState fields (contract — freeze in Workstream 0)

Add (names may match implementation style):

| Field | Type | Purpose |
|-------|------|---------|
| `cheese` | float or int | Spendable prestige currency |
| `prestige_count` | int | Times prestiged |
| `prestige_threshold` | float | Current cash-on-hand requirement (default 5000; Ambition mutates) |
| `prestige_levels` | Dictionary | `upgrade_id → level` for cheese tree |
| Cheese-derived runtime flags | via effects apply | e.g. combo unlocked, quick reset stacks, perfect streak rules |

Signals (suggested):

- `EventBus.cheese_changed(amount)`
- `EventBus.prestiged(prestige_count, cheese_gained)`
- Existing upgrade signals reused or namespaced for prestige purchases

## Save / load

Extend `SaveManager` payload:

- Persist `cheese`, `prestige_count`, `prestige_threshold`, `prestige_levels`
- On load: re-apply prestige effects to stats **before** Play levels (or compose clearly: defaults → prestige effects → play effects)
- Migration: missing keys → cheese 0, prestige_count 0, threshold 5000, empty levels
- Old saves with Ratina/Rattling/combo/quick_reset on play tree: strip or ignore removed ids; do not soft-lock

## Composition order for stats

```text
Balance.default_stats()
  → apply prestige (cheese) effects
  → apply play (cash) upgrade effects
  → apply shop effects still in play (if any remain)
```

Document the exact apply path in code comments next to `GameState.recompute_stats` (or equivalent).
