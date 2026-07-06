extends SceneTree
## Compounding-aware economy simulation — run:
## godot --headless --script res://tools/simulate_economy.gd

const SEC_PER_BUCKET: float = 16.0
const MIN_TREE_MINUTES: float = 90.0
const MAX_TREE_MINUTES: float = 150.0
const PERFECT_QUALITY: int = 6
const SAMPLE_YARDAGE: float = 30.0

const OPENING_PATH: Array[String] = [
	"base_pay", "base_pay", "power", "quality", "pickup", "distance_pay",
	"base_pay", "metronome", "tip_jar", "combo_bonus",
]

const ROUND_ROBIN: Array[String] = [
	"base_pay", "power", "distance_pay", "quality", "pickup",
	"metronome", "tip_jar", "combo_bonus",
	"iron_set", "great_eye", "quick_reset", "magnetic_glove",
]

const MILESTONES: Array[int] = [10, 21, 50, 100, 177]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := _build_full_path()
	if path.size() != 177:
		print("FAIL: expected 177 purchases, got ", path.size())
		quit(1)
		return

	var levels: Dictionary = {}
	var stats := Balance.default_stats()
	var total_sec: float = 0.0
	var payback_sum: float = 0.0
	var ok := true

	for buy_idx in range(path.size()):
		var upgrade_id: String = path[buy_idx]
		var def := UpgradeDefinitions.get_def(upgrade_id)
		if def.is_empty():
			print("FAIL: unknown upgrade ", upgrade_id)
			quit(1)
			return

		var level: int = int(levels.get(upgrade_id, 0))
		var cost := Economy.upgrade_cost(
			float(def["base_cost"]), float(def["growth_rate"]), level
		)
		var income := _bucket_income(stats)
		var payback := cost / maxf(income, 0.01)
		total_sec += payback * SEC_PER_BUCKET
		payback_sum += payback

		levels[upgrade_id] = level + 1
		stats = UpgradeEffects.preview_stats(levels)

		var purchase_num := buy_idx + 1
		if purchase_num in MILESTONES:
			print(
				"Milestone buy %3d: %-14s cost=$%7.2f income/bkt=$%8.2f payback=%.2f buckets time=%.1f min"
				% [purchase_num, upgrade_id, cost, income, payback, total_sec / 60.0]
			)

	var avg_payback := payback_sum / float(path.size())
	var total_minutes := total_sec / 60.0
	print(
		"Summary: purchases=%d avg_payback=%.2f buckets total_time=%.1f min final_income/bkt=$%.2f"
		% [path.size(), avg_payback, total_minutes, _bucket_income(stats)]
	)

	if total_minutes < MIN_TREE_MINUTES:
		print(
			"FAIL: full tree too fast (%.1f min < %.0f min target)"
			% [total_minutes, MIN_TREE_MINUTES]
		)
		ok = false
	elif total_minutes > MAX_TREE_MINUTES:
		print(
			"FAIL: full tree too slow (%.1f min > %.0f min target)"
			% [total_minutes, MAX_TREE_MINUTES]
		)
		ok = false
	else:
		print(
			"OK: full tree time %.1f min within %.0f–%.0f min window"
			% [total_minutes, MIN_TREE_MINUTES, MAX_TREE_MINUTES]
		)

	print("simulate_economy_ok=", ok)
	quit(0 if ok else 1)


func _build_full_path() -> Array[String]:
	var path: Array[String] = []
	path.assign(OPENING_PATH)

	var counts: Dictionary = {}
	for id in path:
		counts[id] = int(counts.get(id, 0)) + 1

	while path.size() < 177:
		var added := false
		for upgrade_id in ROUND_ROBIN:
			if path.size() >= 177:
				break
			var def := UpgradeDefinitions.get_def(upgrade_id)
			var max_level: int = int(def.get("max_level", 0))
			if int(counts.get(upgrade_id, 0)) >= max_level:
				continue
			path.append(upgrade_id)
			counts[upgrade_id] = int(counts.get(upgrade_id, 0)) + 1
			added = true
		if not added:
			break

	return path


func _bucket_income(stats: PlayerStats) -> float:
	var balls := Balance.BUCKET_CAPACITY_DEFAULT
	var per_ball := 0.0
	for _i in range(balls):
		per_ball += Economy.resolve_pickup_ball_payout(
			PERFECT_QUALITY, SAMPLE_YARDAGE, 1, stats
		)
	return per_ball
