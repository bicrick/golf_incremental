class_name UpgradeTooltipText
extends RefCounted
## Quantitative upgrade tooltips — recompute stats for accurate previews.


static func compact_stat(
	def: Dictionary,
	level: int,
	levels: Dictionary,
	preview_provider: Variant = null
) -> String:
	if level <= 0:
		return ""
	var stats := _stats_at(def["id"], level, levels, preview_provider)
	var primary := _primary_effect(def)
	if primary.is_empty():
		return ""
	return _format_stat_value(str(primary.get("stat", "")), stats, true)


static func effect_preview(
	def: Dictionary,
	level: int,
	levels: Dictionary,
	maxed: bool,
	preview_provider: Variant = null
) -> String:
	var max_level := int(def.get("max_level", 0))
	if maxed:
		var stats := _stats_at(def["id"], level, levels, preview_provider)
		return _format_max_preview(def, stats)
	if level >= max_level:
		return ""
	var current_stats := _stats_at(def["id"], level, levels, preview_provider)
	var next_stats := _stats_at(def["id"], level + 1, levels, preview_provider)
	return _format_delta_preview(def, current_stats, next_stats)


static func _stats_at(
	upgrade_id: String,
	level: int,
	levels: Dictionary,
	preview_provider: Variant = null
) -> PlayerStats:
	var temp := levels.duplicate()
	temp[upgrade_id] = level
	if preview_provider == null:
		return UpgradeEffects.preview_stats(temp)
	return preview_provider.call(temp)


static func _primary_effect(def: Dictionary) -> Dictionary:
	var effects: Array = def.get("effects", [])
	for effect in effects:
		if str(effect.get("type", "")) == "binary":
			continue
		return effect
	for effect in effects:
		if str(effect.get("type", "")) == "binary":
			return effect
	return {}


static func _format_max_preview(def: Dictionary, stats: PlayerStats) -> String:
	var primary := _primary_effect(def)
	if primary.is_empty():
		return ""
	var stat_name := str(primary.get("stat", ""))
	if str(primary.get("type", "")) == "binary":
		return _binary_unlock_label(stat_name)
	return _format_stat_value(stat_name, stats, false)


static func _format_delta_preview(def: Dictionary, current: PlayerStats, next: PlayerStats) -> String:
	var primary := _primary_effect(def)
	if primary.is_empty():
		return ""
	var stat_name := str(primary.get("stat", ""))
	if str(primary.get("type", "")) == "binary" and _read_stat(current, stat_name) <= 0.0:
		return _binary_unlock_label(stat_name)
	if (
		stat_name == "base_yards"
		or stat_name == "sweet_spot_bonus"
		or stat_name == "perfect_power_bonus"
	):
		var cur_yards := Economy.yards_from_quality(1.0, current)
		var next_yards := Economy.yards_from_quality(1.0, next)
		return "Carry: %.0f yd → %.0f yd" % [cur_yards, next_yards]
	var prefix := _axis_prefix(stat_name)
	var cur_text := _format_stat_value(stat_name, current, false)
	var next_text := _format_stat_value(stat_name, next, false)
	if stat_name == "pay_per_yard" or stat_name == "base_amount":
		## Plain English: what a ball at your current best carry is worth.
		var yards := maxf(Economy.yards_from_quality(1.0, current), 1.0)
		var cur_ball := Economy.resolve_pickup_ball_payout(6, yards, 1, current)
		var next_ball := Economy.resolve_pickup_ball_payout(6, yards, 1, next)
		return "A %.0f yd ball: $%s → $%s" % [
			yards, FloatCashText.format_amount(cur_ball), FloatCashText.format_amount(next_ball)
		]
	return "%s %s → %s" % [prefix, cur_text, next_text]


static func _binary_unlock_label(stat_name: String) -> String:
	match stat_name:
		"yardage_term_unlocked":
			return "Starts paying for distance."
		"sweet_spot_unlocked":
			return "Starts helping your contact."
		"pickup_bonus_unlocked":
			return "Starts paying a pickup bonus."
		_:
			return "Unlock %s" % stat_name


static func _axis_prefix(stat_name: String) -> String:
	match stat_name:
		"base_amount", "pay_per_yard", "yardage_term_unlocked":
			return "Pay:"
		"base_yards", "sweet_spot_bonus", "sweet_spot_unlocked", "perfect_power_bonus":
			return "Carry:"
		"timing_window_perfect_ms", "timing_window_great_ms", "swing_cooldown_ms":
			return "Timing:"
		"consistency", "yard_quality_floor":
			return "Contact:"
		"pickup_multiplier", "pickup_flat_bonus", "combo_mult_per_tier", "combo_window_bonus_sec", "pickup_bonus_unlocked", "range_picker_radius_bonus":
			return "Pickup:"
		"rattling_count":
			return "Crew:"
		"rattling_walk_speed", "rattling_pickup_speed_multiplier":
			return "Speed:"
		"rattling_golden_bonus_chance":
			return "Golden:"
		_:
			return ""


static func _format_stat_value(stat_name: String, stats: PlayerStats, compact: bool) -> String:
	match stat_name:
		"base_amount":
			return "$%.2f" % stats.base_amount
		"base_yards":
			return "%.0fyd" % stats.base_yards if compact else "%.0f yd" % stats.base_yards
		"pay_per_yard":
			return "$/yd" if compact and stats.yardage_term_unlocked > 0.0 else "%.3f" % stats.pay_per_yard
		"yardage_term_unlocked":
			return "$/yd" if stats.yardage_term_unlocked > 0.0 else "—"
		"sweet_spot_unlocked":
			return "on" if stats.sweet_spot_unlocked > 0.0 else "—"
		"sweet_spot_bonus":
			return "+%.0f%%" % (stats.sweet_spot_bonus * 100.0)
		"perfect_power_bonus":
			return "×%.2f" % stats.perfect_power_bonus
		"timing_window_perfect_ms", "timing_window_great_ms":
			return "±%.0fms" % _read_stat(stats, stat_name)
		"swing_cooldown_ms":
			return "%.1fs" % (stats.swing_cooldown_ms / 1000.0)
		"consistency":
			return "%.0f%%" % (stats.consistency * 100.0)
		"yard_quality_floor":
			return "%.0f%%" % (stats.yard_quality_floor * 100.0)
		"pickup_multiplier":
			return "×%.2f" % stats.pickup_multiplier
		"pickup_flat_bonus":
			return "+$%.2f" % stats.pickup_flat_bonus
		"combo_mult_per_tier":
			return "+%.0f%%" % (stats.combo_mult_per_tier * 100.0)
		"combo_window_bonus_sec":
			return "+%.1fs" % stats.combo_window_bonus_sec
		"range_picker_radius_bonus":
			var radius := Balance.range_picker_radius_yards(stats)
			return "%.2f yd" % radius if compact else "Circle: %.2f yd" % radius
		"rattling_count":
			return "x%d" % int(stats.rattling_count)
		"rattling_walk_speed":
			return "%.1fyd/s" % stats.rattling_walk_speed
		"rattling_pickup_speed_multiplier":
			return "×%.2f" % stats.rattling_pickup_speed_multiplier
		"rattling_golden_bonus_chance":
			return "%.0f%%" % (stats.rattling_golden_bonus_chance * 100.0)
		_:
			return ""


static func _read_stat(stats: PlayerStats, stat_name: String) -> float:
	match stat_name:
		"timing_window_perfect_ms":
			return stats.timing_window_perfect_ms
		"timing_window_great_ms":
			return stats.timing_window_great_ms
		_:
			return 0.0
