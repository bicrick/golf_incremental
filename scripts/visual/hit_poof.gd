class_name HitPoof
extends Node2D
## Subtle contact puff when the ball is struck — tier-tinted dust poof.

const DURATION_SEC := 0.32
const PUFF_COUNT := 5


static func spawn(
	parent: Node2D,
	world_pos: Vector2,
	timing_tier: int,
	feedback_tier: int
) -> void:
	var fx := HitPoof.new()
	parent.add_child(fx)
	fx.position = world_pos + Vector2(1.0, -1.0)
	fx.z_as_relative = false
	fx.z_index = 3
	fx._play(timing_tier, feedback_tier)


func _play(timing_tier: int, feedback_tier: int) -> void:
	var tier_color := Balance.TIER_COLORS[clampi(timing_tier, 0, Balance.TIER_COLORS.size() - 1)]
	var scale_mult := _scale_for_tier(timing_tier, feedback_tier)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var core := Polygon2D.new()
	core.color = Color(tier_color.r, tier_color.g, tier_color.b, 0.38)
	core.polygon = PackedVector2Array([
		Vector2(-2, 0), Vector2(0, -2), Vector2(2, 0), Vector2(0, 2),
	])
	core.scale = Vector2(0.35, 0.35)
	add_child(core)

	var core_tween := create_tween()
	core_tween.tween_property(core, "scale", Vector2(1.0, 1.0) * scale_mult * 1.6, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	core_tween.parallel().tween_property(core, "modulate:a", 0.0, DURATION_SEC)

	for i in PUFF_COUNT:
		var fleck := Polygon2D.new()
		var fleck_color := tier_color.lerp(Color(0.72, 0.82, 0.58), 0.35)
		fleck.color = Color(fleck_color.r, fleck_color.g, fleck_color.b, 0.55)
		fleck.polygon = PackedVector2Array([
			Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1),
		])
		var angle := TAU * float(i) / float(PUFF_COUNT) + rng.randf_range(-0.3, 0.3)
		var dist := rng.randf_range(1.5, 4.0) * scale_mult
		fleck.position = Vector2(cos(angle), sin(angle)) * dist * 0.4
		fleck.scale = Vector2(0.4, 0.4)
		add_child(fleck)

		var delay := rng.randf_range(0.0, 0.04)
		var fleck_tween := create_tween()
		fleck_tween.tween_interval(delay)
		fleck_tween.tween_property(
			fleck, "position", fleck.position + Vector2(cos(angle), sin(angle)) * dist, 0.14
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fleck_tween.parallel().tween_property(fleck, "scale", Vector2(0.15, 0.15), 0.14)
		fleck_tween.parallel().tween_property(fleck, "modulate:a", 0.0, 0.2)

	var cleanup := create_tween()
	cleanup.tween_interval(DURATION_SEC + 0.05)
	cleanup.tween_callback(queue_free)


static func _scale_for_tier(timing_tier: int, feedback_tier: int) -> float:
	var scale := 1.0
	match timing_tier:
		Balance.TimingTier.PERFECT:
			scale = 1.15
		Balance.TimingTier.GOOD:
			scale = 1.0
		Balance.TimingTier.OK:
			scale = 0.88
		_:
			scale = 0.72
	if feedback_tier == Balance.FeedbackTier.JACKPOT:
		scale *= 1.18
	elif feedback_tier == Balance.FeedbackTier.WARM:
		scale *= 1.06
	return scale
