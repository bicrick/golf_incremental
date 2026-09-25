class_name TourMap
extends Control
## v8 "The Road": the paper map between ranges. travel() animates the route to
## the next stop; browse() lets you pick any range you've reached.

signal travel_done(index: int)
signal closed

const STOPS := [Vector2(96, 206), Vector2(70, 124), Vector2(214, 162), Vector2(322, 92), Vector2(418, 50)]
const TOKEN := "res://assets/sprites/tour/token.png"

var _paper: Texture2D
var _token: Texture2D
var _from := 0
var _to := 0
var _progress := 1.0
var _browsing := false
var _busy := false
var _t := 0.0
var _title: Label
var _button: Button
var _hover := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_paper = load("res://assets/sprites/tour/map.png")
	_token = load(TOKEN)
	_title = TourUi.outlined(TourUi.label("THE ROAD", 16, TourUi.PAPER_HI), TourUi.INK, 4)
	_title.position = Vector2(150, 10)
	_title.size = Vector2(180, 20)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_button = TourUi.button("Onward", TourUi.GREEN)
	_button.position = Vector2(206, 240)
	_button.custom_minimum_size = Vector2(68, 18)
	_button.pressed.connect(_on_button)
	add_child(_button)


func is_blocking() -> bool:
	return visible


func travel(from: int, to: int) -> void:
	_from = from
	_to = to
	_progress = 0.0
	_browsing = false
	_busy = true
	_button.visible = false
	_button.text = "Onward"
	_open()
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(self, "_progress", 1.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_busy = false
		_button.visible = true
		Audio.play("travel")
	)


func browse() -> void:
	_from = Tour.range_index
	_to = Tour.range_index
	_progress = 1.0
	_browsing = true
	_busy = false
	_button.visible = true
	_button.text = "Close"
	_open()


func _open() -> void:
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	Audio.play("page")


func _close_then(cb: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		visible = false
		cb.call()
	)


func _on_button() -> void:
	if _busy:
		return
	if _browsing:
		_close_then(func() -> void: closed.emit())
	else:
		## Swap the range in behind the paper, then lift the map off it.
		travel_done.emit(_to)
		_close_then(func() -> void: pass)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _stop_at((event as InputEventMouseMotion).position)
	if _browsing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _stop_at((event as InputEventMouseButton).position)
		if i >= 0 and i <= Tour.unlocked_range and i != Tour.range_index:
			_browsing = false
			travel_done.emit(i)
			_close_then(func() -> void: pass)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE, KEY_M]:
		_on_button()
		get_viewport().set_input_as_handled()


func _stop_at(p: Vector2) -> int:
	for i in STOPS.size():
		if p.distance_to(STOPS[i]) < 12.0:
			return i
	return -1


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	draw_texture(_paper, Vector2.ZERO)
	var font := PixelFont.font_for_size(8)
	var reached := Tour.unlocked_range
	## Route: solid dots to where you've been, the travelling leg animated.
	for i in range(STOPS.size() - 1):
		var a: Vector2 = STOPS[i]
		var b: Vector2 = STOPS[i + 1]
		var frac := 0.0
		if i < _from or (i < reached and _browsing):
			frac = 1.0
		elif i == _from and _to == i + 1:
			frac = _progress
		var steps := int(a.distance_to(b) / 5.0)
		for s in steps:
			var t := float(s) / steps
			var p := _route(a, b, t, i)
			var col := TourUi.RED if t <= frac and frac > 0.0 else Color(TourUi.INK_SOFT, 0.35)
			draw_rect(Rect2(p.floor(), Vector2(2, 2)), col)
	for i in STOPS.size():
		var p: Vector2 = STOPS[i]
		var r := TourData.get_range(i)
		var known := i <= reached or (i == _to and _progress >= 1.0)
		var cleared: bool = Tour.cleared.get(r["id"], false)
		## Flag marker.
		var flag_col := TourUi.PINK if cleared else (TourUi.RED if known else Color(TourUi.INK_SOFT, 0.6))
		draw_line(p, p + Vector2(0, -12), TourUi.INK, 1.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(1, -12), p + Vector2(8, -9), p + Vector2(1, -6)]), flag_col)
		draw_circle(p + Vector2(0.5, 0.5), 2.5, TourUi.INK)
		var name: String = ("%s  %s" % [r["numeral"], r["name"]]) if known else "%s  ???" % r["numeral"]
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var lp := p + Vector2(-w * 0.5, 14)
		lp.x = clampf(lp.x, 4, 476 - w)
		var lc := TourUi.INK if known else TourUi.INK_SOFT
		if i == _hover and _browsing and i <= reached:
			lc = TourUi.RED
		draw_string_outline(font, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, TourUi.PAPER)
		draw_string(font, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, lc)
		if known:
			var stars := "%d/%d" % [Tour.stars_in_range(i), (r["greens"] as Array).size()]
			TinyText.draw(self, p + Vector2(10, -12), stars, TourUi.GOLD.darkened(0.35), TourUi.PAPER)
	## The rat token.
	var pos: Vector2 = STOPS[_from]
	if _to == _from + 1:
		pos = _route(STOPS[_from], STOPS[_to], _progress, _from)
	elif _progress >= 1.0:
		pos = STOPS[_to]
	var hop := -absf(sin(_t * 8.0)) * 2.0 if _busy else 0.0
	draw_texture(_token, (pos + Vector2(-8, -28 + hop)).round())


func _route(a: Vector2, b: Vector2, t: float, i: int) -> Vector2:
	var mid := (a + b) * 0.5 + Vector2(0, -18 if i % 2 == 0 else 14)
	return a.lerp(mid, t).lerp(mid.lerp(b, t), t)
