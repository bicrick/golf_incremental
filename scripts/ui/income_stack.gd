extends VBoxContainer
## Newest-on-top feed of recent +$ deposits under the HUD bank.

const MAX_ROWS := 5
const HOLD_SEC := 1.0
const FADE_SEC := 0.4
const ROW_HEIGHT := 14
const INCOME_COLOR := Color(1.0, 0.88, 0.25, 1)
const OUTLINE_COLOR := Color(0.2, 0.15, 0.1, 0.8)
const META_LIFE_TWEEN := &"life_tween"

const FloatCashTextScript := preload("res://scripts/visual/float_cash_text.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 1)
	custom_minimum_size = Vector2(0, 0)


func push_amount(amount: float) -> void:
	if amount <= 0.0:
		return
	var row := _make_row(amount)
	add_child(row)
	move_child(row, 0)
	_trim_overflow()
	_refresh_row_dimming()
	_play_row_life(row)


func _make_row(amount: float) -> Label:
	var row := Label.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.text = "+$%s" % FloatCashTextScript.format_amount(amount)
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_color_override(&"font_color", INCOME_COLOR)
	row.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	row.add_theme_constant_override(&"outline_size", 1)
	PixelFont.apply_label(row, 10)
	row.modulate.a = 1.0
	return row


func _trim_overflow() -> void:
	# queue_free alone does not drop get_child_count until end of frame —
	# remove_child first so the while loop cannot hang on spam pushes.
	while get_child_count() > MAX_ROWS:
		var oldest: Node = get_child(get_child_count() - 1)
		_discard_row(oldest)


func _discard_row(row: Node) -> void:
	if row == null or not is_instance_valid(row):
		return
	_kill_row_life(row)
	if row.get_parent() == self:
		remove_child(row)
	row.queue_free()


func _kill_row_life(row: Node) -> void:
	if not row.has_meta(META_LIFE_TWEEN):
		return
	var life: Variant = row.get_meta(META_LIFE_TWEEN)
	row.remove_meta(META_LIFE_TWEEN)
	if life is Tween and (life as Tween).is_valid():
		(life as Tween).kill()


func _refresh_row_dimming() -> void:
	var count := get_child_count()
	for i in count:
		var row := get_child(i) as CanvasItem
		if row == null or not is_instance_valid(row):
			continue
		# Newest (index 0) full bright; older rows slightly dimmer. Preserve fade alpha.
		var dim := clampf(1.0 - float(i) * 0.12, 0.55, 1.0)
		row.modulate = Color(dim, dim, dim, row.modulate.a)


func _play_row_life(row: Label) -> void:
	if row == null or not is_instance_valid(row):
		return
	_kill_row_life(row)
	var tween := create_tween()
	row.set_meta(META_LIFE_TWEEN, tween)
	tween.tween_interval(HOLD_SEC)
	tween.tween_property(row, "modulate:a", 0.0, FADE_SEC)
	tween.tween_callback(_on_row_life_finished.bind(row))


func _on_row_life_finished(row: Label) -> void:
	if row == null or not is_instance_valid(row):
		return
	if row.has_meta(META_LIFE_TWEEN):
		row.remove_meta(META_LIFE_TWEEN)
	_discard_row(row)
