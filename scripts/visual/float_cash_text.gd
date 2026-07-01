class_name FloatCashText
extends Node2D
## Floating +$ label — shared by swing payouts and pickup collects.

const COLOR_CASH := Color(1.0, 0.88, 0.25)
const LABEL_OFFSET := Vector2(-28, -40)
const RISE_OFFSET := Vector2(0, -48)
const DURATION_SEC := 0.85
const FADE_DELAY_SEC := 0.25


static func spawn(
	parent: Node2D,
	world_pos: Vector2,
	amount: float,
	combo_tier: int = 0,
	z_index: int = 4
) -> void:
	var fx: Node2D = load("res://scripts/visual/float_cash_text.gd").new()
	parent.add_child(fx)
	fx.position = world_pos
	fx.z_as_relative = false
	fx.z_index = z_index
	fx._play(amount, combo_tier)


static func format_amount(amount: float) -> String:
	if amount >= 1_000_000:
		return "%.2fM" % (amount / 1_000_000.0)
	if amount >= 1_000:
		return "%.2fK" % (amount / 1_000.0)
	if amount < 1.0:
		return "%.2f" % amount
	if is_equal_approx(amount, floor(amount)):
		return str(int(amount))
	return "%.2f" % amount


func _play(amount: float, _combo_tier: int) -> void:
	var label := Label.new()
	label.text = "+$%s" % format_amount(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelFont.apply_label(label, 8)
	label.modulate = COLOR_CASH
	label.position = LABEL_OFFSET
	add_child(label)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + RISE_OFFSET, DURATION_SEC)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, DURATION_SEC).set_delay(FADE_DELAY_SEC)
	tween.chain().tween_callback(queue_free)
