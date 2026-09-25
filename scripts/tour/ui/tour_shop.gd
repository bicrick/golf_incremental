class_name TourShop
extends PanelContainer
## v8 Pro Shop: a slim panel on the right. You can keep swinging while it's open.

const ROW_H := 19
const WIDTH := 184

var _rows: VBoxContainer
var _info: Label
var _info_title: Label
var _hover_id := ""
var _open := false
var _row_nodes := {}


func _ready() -> void:
	add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER, TourUi.INK, 4))
	custom_minimum_size = Vector2(WIDTH, 0)
	size = Vector2(WIDTH, 232)
	position = Vector2(480, 30)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 3)
	add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := TourUi.label("PRO SHOP", 8, TourUi.GREEN_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := TourUi.button("x", TourUi.PAPER_DIM, TourUi.INK)
	close.custom_minimum_size = Vector2(14, 12)
	close.pressed.connect(toggle)
	head.add_child(close)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 1)
	vb.add_child(_rows)
	var sep := ColorRect.new()
	sep.color = TourUi.INK_SOFT
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)
	_info_title = TourUi.label("", 8, TourUi.INK)
	vb.add_child(_info_title)
	_info = TourUi.label("", 8, TourUi.INK_SOFT)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(WIDTH - 12, 0)
	_info.add_theme_constant_override(&"line_spacing", 1)
	vb.add_child(_info)
	Tour.upgrades_changed.connect(_rebuild)
	Tour.money_changed.connect(func(_m: float) -> void: _refresh_rows())
	visible = false
	_rebuild()


func is_open() -> bool:
	return _open


func toggle() -> void:
	_open = not _open
	var tw := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if _open:
		visible = true
		_rebuild()
		tw.tween_property(self, "position:x", 480.0 - WIDTH - 6.0, 0.22)
	else:
		tw.tween_property(self, "position:x", 480.0, 0.18)
		tw.tween_callback(func() -> void: visible = false)
	Audio.play("page")


func _rebuild() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_row_nodes.clear()
	for u in TourData.UPGRADES:
		var id: String = u["id"]
		if not Tour.upgrade_visible(id):
			continue
		var row := _make_row(u)
		_rows.add_child(row)
		_row_nodes[id] = row
	_refresh_rows()
	_show_info(_hover_id if _row_nodes.has(_hover_id) else "")


func _make_row(u: Dictionary) -> Control:
	var id: String = u["id"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(WIDTH - 10, ROW_H)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in [&"normal", &"hover", &"pressed", &"disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	b.set_meta("id", id)
	b.set_meta("icon", load("res://assets/sprites/tour/icons/%s.png" % u["icon"]))
	b.pressed.connect(func() -> void: _buy(id))
	b.mouse_entered.connect(func() -> void: _show_info(id))
	b.draw.connect(func() -> void: _draw_row(b, u))
	return b


func _buy(id: String) -> void:
	if Tour.buy(id):
		Audio.play("buy", 1.0 + 0.04 * Tour.level(id))
		_show_info(id)
		var row: Control = _row_nodes.get(id)
		if row:
			var tw := row.create_tween()
			row.modulate = Color(1.4, 1.3, 0.9)
			tw.tween_property(row, "modulate", Color.WHITE, 0.3)
	else:
		Audio.play("ui_error")


func _refresh_rows() -> void:
	for id in _row_nodes:
		(_row_nodes[id] as Control).queue_redraw()


func _draw_row(b: Button, u: Dictionary) -> void:
	var id: String = u["id"]
	var maxed := Tour.upgrade_maxed(id)
	var afford := Tour.can_buy(id)
	var hovered := b.is_hovered()
	var r := Rect2(Vector2.ZERO, b.size)
	var bg := TourUi.PAPER_HI if hovered else TourUi.PAPER
	if afford:
		bg = bg.lerp(Color("dff0c8"), 0.6)
	b.draw_rect(r, bg)
	b.draw_rect(Rect2(0, r.size.y - 1, r.size.x, 1), TourUi.PAPER_DIM)
	var icon: Texture2D = b.get_meta("icon", null)
	if icon:
		b.draw_texture_rect(icon, Rect2(1, 1, 16, 16), false, Color.WHITE if (afford or maxed) else Color(0.75, 0.75, 0.75))
	var font := PixelFont.font_for_size(8)
	var name_col := TourUi.INK if (afford or maxed) else TourUi.INK_SOFT
	b.draw_string(font, Vector2(21, 10), u["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, name_col)
	## Level pips (or a count when there are many levels).
	var lv := Tour.level(id)
	var mx := int(u["max"])
	if mx <= 8:
		for i in mx:
			var pc := TourUi.GREEN if i < lv else TourUi.PAPER_DIM.darkened(0.1)
			b.draw_rect(Rect2(21 + i * 4, 13, 3, 3), pc)
	else:
		TinyText.draw(b, Vector2(21, 12), "LV %d" % lv, TourUi.GREEN_DARK)
	var cost_txt := "MAX" if maxed else "$" + TourFormat.money(Tour.upgrade_cost(id))
	var w := font.get_string_size(cost_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var cc := TourUi.GREEN_DARK if afford else (TourUi.INK_SOFT if not maxed else TourUi.GOLD.darkened(0.3))
	b.draw_string(font, Vector2(r.size.x - w - 2, 13), cost_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cc)


func _show_info(id: String) -> void:
	_hover_id = id
	if id == "":
		_info_title.text = ""
		_info.text = "Pick something. Hover for details."
		return
	var u := TourData.upgrade(id)
	_info_title.text = u["name"]
	_info.text = "%s\n%s" % [u["desc"], _preview(id)]


func _preview(id: String) -> String:
	var lv := Tour.level(id)
	if Tour.upgrade_maxed(id):
		return "Maxed out."
	match id:
		"power":
			var now := Tour.reach()
			return "Reach %sy -> %sy" % [TourFormat.yards(now), TourFormat.yards(now * TourData.POWER_STEP)]
		"fee":
			return "Pay x%s -> x%s" % [TourFormat.mult(1.0 + 0.5 * lv), TourFormat.mult(1.0 + 0.5 * (lv + 1))]
		"bucket":
			return "%d -> %d balls" % [Tour.bucket_size(), Tour.bucket_size() + 2]
		"sweet":
			return "Windows +%d%% -> +%d%%" % [12 * lv, 12 * (lv + 1)]
		"greens":
			return "Green x%s -> x%s" % [TourFormat.mult(TourData.GREEN_MULT + 0.5 * lv), TourFormat.mult(TourData.GREEN_MULT + 0.5 * (lv + 1))]
		"streak":
			return "Cap %d -> %d" % [3 + 2 * lv, 3 + 2 * (lv + 1)]
		"golden":
			return "%d%% -> %d%%" % [2 * lv, 2 * (lv + 1)]
		"cart":
			return "Radius +%d%% -> +%d%%" % [20 * lv, 20 * (lv + 1)]
		"wind":
			return "Drift -%d%% -> -%d%%" % [15 * lv, 15 * (lv + 1)]
		"roll":
			return "Roll +%d%%" % [20 * (lv + 1)]
		"oil":
			return "+%d%% -> +%d%% per lantern" % [15 + 10 * lv, 15 + 10 * (lv + 1)]
	return ""
