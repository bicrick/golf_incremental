# v7 Workstreams — Parallel Agents

Freeze **Workstream 0** contracts before splitting. Agents must not edit files outside their stream without updating this doc.

## Workstream 0 — Contracts (do first, solo or tiny PR)

**Owner:** one agent / human.

| Deliverable | Location (suggested) |
|-------------|----------------------|
| `cheese`, `prestige_count`, `prestige_threshold`, `prestige_levels` on `GameState` | `scripts/autoload/game_state.gd` |
| Prestige + cheese signals | `scripts/autoload/event_bus.gd` |
| Save migration | `scripts/autoload/save_manager.gd` |
| Balance constants (threshold 5000, surplus curve, cheese press base) | `scripts/config/balance.gd` |
| `prestige()` API: validate cash, grant cheese, wipe play progress, keep cheese tree, recompute stats | `game_state.gd` |
| Stat compose order documented | defaults → prestige effects → play effects |

**Exit:** headless smoke; save/load round-trip with cheese fields; can call `prestige()` from a verify script or debugger.

---

## Workstream A — Prestige definitions & effects

**Depends on:** Workstream 0.

| Task | Files (suggested) |
|------|-------------------|
| Prestige upgrade definitions (ids from [04-cheese-tree.md](04-cheese-tree.md)) | `scripts/game/prestige/definitions.gd` (new) |
| Apply effects to `PlayerStats` / threshold | `scripts/game/prestige/effects.gd` (new) |
| Purchase API with cheese | `game_state.gd` or prestige graph helper |
| Perfect Chain streak tracking on swing resolve | `swing.gd` / `range_view.gd` + GameState flags |
| Wire golden-while-streak | tee prep path in `range_view.gd` |

**Do not edit:** upgrade panel layout (Workstream C), Play tree removals beyond what’s needed for effects hooks (coord with B).

**Exit:** `verify_prestige.gd` (new) — purchase cheese nodes, threshold changes, perfect chain goldens in headless or scripted checks where possible.

---

## Workstream B — Play tree trim & pace

**Depends on:** Workstream 0 (soft); can parallel A after contracts.

| Task | Files |
|------|-------|
| Remove `quick_reset`, `combo_bonus` from Play defs | `scripts/game/upgrades/definitions.gd` |
| Hide Ratina hire + rattling from graph / UI reveal | `graph.gd`, shop/ratina/rattling registration |
| Bucket default 6; capacity from cheese Deep Bucket only | `balance.gd`, shop `ball_count` handling |
| Golden chance from cheese (and/or strip shop golden) | `shop/definitions.gd`, prestige effects |
| Faster early costs / income toward 5k | `definitions.gd`, `balance.gd` |
| Ensure dormant crew doesn’t spawn | `ratina_controller.gd` / `rattling_controller.gd` gates |

**Exit:** Play tree has no combo/quick reset/Ratina/Rattlings; fresh save can earn toward 5k meaningfully faster; `verify_upgrade_tree` / `verify_upgrade_effects` updated.

---

## Workstream C — Upgrade menu UI

**Depends on:** Workstream 0; needs A’s defs for cheese nodes to render.

| Task | Files |
|------|-------|
| Play / Prestige tabs | `upgrade_panel.gd` + scene |
| Prestige tab: cheese in top-right, prestige # | same |
| Prestige button bottom-right: grey / active + tooltips + confirm | same |
| Bind cheese graph + purchase | panel + prestige graph |
| Tab-local currency display | panel / HUD helpers |

**Exit:** `verify` or manual checklist in [specs/v7-acceptance.md](specs/v7-acceptance.md); headless smoke still green.

---

## Parallelism diagram

```text
        [0 Contracts]
         /         \
      [A Prestige] [B Play trim + pace]
         \         /
        [C Prestige UI]  (needs A defs; B can merge first)
```

## Conflict zones

| Shared file | Rule |
|-------------|------|
| `game_state.gd` | Only 0 adds fields/API; A/B add narrow purchase/apply hooks via review or sequential commits |
| `event_bus.gd` | Only 0 adds signals unless pre-declared in 0 |
| `upgrade_panel.gd` | C owns |
| `definitions.gd` (play) | B owns |
| `balance.gd` | 0 seeds constants; B/A append with clear section comments |

## Out of scope for all v7 streams

Landlord, consumables, Ratina/Rattling *redesign*, primers, whistle, v4 bay placement.
