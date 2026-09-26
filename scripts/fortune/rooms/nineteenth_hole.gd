class_name NineteenthHole
extends FortuneRoom
## v9 19th Hole: roll the dice at the clubhouse bar. Pips pay; doubles double
## everything for a while, boxcars ×5, triples (with the third die) ×10, and
## snake eyes is +3% to everything, forever.

signal rolled(kind: String)

const ROLL_SEC := 0.7
const DIE := 30.0

var dice: Array[int] = [1, 1]
var rolling := 0.0 ## > 0 while tumbling
var cooldown := 0.0
var _auto_t := 3.0
var _flash := 0.0
var _result := {"text": "", "t": 9.0, "color": Color.WHITE}
var _tumble: Array[Vector2] = []
var _roll_rect := Rect2(111, 186, 100, 22)
var _by_toad := false


func setup() -> void:
	room_id = "dice"


func can_roll() -> bool:
	return rolling <= 0.0 and cooldown <= 0.0


func roll(by_toad: bool = false) -> bool:
	if not can_roll():
		return false
	_by_toad = by_toad
	var n := FortuneEcon.dice_count(Game.levels)
	while dice.size() < n:
		dice.append(_rng.randi_range(1, 6))
	if visible:
		rolling = ROLL_SEC
		Audio.play("page", 0.8)
		_tumble.clear()
		for i in n:
			_tumble.append(Vector2(_rng.randf_range(-80, 80), _rng.randf_range(-60, -20)))
	else:
		rolling = 0.0001
	return true


func _settle() -> void:
	var n := FortuneEcon.dice_count(Game.levels)
	dice.resize(n)
	for i in n:
		dice[i] = _rng.randi_range(1, 6)
	## Loaded dice: sometimes the second die follows the first.
	if _rng.randf() < FortuneEcon.loaded_chance(Game.levels):
		dice[1] = dice[0]
	cooldown = FortuneEcon.dice_cooldown(Game.levels)
	var pips := 0
	var counts := {}
	for d in dice:
		pips += d
		counts[d] = int(counts.get(d, 0)) + 1
	var paid := Game.earn(pips * FortuneEcon.pip_value(Game.levels), "dice")
	var best := 1
	var face := 0
	for k in counts:
		if int(counts[k]) > best:
			best = int(counts[k])
			face = int(k)
	var bs := FortuneEcon.buff_scale(Game.levels)
	var kind := "plain"
	var label := "+$" + TourFormat.money(paid)
	var col := Color(1, 1, 1)
	var cash_label := label
	if best >= 3:
		kind = "triples"
		Game.add_buff("Triples", 10.0, 30.0 * bs)
		label = "TRIPLES!  x10 ALL  " + label
		col = Color(1.0, 0.5, 0.9)
	elif best == 2 and face == 1:
		kind = "snake"
		Game.add_buff("Doubles", 2.0, 12.0 * bs)
		Game.add_permanent(FortuneEcon.SNAKE_EYES_PERMANENT, "SNAKE EYES!")
		label = "SNAKE EYES  " + label
		col = Color(0.6, 1.0, 0.6)
	elif best == 2 and face == 6:
		kind = "boxcars"
		Game.add_buff("Boxcars", 5.0, 10.0 * bs)
		label = "BOXCARS!  x5 ALL  " + label
		col = Color(1.0, 0.7, 0.3)
	elif best == 2:
		kind = "doubles"
		Game.add_buff("Doubles", 2.0, 12.0 * bs)
		label = "DOUBLES!  x2 ALL  " + label
		col = Color(1.0, 0.9, 0.4)
	if kind != "plain":
		Game.bump("doubles")
		_flash = 1.0
	## The banner names the combo; the table just shows the money.
	_result = {"text": cash_label, "t": 0.0, "color": col, "big": kind != "plain"}
	if visible:
		Audio.play("ace" if kind == "triples" else ("star" if kind != "plain" else "land"))
	rolled.emit(kind)


func tick(delta: float) -> void:
	_flash = maxf(_flash - delta * 1.5, 0.0)
	_result["t"] = float(_result["t"]) + delta
	if rolling > 0.0:
		rolling -= delta
		if rolling <= 0.0:
			rolling = 0.0
			_settle()
		elif int(rolling * 30.0) % 3 == 0:
			for i in dice.size():
				dice[i] = _rng.randi_range(1, 6)
		return
	cooldown = maxf(cooldown - delta, 0.0)
	var ai := FortuneEcon.dice_auto_interval(Game.levels)
	if ai > 0.0:
		_auto_t -= delta
		if _auto_t <= 0.0 and can_roll():
			_auto_t = ai
			roll(true)


static var _glow_tex: Texture2D


static func _glow() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_glow_tex = gt
	return _glow_tex


func key_action() -> void:
	if roll():
		Game.flags["dice_hint"] = true
	else:
		Audio.play("ui_error")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		key_action()
		accept_event()


# --- draw ---------------------------------------------------------------------------------

func _draw() -> void:
	var ai := FortuneEcon.dice_auto_interval(Game.levels)
	draw_header("19TH HOLE", "PIP $%s%s" % [TourFormat.money(FortuneEcon.pip_value(Game.levels) * Game.global_mult()),
		("   TOAD %.1fS" % ai) if ai > 0.0 else ""])
	## Lamplit bar: dark wood, a green baize mat.
	draw_rect(Rect2(0, 16, size.x, size.y - 16), Color(0.16, 0.1, 0.09, 0.94))
	for i in 12:
		draw_rect(Rect2(0, 16 + i * 19, size.x, 1), Color(0, 0, 0, 0.18))
	draw_texture_rect(_glow(), Rect2(161 - 170, 104 - 120, 340, 240), false, Color(1.0, 0.75, 0.4, 0.22 + 0.1 * _flash))
	var mat := Rect2(36, 40, 250, 130)
	draw_rect(mat.grow(3), Color(0.35, 0.22, 0.12))
	draw_rect(mat, Color(0.14, 0.36, 0.22).lerp(Color(0.5, 0.45, 0.2), _flash * 0.5))
	draw_rect(mat.grow(-6), Color(1, 1, 1, 0.04), false, 1.0)
	## Dice.
	var n := dice.size()
	for i in n:
		var home := Vector2(161 + (i - (n - 1) * 0.5) * (DIE + 18.0), 104)
		var p := home
		var rot := 0.0
		if rolling > 0.0 and i < _tumble.size():
			var k := rolling / ROLL_SEC
			p += _tumble[i] * k * k + Vector2(0, -sin(k * PI) * 18.0)
			rot = k * 9.0 + i
		_draw_die(p, rot, dice[i])
	## Result.
	if float(_result["t"]) < 2.4 and rolling <= 0.0:
		var a := clampf((2.4 - float(_result["t"])) / 0.4, 0.0, 1.0)
		var col: Color = _result["color"]
		col.a = a
		text_c(161, 158 - minf(float(_result["t"]), 0.2) * 16.0, _result["text"], col, 16 if _result.get("big", false) else 8)
	## Roll button with its cooldown.
	var ready := can_roll()
	var fill := Color(0.62, 0.2, 0.18) if ready else Color(0.3, 0.22, 0.22)
	if ready:
		fill = fill.lerp(Color(0.85, 0.35, 0.25), 0.5 + 0.5 * sin(t * 5.0))
	draw_rect(_roll_rect, TourUi.INK)
	draw_rect(_roll_rect.grow(-1), fill)
	if not ready and rolling <= 0.0:
		var frac := cooldown / maxf(FortuneEcon.dice_cooldown(Game.levels), 0.01)
		draw_rect(Rect2(_roll_rect.position + Vector2(1, 1), Vector2((_roll_rect.size.x - 2) * (1.0 - frac), _roll_rect.size.y - 2)), Color(0.5, 0.25, 0.22))
	text_c(_roll_rect.get_center().x, _roll_rect.position.y + 15, "ROLL" if ready else "...", TourUi.PAPER_HI)
	var legend := ["DOUBLES  x2 ALL %dS" % int(12 * FortuneEcon.buff_scale(Game.levels)),
		"BOXCARS  x5 ALL %dS" % int(10 * FortuneEcon.buff_scale(Game.levels)),
		"SNAKE EYES  +3% FOREVER"]
	if FortuneEcon.dice_count(Game.levels) >= 3:
		legend.append("TRIPLES  x10 ALL %dS" % int(30 * FortuneEcon.buff_scale(Game.levels)))
	for i in legend.size():
		TinyText.draw(self, Vector2(40 + (i % 2) * 130, 214 + (i / 2) * 9), legend[i], Color(1, 0.9, 0.75, 0.9), Color(0, 0, 0, 0.5))
	if not Game.flags.get("dice_hint", false):
		text_c(161, 34, "Click or Space to roll", Color(1, 1, 1, 0.6 + 0.4 * sin(t * 4.0)))
	draw_pops()


const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}


func _draw_die(c: Vector2, rot: float, face: int) -> void:
	draw_set_transform(c + Vector2(2, 4), rot, Vector2.ONE)
	draw_rect(Rect2(-DIE * 0.5, -DIE * 0.5, DIE, DIE), Color(0, 0, 0, 0.35))
	draw_set_transform(c, rot, Vector2.ONE)
	draw_rect(Rect2(-DIE * 0.5, -DIE * 0.5, DIE, DIE), Color(0.96, 0.93, 0.86))
	draw_rect(Rect2(-DIE * 0.5, DIE * 0.5 - 3, DIE, 3), Color(0.8, 0.75, 0.68))
	draw_rect(Rect2(-DIE * 0.5, -DIE * 0.5, DIE, DIE), TourUi.INK, false, 1.0)
	var pc := TourUi.RED if face == 1 else TourUi.INK
	for p in PIPS[face]:
		draw_circle((p as Vector2) * 8.0, 2.6 if face == 1 else 2.2, pc)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
