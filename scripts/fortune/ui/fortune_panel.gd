class_name FortunePanel
extends PanelContainer
## v9 upgrade panel: always open on the right, showing the current room's
## upgrades. Affordable rows glow; buying one pops.

const WIDTH := 150
const ROW_H := 20

var room_id := "tee"
var _rows: VBoxContainer
var _title: Label
var _info_title: Label
var _info: Label
var _row_nodes := {}
var _hover := ""
var _t := 0.0


func _ready() -> void:
	add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER, TourUi.INK, 4))
	position = Vector2(480 - WIDTH, 24)
	size = Vector2(WIDTH, 246)
	custom_minimum_size = Vector2(WIDTH, 246)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 2)
	add_child(vb)
	_title = TourUi.label("", 8, TourUi.GREEN_DARK)
	vb.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH - 10, 168)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 1)
	scroll.add_child(_rows)
	var sep := ColorRect.new()
	sep.color = TourUi.INK_SOFT
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)
	_info_title = TourUi.label("", 8, TourUi.INK)
	vb.add_child(_info_title)
	_info = TourUi.label("", 8, TourUi.INK_SOFT)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(WIDTH - 12, 0)
	vb.add_child(_info)
	Game.upgrades_changed.connect(_rebuild)
	Game.cash_changed.connect(func(_c: float) -> void: _refresh())
	_rebuild()


func show_room(id: String) -> void:
	room_id = id
	_hover = ""
	_rebuild()


func _rebuild() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_row_nodes.clear()
	_title.text = String(FortuneData.room(room_id)["name"]).to_upper()
	for u in FortuneData.upgrades_for(room_id):
		if not Game.available(u["id"]) and not u.has("needs"):
			continue
		_rows.add_child(_make_row(u))
	_show_info(_hover)


func _make_row(u: Dictionary) -> Control:
	var id: String = u["id"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(WIDTH - 12, ROW_H)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.set_meta("icon", load("res://assets/sprites/tour/icons/%s.png" % u["icon"]))
	b.pressed.connect(func() -> void: _buy(id, b))
	b.mouse_entered.connect(func() -> void: _show_info(id))
	b.draw.connect(func() -> void: _draw_row(b, u))
	_row_nodes[id] = b
	return b


func _buy(id: String, row: Control) -> void:
	if Game.buy(id):
		Audio.play("buy", 1.0 + 0.03 * Game.level(id))
		row.pivot_offset = row.size * 0.5
		row.scale = Vector2(1.08, 1.08)
		row.create_tween().tween_property(row, "scale", Vector2.ONE, 0.18)
		_show_info(id)
	else:
		Audio.play("ui_error")


func _refresh() -> void:
	for id in _row_nodes:
		(_row_nodes[id] as Control).queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 6.0) % 2 == 0:
		_refresh()


func _draw_row(b: Button, u: Dictionary) -> void:
	var id: String = u["id"]
	var maxed := Game.maxed(id)
	var locked := not Game.available(id)
	var afford := Game.can_buy(id)
	var r := Rect2(Vector2.ZERO, b.size)
	var bg := TourUi.PAPER_HI if b.is_hovered() else TourUi.PAPER
	if afford:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		bg = bg.lerp(Color("dff5c0"), 0.55 + 0.2 * pulse)
	b.draw_rect(r, bg)
	b.draw_rect(Rect2(0, r.size.y - 1, r.size.x, 1), TourUi.PAPER_DIM)
	var icon: Texture2D = b.get_meta("icon")
	var mod := Color.WHITE if (afford or maxed) else Color(0.7, 0.7, 0.72)
	if icon:
		b.draw_texture_rect(icon, Rect2(1, 2, 16, 16), false, mod)
	var font := PixelFont.font_for_size(8)
	var name_col := TourUi.INK if not locked else TourUi.INK_SOFT
	b.draw_string(font, Vector2(20, 10), u["name"] if not locked else "???", HORIZONTAL_ALIGNMENT_LEFT, 116, 8, name_col)
	var lv := Game.level(id)
	TinyText.draw(b, Vector2(20, 13), "LV %d/%d" % [lv, int(u["max"])], TourUi.GREEN_DARK if lv > 0 else TourUi.INK_SOFT)
	var cost_txt := "MAX" if maxed else "$" + TourFormat.money(Game.cost(id))
	var w := TinyText.width(cost_txt)
	TinyText.draw(b, Vector2(r.size.x - w - 3, 13), cost_txt, TourUi.GREEN_DARK if afford else (TourUi.GOLD.darkened(0.3) if maxed else TourUi.RED))


func _show_info(id: String) -> void:
	_hover = id
	if id == "":
		_info_title.text = ""
		_info.text = "Hover an upgrade."
		return
	var u := FortuneData.upgrade(id)
	_info_title.text = u["name"]
	var extra := ""
	if u.has("needs") and not Game.available(id):
		extra = "\nNeeds %s first." % FortuneData.upgrade(u["needs"])["name"]
	_info.text = String(u["desc"]) + extra
