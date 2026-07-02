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
	if stat_name == "carry_multiplier" or stat_name == "base_yards":
		var cur_yards := Economy.yards_from_quality(1.0, current)
		var next_yards := Economy.yards_from_quality(1.0, next)
		return "Carry: %.0f yd → %.0f yd" % [cur_yards, next_yards]
	var prefix := _axis_prefix(stat_name)
	var cur_text := _format_stat_value(stat_name, current, false)
	var next_text := _format_stat_value(stat_name, next, false)
	if stat_name == "pay_per_yard":
		var sample_yards := 30.0
		var cur_bonus := current.base_amount * current.pay_per_yard * sample_yards
		var next_bonus := next.base_amount * next.pay_per_yard * sample_yards
		return "%s %s → %s (+$%.2f→$%.2f @%.0fyd)" % [
			prefix, cur_text, next_text, cur_bonus, next_bonus, sample_yards
		]
	return "%s %s → %s" % [prefix, cur_text, next_text]


static func _binary_unlock_label(stat_name: String) -> String:
	match stat_name:
		"yardage_term_unlocked":
			return "Pay: unlock $ per yard at pickup"
		"quality_term_unlocked":
			return "Pay: unlock tier bonus at pickup"
		"pickup_bonus_unlocked":
			return "Pickup: unlock harvest bonuses"
		"magnetic_glove":
			return "Pickup: magnetic glove (soon)"
		_:
			return "Unlock %s" % stat_name


static func _axis_prefix(stat_name: String) -> String:
	match stat_name:
		"base_amount", "pay_per_yard", "yardage_term_unlocked", "quality_multiplier", "quality_term_unlocked":
			return "Pay:"
		"carry_multiplier", "base_yards":
			return "Carry:"
		"timing_window_perfect_ms", "timing_window_great_ms", "swing_cooldown_ms":
			return "Timing:"
		"consistency", "yard_quality_floor":
			return "Quality:"
		"pickup_multiplier", "pickup_flat_bonus", "combo_mult_per_tier", "combo_window_bonus_sec", "pickup_bonus_unlocked":
			return "Pickup:"
		_:
			return ""


static func _format_stat_value(stat_name: String, stats: PlayerStats, compact: bool) -> String:
	match stat_name:
		"base_amount":
			return "$%.2f" % stats.base_amount
		"carry_multiplier":
			return "×%.2f" % stats.carry_multiplier
		"base_yards":
			return "%.0fyd" % stats.base_yards if compact else "%.0f yd" % stats.base_yards
		"pay_per_yard":
			return "$/yd" if compact and stats.yardage_term_unlocked > 0.0 else "%.3f" % stats.pay_per_yard
		"yardage_term_unlocked":
			return "$/yd" if stats.yardage_term_unlocked > 0.0 else "—"
		"quality_multiplier":
			return "×%.2f" % stats.quality_multiplier
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
