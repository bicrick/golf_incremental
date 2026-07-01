class_name ContactChargeRing
extends Node2D
## Concentric rhombus charge UI — inner expands into upgrade-scaled outer target.

const FROZEN_FADE_DURATION: float = 1.0
const COLOR_PERFECT := Color(0.35, 0.85, 0.42)
const COLOR_GOOD := Color(1.0, 0.88, 0.25)
const COLOR_BAD := Color(0.92, 0.32, 0.28)

signal frozen_fade_completed

const FLAVOR_COLORS: Dictionary = {
	Balance.ContactFlavor.PURE: Color(0.45, 0.92, 0.48),
	Balance.ContactFlavor.SLIGHTLY_FAT: Color(1.0, 0.82, 0.35),
	Balance.ContactFlavor.THIN: Color(0.98, 0.62, 0.38),
	Balance.ContactFlavor.CHUNK: Color(0.88, 0.38, 0.30),
}

@onready var ring_outer: Polygon2D = $RingOuter
@onready var ring_inner: Polygon2D = $RingInner

var _flash_tween: Tween
var _fade_tween: Tween
var _frozen: bool = false
var _cached_outer_scale: float = Balance.RING_OUTER_MIN_SCALE


func _ready() -> void:
	hide_idle()


func is_frozen() -> bool:
	return _frozen


func clear_frozen_result() -> void:
	if not _frozen:
		return
	_kill_fade_tween()
	_frozen = false
	hide_idle()


func is_flash_active() -> bool:
	return _flash_tween != null and _flash_tween.is_valid()


static func inner_scale_for_windup(
	windup: float, past_contact: bool, past_contact_frac: float
) -> float:
	if past_contact:
		return lerpf(
			Balance.RING_INNER_CONTACT_FRAC,
			Balance.RING_INNER_OVERSHOOT_FRAC,
			past_contact_frac
		)
	return lerpf(Balance.RING_INNER_START_FRAC, Balance.RING_INNER_CONTACT_FRAC, windup)


static func inner_scale_for_hold(hold_sec: float) -> float:
	var charge := ChargeSwing.new()
	return inner_scale_for_windup(
		charge.windup_progress(hold_sec),
		charge.past_contact(hold_sec),
		charge.past_contact_fraction(hold_sec)
	)


static func inner_visual_scale_for_windup(
	windup: float, past_contact: bool, past_contact_frac: float, outer_scale: float
) -> float:
	return inner_scale_for_windup(windup, past_contact, past_contact_frac) * outer_scale


static func perfect_zone_early_hold_sec(stats: PlayerStats) -> float:
	var contact := Balance.CONTACT_WINDUP_SEC
	var early := contact - stats.timing_window_perfect_ms / 1000.0
	return maxf(Balance.MIN_HOLD_SEC, early)


static func perfect_zone_inner_scale_bounds(stats: PlayerStats) -> Vector2:
	var contact := Balance.CONTACT_WINDUP_SEC
	var early_hold := perfect_zone_early_hold_sec(stats)
	var early_windup := clampf(early_hold / contact, 0.0, 1.0)
	var early_scale := inner_scale_for_windup(early_windup, false, 0.0)
	var late_scale := Balance.RING_INNER_CONTACT_FRAC
	return Vector2(early_scale, late_scale)


static func is_inner_in_perfect_zone(
	inner_scale: float, stats: PlayerStats, past_contact: bool
) -> bool:
	if past_contact:
		return false
	var bounds := perfect_zone_inner_scale_bounds(stats)
	return inner_scale >= bounds.x - 0.0001 and inner_scale <= bounds.y + 0.0001


static func is_hold_in_perfect_zone(hold_sec: float, stats: PlayerStats) -> bool:
	var charge := ChargeSwing.new()
	if hold_sec < Balance.MIN_HOLD_SEC or charge.past_contact(hold_sec):
		return false
	return charge.evaluate_timing(hold_sec, stats) == Balance.TimingTier.PERFECT


## Piecewise green → yellow → red blend keyed to the same ms windows as evaluate_timing.
static func charge_timing_color(elapsed_sec: float, stats: PlayerStats) -> Color:
	if elapsed_sec < Balance.MIN_HOLD_SEC:
		return COLOR_BAD

	var contact := Balance.CONTACT_WINDUP_SEC
	var delta_sec := elapsed_sec - contact
	var perfect_ms := stats.timing_window_perfect_ms
	var good_ms := stats.timing_window_good_ms
	var ok_ms := good_ms * 1.5

	if delta_sec <= 0.0:
		var early_ms := absf(delta_sec) * 1000.0
		if early_ms <= perfect_ms:
			return COLOR_PERFECT
		if early_ms <= good_ms:
			var t := (early_ms - perfect_ms) / maxf(good_ms - perfect_ms, 0.001)
			return COLOR_PERFECT.lerp(COLOR_GOOD, t)
		if early_ms <= ok_ms:
			var t := (early_ms - good_ms) / maxf(ok_ms - good_ms, 0.001)
			return COLOR_GOOD.lerp(COLOR_BAD, t)
		return COLOR_BAD

	var late_ms := delta_sec * 1000.0
	var good_late_ms := Balance.POST_PEAK_GOOD_MS
	var ok_max_ms := Balance.CONTACT_DECAY_SEC * 0.5 * 1000.0
	if late_ms <= good_late_ms:
		var t := late_ms / maxf(good_late_ms, 0.001)
		return COLOR_PERFECT.lerp(COLOR_GOOD, t)
	if late_ms <= ok_max_ms:
		var t := (late_ms - good_late_ms) / maxf(ok_max_ms - good_late_ms, 0.001)
		return COLOR_GOOD.lerp(COLOR_BAD, t)
	return COLOR_BAD


static func charge_outer_color(inner: Color) -> Color:
	var outer := inner.darkened(0.55)
	outer.a = 0.72
	return outer


static func outer_scale_for_stats(stats: PlayerStats) -> float:
	var default := Balance.default_stats()
	var min_metric := default.max_yards * default.yard_multiplier
	var max_metric := _max_distance_power_metric()
	var metric := stats.max_yards * stats.yard_multiplier
	var t := inverse_lerp(min_metric, max_metric, metric)
	return lerpf(
		Balance.RING_OUTER_MIN_SCALE,
		Balance.RING_OUTER_MAX_SCALE,
		clampf(t, 0.0, 1.0)
	)


static func _max_distance_power_metric() -> float:
	var stats := Balance.default_stats()
	var levels := {
		"power": UpgradeDefinitions.get_def("power").get("max_level", 0),
		"leg_day": UpgradeDefinitions.get_def("leg_day").get("max_level", 0),
		"followthrough_form": UpgradeDefinitions.get_def("followthrough_form").get("max_level", 0),
		"core_strength": UpgradeDefinitions.get_def("core_strength").get("max_level", 0),
	}
	UpgradeEffects.apply_all(stats, levels)
	return stats.max_yards * stats.yard_multiplier


func show_charging(stats: PlayerStats) -> void:
	_frozen = false
	_kill_fade_tween()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null
	scale = Vector2.ONE
	var outer_scale := outer_scale_for_stats(stats)
	_cached_outer_scale = outer_scale
	if ring_outer:
		ring_outer.visible = true
	if ring_inner:
		ring_inner.visible = true
	var inner_color := charge_timing_color(0.0, stats)
	_apply_outer(outer_scale, charge_outer_color(inner_color))
	_apply_inner(
		Balance.RING_INNER_START_FRAC * outer_scale,
		inner_color
	)


func hide_idle() -> void:
	if _frozen:
		return
	if _flash_tween and _flash_tween.is_valid():
		return
	_hide_all_ring_elements()


func _hide_all_ring_elements() -> void:
	scale = Vector2.ONE
	if ring_outer:
		ring_outer.visible = false
		ring_outer.scale = Vector2.ONE * Balance.RING_OUTER_MIN_SCALE
		ring_outer.modulate = Color.WHITE
	if ring_inner:
		ring_inner.visible = false
		ring_inner.scale = Vector2.ONE * Balance.RING_INNER_START_FRAC * Balance.RING_OUTER_MIN_SCALE
		ring_inner.modulate = Color.WHITE


func update_visuals(
	windup: float,
	_in_band: bool,
	past_contact: bool,
	past_contact_frac: float,
	elapsed: float,
	stats: PlayerStats
) -> void:
	if _frozen or is_flash_active():
		return

	scale = Vector2.ONE
	_cached_outer_scale = outer_scale_for_stats(stats)
	var inner_scale := inner_visual_scale_for_windup(
		windup, past_contact, past_contact_frac, _cached_outer_scale
	)
	var inner_color := charge_timing_color(elapsed, stats)
	_apply_outer(_cached_outer_scale, charge_outer_color(inner_color))
	_apply_inner(inner_scale, inner_color)


func freeze_release_result(
	tier: int,
	flavor: int,
	hold_sec: float,
	stats: PlayerStats
) -> void:
	_frozen = true
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null

	var charge := ChargeSwing.new()
	var windup := charge.windup_progress(hold_sec)
	var past_contact := charge.past_contact(hold_sec)
	var past_frac := charge.past_contact_fraction(hold_sec)
	var inner_scale := inner_visual_scale_for_windup(
		windup, past_contact, past_frac, outer_scale_for_stats(stats)
	)
	_cached_outer_scale = outer_scale_for_stats(stats)

	var colors := _release_colors(tier, flavor)
	_apply_outer(_cached_outer_scale, colors["outer"])
	_apply_inner(inner_scale, colors["inner"])

	_start_frozen_fade()


func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _start_frozen_fade() -> void:
	_kill_fade_tween()
	_fade_tween = create_tween().set_parallel(true)
	if ring_outer:
		_fade_tween.tween_property(ring_outer, "modulate:a", 0.0, FROZEN_FADE_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if ring_inner:
		_fade_tween.tween_property(ring_inner, "modulate:a", 0.0, FROZEN_FADE_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fade_tween.chain().tween_callback(_on_frozen_fade_complete)


func _on_frozen_fade_complete() -> void:
	_fade_tween = null
	_frozen = false
	_hide_all_ring_elements()
	frozen_fade_completed.emit()


func _apply_outer(outer_scale: float, color: Color) -> void:
	if not ring_outer:
		return
	ring_outer.visible = true
	ring_outer.scale = Vector2.ONE * outer_scale
	ring_outer.modulate = color


func _apply_inner(inner_scale: float, color: Color) -> void:
	if not ring_inner:
		return
	ring_inner.visible = true
	ring_inner.scale = Vector2.ONE * inner_scale
	ring_inner.modulate = color


func _release_colors(tier: int, flavor: int) -> Dictionary:
	var tier_color: Color = Balance.TIER_COLORS[tier]
	var flavor_color: Color = FLAVOR_COLORS.get(flavor, tier_color)
	var blend := 0.35 if tier == Balance.TimingTier.MISS else 0.15
	var inner := tier_color.lerp(flavor_color, blend)
	inner.a = 0.95
	var outer := tier_color.lerp(flavor_color, blend * 0.5)
	outer.a = 0.88
	return {"inner": inner, "outer": outer}
