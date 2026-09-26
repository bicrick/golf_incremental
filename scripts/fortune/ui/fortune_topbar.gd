class_name FortuneTopBar
extends Control
## v9 top bar: the cash counter (rolling, bumping), income per second, active
## buffs, room tabs, and the $1,000,000 goal.

signal room_selected(id: String)
signal buy_range

var current := "tee"
var coin_bump := 0.0
var _shown := 0.0
var _rate := 0.0
var _hist: Array = [] ## [time, earned]
var _t := 0.0
var _tabs: Array[Dictionary] = []
var _font: Font
var _font16: Font
var _hover_tab := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = PixelFont.font_for_size(8)
	_font16 = PixelFont.font_for_size(16)
	_shown = Game.cash


func _process(delta: float) -> void:
	_t += delta
	_shown = lerpf(_shown, Game.cash, clampf(delta * 9.0, 0.0, 1.0))
	if absf(_shown - Game.cash) < 0.01 * maxf(Game.cash, 1.0):
		_shown = Game.cash
	coin_bump = maxf(coin_bump - delta * 4.0, 0.0)
	_hist.append([_t, Game.earned])
	while _hist.size() > 2 and _t - float(_hist[0][0]) > 5.0:
		_hist.pop_front()
	if _hist.size() > 1:
		var dt := float(_hist[-1][0]) - float(_hist[0][0])
		_rate = (float(_hist[-1][1]) - float(_hist[0][1])) / maxf(dt, 0.1)
	queue_redraw()


func _tab_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var x := 150.0
	for r in FortuneData.ROOMS:
		out.append(Rect2(x, 3, 43, 17))
		x += 45.0
	return out


func _gui_input(event: InputEvent) -> void:
	var rects := _tab_rects()
	if event is InputEventMouseMotion:
		_hover_tab = -1
		for i in rects.size():
			if rects[i].has_point((event as InputEventMouseMotion).position):
				_hover_tab = i
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := (event as InputEventMouseButton).position
		for i in rects.size():
			if rects[i].has_point(p):
				_click_tab(i)
				accept_event()
				return
		if _goal_rect().has_point(p) and Game.cash >= FortuneData.GOAL and not Game.has_won:
			buy_range.emit()
			accept_event()


func _has_point(p: Vector2) -> bool:
	return p.y < 24.0


func _click_tab(i: int) -> void:
	var r: Dictionary = FortuneData.ROOMS[i]
	if Game.rooms.get(r["id"], false):
		room_selected.emit(r["id"])
		Audio.play("ui_tick")
	elif Game.unlock_room(r["id"]):
		Audio.play("star")
		room_selected.emit(r["id"])
	else:
		Audio.play("ui_error")


func _goal_rect() -> Rect2:
	return Rect2(334, 3, 143, 17)


func _draw() -> void:
	## Bar background.
	draw_rect(Rect2(0, 0, 480, 24), Color(0.1, 0.08, 0.12, 0.72))
	draw_rect(Rect2(0, 23, 480, 1), Color(0.0, 0.0, 0.0, 0.5))
	draw_rect(Rect2(0, 24, 330, 11), Color(0.1, 0.08, 0.12, 0.45))
	## Cash.
	var s := 1.0 + coin_bump * 0.12
	var cash_text := "$" + TourFormat.money(_shown)
	draw_set_transform(Vector2(6, 19), 0.0, Vector2(s, s))
	draw_string_outline(_font16, Vector2.ZERO, cash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0.1, 0.06, 0.02))
	draw_string(_font16, Vector2.ZERO, cash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.86, 0.3).lerp(Color.WHITE, coin_bump * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	TinyText.draw(self, Vector2(8, 26), "%s/S" % TourFormat.money(_rate), Color(0.85, 1.0, 0.75), Color(0.05, 0.05, 0.08, 0.8))
	## Buffs (under the cash).
	var bx := 48.0
	var m := Game.global_mult()
	if m > 1.001:
		TinyText.draw(self, Vector2(bx, 26), "x%s ALL" % TourFormat.mult(m), Color(1.0, 0.8, 0.4), Color(0.05, 0.05, 0.08, 0.8))
		bx += 46
	for b in Game.buffs:
		var frac := float(b["t"]) / maxf(float(b["total"]), 0.01)
		draw_rect(Rect2(bx, 26, 30, 5), Color(0.1, 0.08, 0.12, 0.8))
		draw_rect(Rect2(bx, 26, 30 * frac, 5), Color(1.0, 0.7, 0.3))
		TinyText.draw(self, Vector2(bx + 1, 32), String(b["name"]).to_upper(), Color(1, 0.9, 0.7), Color(0.05, 0.05, 0.08, 0.8))
		bx += 36
	if Game.frenzy > 0.0:
		TinyText.draw(self, Vector2(bx, 26), "FRENZY %.0fS" % Game.frenzy, Color(0.6, 1.0, 0.6), Color(0.05, 0.05, 0.08, 0.8))
	## Tabs.
	var rects := _tab_rects()
	for i in rects.size():
		var r: Dictionary = FortuneData.ROOMS[i]
		var rect := rects[i]
		var open: bool = Game.rooms.get(r["id"], false)
		var active: bool = r["id"] == current
		var can := not open and Game.cash >= float(r["unlock"])
		var fill := TourUi.PAPER if active else (Color(0.3, 0.26, 0.32) if open else Color(0.2, 0.17, 0.22))
		if can:
			fill = Color(0.35, 0.55, 0.3).lerp(Color(0.5, 0.75, 0.4), 0.5 + 0.5 * sin(_t * 6.0))
		if i == _hover_tab and not active:
			fill = fill.lightened(0.15)
		draw_rect(rect, TourUi.INK)
		draw_rect(rect.grow(-1), fill)
		var label: String = String(r["name"]).split(" ")[0].to_upper() if open else "$" + TourFormat.money(float(r["unlock"]))
		if r["id"] == "dice" and open:
			label = "19TH"
		var tc := TourUi.INK if active else (Color(0.95, 0.92, 0.85) if open or can else Color(0.6, 0.55, 0.6))
		TinyText.draw(self, rect.position + Vector2((rect.size.x - TinyText.width(label)) * 0.5, 6), label, tc)
	## Goal.
	var g := _goal_rect()
	var frac2 := clampf(Game.cash / FortuneData.GOAL, 0.0, 1.0)
	draw_rect(g, TourUi.INK)
	draw_rect(g.grow(-1), Color(0.22, 0.2, 0.25))
	var fill_r := g.grow(-2)
	fill_r.size.x *= frac2
	var ready := Game.cash >= FortuneData.GOAL and not Game.has_won
	draw_rect(fill_r, Color(1.0, 0.8, 0.3) if ready else Color(0.45, 0.75, 0.4))
	var gt := "BUY THE RANGE!" if ready else ("THE RANGE IS YOURS" if Game.has_won else "GOAL $1,000,000")
	if ready and int(_t * 3.0) % 2 == 0:
		gt = "> BUY THE RANGE <"
	TinyText.draw(self, g.position + Vector2((g.size.x - TinyText.width(gt)) * 0.5, 6), gt, Color(1, 1, 1), Color(0.05, 0.05, 0.08, 0.8))
