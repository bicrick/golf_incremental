class_name FloatStrikeText
extends Node2D
## Tier name + yardage label — shared by main golfer and Ratina strike feedback.

const DEFAULT_TEXT_OFFSET := Vector2(0.0, -38.0)
const VIEWPORT_MARGIN := 8.0
## Portrait-only: shrink to a caption and park to the right of the golfer.
## Landscape keeps full size and the caller-supplied offset.
const PORTRAIT_SCALE := 0.76
const PORTRAIT_SIDE_X := 52.0
const PORTRAIT_MARGIN := 10.0


static func spawn(
	parent: Node2D,
	anchor_pos: Vector2,
	tier: int,
	yards: float,
	text_offset: Vector2 = DEFAULT_TEXT_OFFSET,
	z_index: int = 2
) -> void:
	var fx: Node2D = load("res://scripts/visual/float_strike_text.gd").new()
	parent.add_child(fx)
	fx.position = anchor_pos
	fx.z_as_relative = false
	fx.z_index = z_index
	fx._play(tier, yards, text_offset)


func _play(tier: int, yards: float, text_offset: Vector2) -> void:
	var tier_name := Balance.TIER_NAMES[tier]
	var label := Label.new()
	label.text = "%s\n%d yds" % [tier_name, int(yards)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelFont.apply_label(label, 8)
	label.modulate = Balance.TIER_COLORS[tier]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.reset_size()
	var size := label.get_minimum_size()
	var portrait := get_viewport() != null and UiLayout.is_portrait(get_viewport())
	var scale := PORTRAIT_SCALE if portrait else 1.0
	label.scale = Vector2(scale, scale)
	var visual := size * scale
	var offset := text_offset
	if portrait:
		offset = Vector2(PORTRAIT_SIDE_X, text_offset.y)
	var local_pos := Vector2(offset.x - visual.x * 0.5, offset.y - visual.y)
	label.position = _clamped_label_pos(local_pos, visual)

	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 0.0, ContactChargeRing.FROZEN_FADE_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _clamped_label_pos(local_pos: Vector2, size: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return local_pos
	var rect := vp.get_visible_rect()
	var global_tl := global_position + local_pos
	var margin := PORTRAIT_MARGIN if UiLayout.is_portrait(vp) else VIEWPORT_MARGIN
	var min_x := rect.position.x + margin
	var max_x := rect.end.x - margin - size.x
	var min_y := rect.position.y + margin
	var max_y := rect.end.y - margin - size.y
	if max_x < min_x:
		max_x = min_x
	if max_y < min_y:
		max_y = min_y
	var clamped := Vector2(
		clampf(global_tl.x, min_x, max_x),
		clampf(global_tl.y, min_y, max_y)
	)
	return clamped - global_position
