# v7 Prestige / Cheese — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship early prestige at $5k cash on hand, cheese currency, a Prestige tab with OP cheese tree, and a trimmed faster Play tree — per [`docs/v7/`](../../v7/README.md).

**Architecture:** Extend `GameState` with cheese + prestige fields and a `prestige()` API. New `scripts/game/prestige/` mirrors cash upgrade defs/effects. Play tree drops OP/crew nodes; cheese tree owns them. Upgrade panel gains Play/Prestige tabs; Prestige tab shows cheese, prestige #, and a grey/active Prestige button.

**Tech Stack:** Godot 4.x, GDScript, existing `UpgradeDefinitions` / `UpgradeEffects` / `UpgradeGraph` / `upgrade_panel.gd` patterns, headless `tools/verify_*.gd`.

**Design source of truth:** [`docs/v7/README.md`](../../v7/README.md) · Acceptance: [`docs/v7/specs/v7-acceptance.md`](../../v7/specs/v7-acceptance.md) · Workstreams: [`docs/v7/06-workstreams.md`](../../v7/06-workstreams.md)

**Godot binary:**

```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
cd /Users/pbrown/Desktop/golf_incremental
```

Always smoke after each part:

```bash
$GODOT --headless --path . --quit-after 2
```

---

## File map

| File | Responsibility |
|------|----------------|
| `scripts/config/balance.gd` | Prestige constants; `SAVE_VERSION` bump; pace tweaks |
| `scripts/autoload/event_bus.gd` | `cheese_changed`, `prestiged`, `prestige_upgrade_purchased` |
| `scripts/autoload/game_state.gd` | Cheese state, `prestige()`, purchase cheese, recompute order, Perfect streak |
| `scripts/autoload/save_manager.gd` | Persist + migrate prestige fields; strip removed play ids |
| `scripts/game/prestige/definitions.gd` | **New** — cheese tree defs |
| `scripts/game/prestige/effects.gd` | **New** — apply cheese levels → stats / threshold |
| `scripts/game/prestige/graph.gd` | **New** (optional) — parent/prereq helpers for UI |
| `scripts/game/upgrades/definitions.gd` | Remove `quick_reset`, `combo_bonus`, `ratina_hire` |
| `scripts/game/upgrades/graph.gd` | Stop registering Ratina/Rattling/shop ball+golden (or filter) |
| `scripts/game/shop/definitions.gd` | Remove or empty `ball_count` / `golden_ball` from Play economy |
| `scripts/ui/upgrade_panel.gd` + scene | Tabs, cheese header, prestige button |
| `scripts/range/range_view.gd` | Perfect Chain golden at tee prep |
| `tools/verify_prestige.gd` | **New** — headless prestige checks |
| `tools/verify_upgrade_*.gd` | Drop removed ids from cases |

---

## Part order

```text
Part 0  Contracts (GameState / EventBus / save / prestige API)
  ├─ Part 1  Cheese tree defs + effects + purchase + Perfect Chain
  ├─ Part 2  Play tree trim + pace + hide crew  (parallel with Part 1 after 0)
  └─ Part 3  Upgrade menu UI (needs Part 1 defs)
Part 4  Acceptance pass + verify scripts
```

Do **not** start Part 1/2 until Part 0 is merged. Part 3 needs Part 1. Part 2 can merge before Part 3.

---

# Part 0 — Contracts

**Owner:** single agent. **Spec:** [02-currencies-and-save](../../v7/02-currencies-and-save.md), [01-prestige-loop](../../v7/01-prestige-loop.md)

### Task 0.1: Balance constants + save version

**Files:**
- Modify: `scripts/config/balance.gd`

- [ ] **Step 1: Add a `## v7 Prestige` section**

```gdscript
## v7 Prestige
const SAVE_VERSION: int = 4  # was 3 — bump when prestige fields land
const PRESTIGE_THRESHOLD_DEFAULT: float = 5000.0
const PRESTIGE_CHEESE_BASE: float = 1.0
const PRESTIGE_SURPLUS_PER_CHEESE: float = 2500.0
## Ambition level → threshold (index 0 unused; level 0 = default threshold)
const PRESTIGE_AMBITION_THRESHOLDS: Array[float] = [
	5000.0, 10000.0, 20000.0, 40000.0, 80000.0, 160000.0,
]
```

Keep existing `SAVE_VERSION` replacement in place (one const only).

- [ ] **Step 2: Commit**

```bash
git add scripts/config/balance.gd
git commit -m "$(cat <<'EOF'
Add v7 prestige balance constants and bump save version.

EOF
)"
```

### Task 0.2: EventBus signals

**Files:**
- Modify: `scripts/autoload/event_bus.gd`

- [ ] **Step 1: Append signals**

```gdscript
signal cheese_changed(cheese: float)
signal prestiged(prestige_count: int, cheese_gained: float)
signal prestige_upgrade_purchased(id: String, level: int)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/autoload/event_bus.gd
git commit -m "$(cat <<'EOF'
Add EventBus signals for cheese and prestige.

EOF
)"
```

### Task 0.3: GameState prestige fields + recompute order

**Files:**
- Modify: `scripts/autoload/game_state.gd`

- [ ] **Step 1: Add fields after existing level dicts**

```gdscript
var cheese: float = 0.0
var prestige_count: int = 0
var prestige_threshold: float = Balance.PRESTIGE_THRESHOLD_DEFAULT
var prestige_levels: Dictionary = {}
## Perfect Chain: consecutive Perfect swing count this life (runtime; optional to save)
var perfect_swing_streak: int = 0
```

- [ ] **Step 2: Change `_recompute_stats` compose order**

```gdscript
func _recompute_stats() -> void:
	stats = Balance.default_stats()
	# defaults → prestige → play → shop (crew dormant in v7 but keep apply harmless)
	PrestigeEffects.apply_all(stats, prestige_levels)  # stub in 0.3 if Part 1 not merged: no-op class
	UpgradeEffects.apply_all(stats, upgrade_levels)
	ShopEffects.apply_all(stats, shop_levels)
	ratina_stats = Balance.default_ratina_stats()
	RatinaUpgradeEffects.apply_all(ratina_stats, ratina_upgrade_levels)
	rattling_stats = Balance.default_rattling_stats()
	RattlingUpgradeEffects.apply_all(rattling_stats, rattling_upgrade_levels)
	_apply_ambition_threshold()
	bucket_capacity = get_bucket_capacity()
```

**Part 0 stub:** If `PrestigeEffects` does not exist yet, add a minimal stub:

Create `scripts/game/prestige/effects.gd`:

```gdscript
class_name PrestigeEffects
extends RefCounted

static func apply_all(_stats: PlayerStats, _levels: Dictionary) -> void:
	pass
```

Ambition threshold helper:

```gdscript
func _apply_ambition_threshold() -> void:
	var ambition: int = int(prestige_levels.get("ambition", 0))
	var idx: int = mini(ambition, Balance.PRESTIGE_AMBITION_THRESHOLDS.size() - 1)
	prestige_threshold = Balance.PRESTIGE_AMBITION_THRESHOLDS[idx]
```

- [ ] **Step 3: Smoke**

```bash
$GODOT --headless --path . --quit-after 2
```

Expected: exit 0 (fix parse errors if stub missing from autoload path — ensure script exists).

- [ ] **Step 4: Commit**

```bash
git add scripts/autoload/game_state.gd scripts/game/prestige/effects.gd
git commit -m "$(cat <<'EOF'
Add GameState cheese fields and prestige-aware stat recompute stub.

EOF
)"
```

### Task 0.4: `prestige()` API + cheese helpers

**Files:**
- Modify: `scripts/autoload/game_state.gd`

- [ ] **Step 1: Implement helpers**

```gdscript
func can_prestige() -> bool:
	return currency >= prestige_threshold


func cheese_from_prestige_cash(cash_on_hand: float) -> float:
	var base: float = Balance.PRESTIGE_CHEESE_BASE + float(prestige_levels.get("cheese_press", 0))
	# Ambition also bumps base: +1 cheese per ambition level (tunable)
	base += float(prestige_levels.get("ambition", 0))
	var surplus: float = maxf(0.0, cash_on_hand - prestige_threshold)
	var surplus_cheese: float = floorf(surplus / Balance.PRESTIGE_SURPLUS_PER_CHEESE)
	return base + surplus_cheese


func add_cheese(amount: float) -> void:
	if amount == 0.0:
		return
	cheese += amount
	EventBus.cheese_changed.emit(cheese)


func prestige() -> bool:
	if not can_prestige():
		return false
	var cash_before: float = currency
	var gained: float = cheese_from_prestige_cash(cash_before)
	# Wipe run (Play) progress — keep cheese tree + lifetime optional
	currency = 0.0
	upgrade_levels.clear()
	shop_levels.clear()
	ratina_upgrade_levels.clear()
	rattling_upgrade_levels.clear()
	ratina_unlocked = false
	rattlings_unlocked = false
	ratina_active = true
	rattlings_active = true
	upgrades_unlocked = true  # keep menu unlocked after first unlock this life? Spec: wipe play — prefer keep upgrades_unlocked if already true
	perfect_swing_streak = 0
	current_phase = "strike"
	harvest_collected = 0
	harvest_stash = 0
	pending_vanish_collects = 0
	add_cheese(gained)
	prestige_count += 1
	_recompute_stats()
	bucket_remaining = bucket_capacity
	EventBus.prestiged.emit(prestige_count, gained)
	EventBus.currency_changed.emit(currency)
	EventBus.stats_changed.emit(stats, currency)
	EventBus.bucket_changed.emit(_bucket_display_count(), bucket_capacity)
	EventBus.phase_changed.emit("strike")
	return true
```

**Note:** Spec says wipe Play upgrades; keeping `upgrades_unlocked = true` after first unlock is a QoL choice — document in commit. Do **not** clear `prestige_levels` or `cheese` (except via `add_cheese`).

- [ ] **Step 2: Commit**

```bash
git add scripts/autoload/game_state.gd
git commit -m "$(cat <<'EOF'
Implement GameState.prestige() cash-out and cheese grant.

EOF
)"
```

### Task 0.5: Save / load migration

**Files:**
- Modify: `scripts/autoload/save_manager.gd`

- [ ] **Step 1: Write prestige fields in `save_game`**

```gdscript
"cheese": GameState.cheese,
"prestige_count": GameState.prestige_count,
"prestige_threshold": GameState.prestige_threshold,
"prestige_levels": GameState.prestige_levels.duplicate(),
```

- [ ] **Step 2: Read with defaults in `load_game`**

```gdscript
GameState.cheese = float(data.get("cheese", 0.0))
GameState.prestige_count = int(data.get("prestige_count", 0))
GameState.prestige_levels = data.get("prestige_levels", {}).duplicate()
if typeof(GameState.prestige_levels) != TYPE_DICTIONARY:
	GameState.prestige_levels = {}
# threshold recomputed in _recompute_stats via Ambition
```

- [ ] **Step 3: On migrate from save v3 → v4, strip removed play ids if present**

```gdscript
for stale_id in ["quick_reset", "combo_bonus", "ratina_hire"]:
	GameState.upgrade_levels.erase(stale_id)
# shop
GameState.shop_levels.erase("ball_count")
GameState.shop_levels.erase("golden_ball")
```

(Full refund optional; v7 prefers erase — early prestige game.)

- [ ] **Step 4: Smoke + commit**

```bash
$GODOT --headless --path . --quit-after 2
git add scripts/autoload/save_manager.gd
git commit -m "$(cat <<'EOF'
Persist cheese prestige fields and migrate stale play upgrades.

EOF
)"
```

### Task 0.6: Headless verify stub for prestige API

**Files:**
- Create: `tools/verify_prestige.gd`

- [ ] **Step 1: Write verify script**

```gdscript
extends SceneTree
## godot --headless --script res://tools/verify_prestige.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.currency = 4999.0
	if gs.prestige():
		print("FAIL: prestige allowed under threshold")
		quit(1)
		return
	gs.currency = 5000.0
	gs.upgrade_levels = {"base_pay": 3}
	if not gs.prestige():
		print("FAIL: prestige denied at threshold")
		quit(1)
		return
	if gs.currency != 0.0:
		print("FAIL: cash not wiped")
		quit(1)
		return
	if gs.get_upgrade_level("base_pay") != 0:
		print("FAIL: play upgrades not wiped")
		quit(1)
		return
	if gs.cheese < 1.0:
		print("FAIL: expected cheese >= 1")
		quit(1)
		return
	if gs.prestige_count < 1:
		print("FAIL: prestige_count")
		quit(1)
		return
	print("OK verify_prestige Part 0")
	quit(0)
```

- [ ] **Step 2: Run**

```bash
$GODOT --headless --path . --script res://tools/verify_prestige.gd
```

Expected: `OK verify_prestige Part 0`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add tools/verify_prestige.gd
git commit -m "$(cat <<'EOF'
Add headless verify_prestige for cash-out API.

EOF
)"
```

**Part 0 exit:** contracts frozen; `prestige()` works; save fields exist; smoke green.

---

# Part 1 — Cheese tree (Workstream A)

**Depends on:** Part 0. **Spec:** [04-cheese-tree](../../v7/04-cheese-tree.md)

### Task 1.1: Prestige definitions

**Files:**
- Create: `scripts/game/prestige/definitions.gd`

- [ ] **Step 1: Mirror `UpgradeDefinitions` pattern** with ids:

| id | name | parent | notes |
|----|------|--------|-------|
| `cheese_press` | Cheese Press | (root) | +1 base cheese / level |
| `ambition` | Ambition | `cheese_press` | threshold table |
| `prestige_quick_reset` | Quick Reset | `cheese_press` | ×0.85 cooldown / level, max 5 |
| `prestige_combo` | Combo Hands | `cheese_press` | +0.08 combo_mult_per_tier / level, max 5 |
| `prestige_deep_bucket` | Deep Bucket | `cheese_press` | +1 bucket_capacity_bonus / level, max 4 |
| `prestige_golden_tee` | Golden Tee | `cheese_press` | +0.02 golden_ball_chance / level, max 10 |
| `prestige_perfect_chain` | Perfect Chain | `cheese_press` | binary unlock, max 1 |

Include `base_cost`, `growth_rate`, `effects` arrays like play defs. Cheese Press `base_cost` ≈ 1, growth mild.

- [ ] **Step 2: Commit**

```bash
git add scripts/game/prestige/definitions.gd
git commit -m "$(cat <<'EOF'
Add prestige cheese upgrade definitions.

EOF
)"
```

### Task 1.2: Prestige effects (replace stub)

**Files:**
- Modify: `scripts/game/prestige/effects.gd`

- [ ] **Step 1: Implement `apply_all`**

Reuse multiply/add/binary patterns from `UpgradeEffects` (copy helpers or call shared util — prefer duplicate small helpers in this file for isolation).

Map:

- `cheese_press` — no PlayerStats change (payout reads level in `cheese_from_prestige_cash`)
- `ambition` — threshold via GameState `_apply_ambition_threshold`
- `prestige_quick_reset` — multiply `swing_cooldown_ms` by `pow(0.85, level)`
- `prestige_combo` — add `combo_mult_per_tier` += `0.08 * level` (0 if level 0)
- `prestige_deep_bucket` — add `bucket_capacity_bonus` += level
- `prestige_golden_tee` — add `golden_ball_chance` += `0.02 * level`
- `prestige_perfect_chain` — set a flag on stats or GameState: `stats.perfect_chain_unlocked = 1.0` (add field on `PlayerStats` if missing)

- [ ] **Step 2: Add `perfect_chain_unlocked` on `PlayerStats` if needed** (`scripts/game/player_stats.gd` + `Balance.default_stats`)

- [ ] **Step 3: Commit**

```bash
git add scripts/game/prestige/effects.gd scripts/game/player_stats.gd scripts/config/balance.gd
git commit -m "$(cat <<'EOF'
Apply cheese prestige effects to player stats.

EOF
)"
```

### Task 1.3: Purchase prestige upgrade with cheese

**Files:**
- Modify: `scripts/autoload/game_state.gd`

- [ ] **Step 1: Add API**

```gdscript
func get_prestige_upgrade_level(id: String) -> int:
	return int(prestige_levels.get(id, 0))


func get_prestige_upgrade_cost(id: String) -> float:
	var def: Dictionary = PrestigeDefinitions.get_def(id)
	if def.is_empty():
		return 0.0
	return Economy.upgrade_cost(float(def["base_cost"]), float(def["growth_rate"]), get_prestige_upgrade_level(id))


func purchase_prestige_upgrade(id: String) -> bool:
	var def: Dictionary = PrestigeDefinitions.get_def(id)
	if def.is_empty():
		return false
	var level: int = get_prestige_upgrade_level(id)
	if level >= int(def["max_level"]):
		return false
	# prereq: parent level >= 1 if parent_id set (except root)
	var parent_id: String = str(def.get("parent_id", ""))
	if not parent_id.is_empty() and get_prestige_upgrade_level(parent_id) < 1:
		return false
	var prereq: Dictionary = def.get("prerequisite", {})
	if not prereq.is_empty():
		var req_id: String = str(prereq.get("upgrade_id", ""))
		var req_lv: int = int(prereq.get("level", 1))
		if get_prestige_upgrade_level(req_id) < req_lv:
			return false
	var cost: float = get_prestige_upgrade_cost(id)
	if cheese < cost:
		return false
	cheese -= cost
	prestige_levels[id] = level + 1
	_recompute_stats()
	EventBus.prestige_upgrade_purchased.emit(id, level + 1)
	EventBus.cheese_changed.emit(cheese)
	EventBus.stats_changed.emit(stats, currency)
	EventBus.bucket_changed.emit(_bucket_display_count(), bucket_capacity)
	return true
```

Preload `PrestigeDefinitions` at top of `game_state.gd` like other defs.

- [ ] **Step 2: Extend `verify_prestige.gd`** — give cheese, buy `cheese_press`, assert level 1 and cheese decreased.

- [ ] **Step 3: Run verify + commit**

```bash
$GODOT --headless --path . --script res://tools/verify_prestige.gd
git add scripts/autoload/game_state.gd tools/verify_prestige.gd
git commit -m "$(cat <<'EOF'
Allow purchasing prestige upgrades with cheese.

EOF
)"
```

### Task 1.4: Perfect Chain runtime

**Files:**
- Modify: `scripts/autoload/game_state.gd` (streak helpers)
- Modify: swing resolve path — find where Perfect tier is known (likely `range_view.gd` / `swing.gd` after resolve)
- Modify: `scripts/range/range_view.gd` tee golden roll (`golden_ball_chance` ~line 1083)

- [ ] **Step 1: Streak API**

```gdscript
func note_swing_tier(tier: int) -> void:
	if int(stats.perfect_chain_unlocked) < 1:
		perfect_swing_streak = 0
		return
	if tier == Balance.TimingTier.PERFECT:
		perfect_swing_streak += 1
	else:
		perfect_swing_streak = 0


func is_perfect_chain_golden_active() -> bool:
	return int(stats.perfect_chain_unlocked) >= 1 and perfect_swing_streak >= 3
```

- [ ] **Step 2: Call `note_swing_tier` on player swing resolve** (not Ratina).

- [ ] **Step 3: In tee golden roll**, if `is_perfect_chain_golden_active()` → force golden `true` (still allow normal chance otherwise).

- [ ] **Step 4: On `prestige()`, reset `perfect_swing_streak = 0`** (already in Part 0).

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/game_state.gd scripts/range/range_view.gd scripts/game/swing.gd
git commit -m "$(cat <<'EOF'
Force golden balls during Perfect Chain streaks.

EOF
)"
```

**Part 1 exit:** all cheese nodes purchasable; effects apply across prestige; Perfect Chain works.

---

# Part 2 — Play tree trim & pace (Workstream B)

**Depends on:** Part 0 (soft). **Can parallel Part 1.** **Spec:** [03-base-tree-and-pace](../../v7/03-base-tree-and-pace.md)

### Task 2.1: Remove OP nodes from Play definitions

**Files:**
- Modify: `scripts/game/upgrades/definitions.gd` — delete `quick_reset`, `combo_bonus`, `ratina_hire` entries
- Modify: `tools/verify_upgrade_effects.gd` / `tools/verify_upgrade_tree.gd` — remove those ids from cases; fix any graph assumptions

- [ ] **Step 1: Remove defs**
- [ ] **Step 2: Run**

```bash
$GODOT --headless --path . --script res://tools/verify_upgrade_tree.gd
$GODOT --headless --path . --script res://tools/verify_upgrade_effects.gd
```

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
Remove Quick Reset, Combo, and Ratina hire from the Play tree.

EOF
)"
```

### Task 2.2: Hide shop balls/golden + crew from graph

**Files:**
- Modify: `scripts/game/upgrades/graph.gd` — stop registering `NAMESPACE_RATINA`, `NAMESPACE_RATTLING`, and shop `ball_count` / `golden_ball` (either skip in `_init_graph` or empty shop defs)
- Modify: `scripts/game/shop/definitions.gd` — remove both items or leave unused
- Modify: `scripts/range/ratina_controller.gd` / `rattling_controller.gd` — early-out if not unlocked (already false)

- [ ] **Step 1: Graph no longer exposes crew/shop capacity/golden**
- [ ] **Step 2: Ensure `UpgradePanel` doesn’t error on missing namespaces**
- [ ] **Step 3: Smoke + commit**

```bash
$GODOT --headless --path . --quit-after 2
git commit -m "$(cat <<'EOF'
Hide Ratina, Rattlings, and shop ball/golden from the Play graph.

EOF
)"
```

### Task 2.3: Default capacity 6; golden from cheese only

**Files:**
- Confirm `Balance.BUCKET_CAPACITY_DEFAULT == 6`
- `get_bucket_capacity()` already uses `bucket_capacity_bonus` from Deep Bucket cheese
- Ensure base `golden_ball_chance` is 0 in `Balance.default_stats()` unless cheese applies

- [ ] **Step 1: Audit defaults**
- [ ] **Step 2: Commit if changes needed**

### Task 2.4: Faster path to $5k

**Files:**
- Modify: `scripts/game/upgrades/definitions.gd` and/or `scripts/config/balance.gd`

Suggested starting knobs (playtest):

- Lower `base_pay` `base_cost` and/or `growth_rate`
- Slightly higher default `base_amount` in `Balance.default_stats()`
- Lower `distance_pay` unlock cost

- [ ] **Step 1: Apply tune**
- [ ] **Step 2: Optional — extend `tools/simulate_economy.gd` or note playtest target 5–15 min to 5k**
- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
Speed early Play economy toward a $5k prestige goal.

EOF
)"
```

**Part 2 exit:** Play tree is golfer-only; crew hidden; 5k reachable sooner.

---

# Part 3 — Upgrade menu UI (Workstream C)

**Depends on:** Part 0 + Part 1 defs. **Spec:** [05-ui](../../v7/05-ui.md)

### Task 3.1: Tabs on upgrade panel

**Files:**
- Modify: `scenes/ui/upgrade_panel.tscn` (or whatever path the panel scene uses — locate via `upgrade_panel.gd`)
- Modify: `scripts/ui/upgrade_panel.gd`

- [ ] **Step 1: Add tab bar** — `Play` | `Prestige`
- [ ] **Step 2: `_build_tree` filters by tab** — Play uses existing `UpgradeGraph`; Prestige builds from `PrestigeDefinitions` / prestige graph
- [ ] **Step 3: On tab change, rebuild or show/hide tree roots + refresh header**

### Task 3.2: Prestige tab chrome

- [ ] **Step 1: Header currency** — if Prestige tab: `Cheese: N` (or `🧀`-free text `Cheese N`); if Play: `$...` as today
- [ ] **Step 2: Prestige # label** — `Prestige #%d` % `GameState.prestige_count`
- [ ] **Step 3: Connect `EventBus.cheese_changed`**

### Task 3.3: Prestige button

- [ ] **Step 1: Add Button bottom-right of Prestige tab content**
- [ ] **Step 2: Disabled when `not GameState.can_prestige()`**
- [ ] **Step 3: Tooltip / disabled hint with live threshold**
- [ ] **Step 4: Confirm dialog → `GameState.prestige()` → refresh UI**
- [ ] **Step 5: Wire prestige node purchases to `purchase_prestige_upgrade`**

### Task 3.4: Smoke + manual checklist

```bash
$GODOT --headless --path . --quit-after 2
$GODOT --headless --path . --script res://tools/verify_prestige.gd
```

Manual (F5): open upgrades → Prestige tab → cheese header → grey button under 5k → cheat/currency to 5k → prestige → Play tree wiped, cheese up.

- [ ] **Step 1: Commit**

```bash
git commit -m "$(cat <<'EOF'
Add Play/Prestige upgrade tabs and prestige cash-out button.

EOF
)"
```

**Part 3 exit:** full player-facing prestige UX.

---

# Part 4 — Acceptance

**Spec:** [v7-acceptance](../../v7/specs/v7-acceptance.md)

### Task 4.1: Expand `verify_prestige.gd`

Cover:

- Surplus cheese when cash >> threshold
- Ambition raises threshold
- Deep Bucket capacity after prestige wipe of play levels
- Combo mult 0 without perk, &gt; 0 with perk
- Quick Reset lowers cooldown with perk

### Task 4.2: Walk acceptance checklist

- [ ] Mark items in `docs/v7/specs/v7-acceptance.md` as done when verified
- [ ] Final smoke + all verify scripts

```bash
$GODOT --headless --path . --quit-after 2
$GODOT --headless --path . --script res://tools/verify_prestige.gd
$GODOT --headless --path . --script res://tools/verify_upgrade_tree.gd
$GODOT --headless --path . --script res://tools/verify_upgrade_effects.gd
```

### Task 4.3: Final commit / PR note

Document any balance number changes vs design defaults in the PR body.

---

## Out of scope (do not implement in this plan)

- Landlord / day cycles  
- Consumables / vacuum / whistle  
- Ratina/Rattling redesign (hide only)  
- Primers  
- Main HUD cheese display (optional later)

---

## Spec coverage check

| Spec area | Plan part |
|-----------|-----------|
| $5k prestige + wipe + cheese | Part 0 |
| Save cheese / prestige # | Part 0 |
| Cheese tree nodes + Perfect Chain | Part 1 |
| Play trim + pace + hide crew | Part 2 |
| Tabs, cheese header, button | Part 3 |
| Acceptance | Part 4 |
