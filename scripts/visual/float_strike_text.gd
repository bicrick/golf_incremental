class_name FloatStrikeText
extends Node2D
## Tier name + yardage label — shared by main golfer and Ratina strike feedback.

const DEFAULT_TEXT_OFFSET := Vector2(0.0, -38.0)


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
	label.position = Vector2(text_offset.x - size.x * 0.5, text_offset.y - size.y)

	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 0.0, ContactChargeRing.FROZEN_FADE_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
