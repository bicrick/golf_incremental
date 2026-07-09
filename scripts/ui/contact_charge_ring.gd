class_name ContactChargeRing
extends Node2D
## Concentric rhombus charge UI — inner expands into upgrade-scaled outer target.

const FROZEN_FADE_DURATION: float = 1.0

## Hides the charge rhombus visuals while keeping all timing/scale logic intact.
## Flip to true to bring the rhombus back.
const RING_VISUALS_ENABLED: bool = false

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


## Piecewise blend across Balance.TIER_COLORS keyed to the same ms windows as evaluate_timing.
static func charge_timing_color(elapsed_sec: float, stats: PlayerStats) -> Color:
	if elapsed_sec < Balance.MIN_HOLD_SEC:
		return Balance.TIER_COLORS[Balance.TimingTier.MISS]

	var contact := Balance.CONTACT_WINDUP_SEC
	var delta_sec := elapsed_sec - contact

	if delta_sec <= 0.0:
		var early_ms := absf(delta_sec) * 1000.0
		var early_stops: Array = [
			[stats.timing_window_perfect_ms, Balance.TimingTier.PERFECT],
			[stats.timing_window_great_ms, Balance.TimingTier.GREAT],
			[stats.timing_window_good_ms, Balance.TimingTier.GOOD],
			[stats.timing_window_okay_ms, Balance.TimingTier.OKAY],
			[stats.timing_window_bad_ms, Balance.TimingTier.BAD],
		]
		return _ladder_color(early_ms, Balance.TimingTier.PERFECT, early_stops)

	var late_ms := delta_sec * 1000.0
	var late_stops: Array = [
		[Balance.POST_PEAK_GREAT_MS, Balance.TimingTier.GREAT],
		[Balance.POST_PEAK_GOOD_MS, Balance.TimingTier.GOOD],
		[Balance.POST_PEAK_OKAY_MS, Balance.TimingTier.OKAY],
		[Balance.POST_PEAK_BAD_MAX_SEC * 1000.0, Balance.TimingTier.BAD],
	]
	return _ladder_color(late_ms, Balance.TimingTier.GREAT, late_stops)


## Blends between consecutive tier colors as `value_ms` crosses each stop's
## threshold. `start_tier` supplies the color for the 0..first-stop range.
## Past the final stop, falls through to the Miss color (matches evaluate_timing).
static func _ladder_color(value_ms: float, start_tier: int, stops: Array) -> Color:
	var prev_ms := 0.0
	var prev_color: Color = Balance.TIER_COLORS[start_tier]
	for stop in stops:
		var threshold_ms: float = stop[0]
		var tier: int = stop[1]
		var color: Color = Balance.TIER_COLORS[tier]
		if value_ms <= threshold_ms:
			var t := inverse_lerp(prev_ms, maxf(threshold_ms, prev_ms + 0.001), value_ms)
			return prev_color.lerp(color, clampf(t, 0.0, 1.0))
		prev_ms = threshold_ms
		prev_color = color
	return Balance.TIER_COLORS[Balance.TimingTier.MISS]


static func charge_outer_color(inner: Color) -> Color:
	var outer := inner.darkened(0.55)
	outer.a = 0.72
	return outer


static func outer_scale_for_stats(stats: PlayerStats) -> float:
	var default := Balance.default_stats()
	var min_metric := Economy.yards_from_quality(1.0, default)
	var max_metric := _max_distance_power_metric()
	var metric := Economy.yards_from_quality(1.0, stats)
	var t := inverse_lerp(min_metric, max_metric, metric)
	return lerpf(
		Balance.RING_OUTER_MIN_SCALE,
		Balance.RING_OUTER_MAX_SCALE,
		clampf(t, 0.0, 1.0)
	)


static func _max_distance_power_metric() -> float:
	var levels := {}
	for id in ["distance_pay", "iron_set", "perfect_pop"]:
		levels[id] = UpgradeDefinitions.get_def(id).get("max_level", 0)
	var stats := UpgradeEffects.preview_stats(levels)
	return Economy.yards_from_quality(1.0, stats)


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
		ring_outer.visible = RING_VISUALS_ENABLED
	if ring_inner:
		ring_inner.visible = RING_VISUALS_ENABLED
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
	ring_outer.visible = RING_VISUALS_ENABLED
	ring_outer.scale = Vector2.ONE * outer_scale
	ring_outer.modulate = color


func _apply_inner(inner_scale: float, color: Color) -> void:
	if not ring_inner:
		return
	ring_inner.visible = RING_VISUALS_ENABLED
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
