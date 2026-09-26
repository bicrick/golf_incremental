class_name PuttingGreen
extends FortuneRoom
## v9 Putting Green: a pachinko board of pegs. Click to drop a putt; it
## rattles down into one of eight cups. A golden JACKPOT hole slides along
## the bottom — catch it for ×25 and +1% to everything, forever. PIN hits on
## the Tee Line drop golden putts here (×10).

signal jackpot

const BOARD := Rect2(8, 20, 306, 204)
const TOP_Y := 30.0
const CUP_Y := 196.0
const BALL_R := 3.0
const PEG_R := 2.2
const GRAVITY := 300.0
const MANUAL_COOLDOWN := 0.8
const SUBSTEPS := 4

var pegs: Array[Vector2] = []
var balls: Array[Dictionary] = [] ## {p, v, golden, hits}
var cup_flash: Array[float] = []
var jackpot_x := 0.5 ## 0..1 across the cups
var golden_queue := 0
var _cool := 0.0
var _auto_t := 1.0
var _golden_t := 0.0
var _jack_flash := 0.0
var _hover_x := -1.0
var _peg_flash := {}


func setup() -> void:
	room_id = "green"
	for r in 9:
		var y := 48.0 + r * 16.0
		var count := 10 if r % 2 == 0 else 9
		for c in count:
			pegs.append(Vector2(161.0 + (c - (count - 1) * 0.5) * 29.0, y))
	cup_flash.resize(FortuneEcon.CUP_MULTS.size())
	cup_flash.fill(0.0)
	Game.upgrades_changed.connect(queue_redraw)


func cup_left() -> float:
	return BOARD.position.x + 6.0


func cup_w() -> float:
	return (BOARD.size.x - 12.0) / FortuneEcon.CUP_MULTS.size()


func jackpot_center() -> float:
	return cup_left() + jackpot_x * (BOARD.size.x - 12.0)


func drop(x: float, golden: bool = false) -> void:
	var cx := clampf(x, BOARD.position.x + 12.0, BOARD.end.x - 12.0)
	balls.append({"p": Vector2(cx + _rng.randf_range(-1.5, 1.5), TOP_Y), "v": Vector2(_rng.randf_range(-8, 8), 0),
		"golden": golden, "hits": 0})
	Game.bump("putts")


## A player drop: honours the short cooldown; Double Drop fans extra putts.
func player_drop(x: float) -> bool:
	if _cool > 0.0:
		return false
	_cool = MANUAL_COOLDOWN
	_multi_drop(x)
	Audio.play("ui_tick", 1.3)
	if int(Game.stats["putts"]) > 4:
		Game.flags["green_hint"] = true
	return true


func _multi_drop(x: float) -> void:
	var n := FortuneEcon.putts_per_drop(Game.levels)
	for i in n:
		drop(x + (float(i) - (n - 1) * 0.5) * 9.0)


func add_golden(n: int = 1) -> void:
	golden_queue += n


func tick(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	_jack_flash = maxf(_jack_flash - delta * 1.5, 0.0)
	## The jackpot hole glides back and forth (a smooth ping-pong).
	jackpot_x = 0.5 + 0.5 * sin(t * 0.9) * 0.96
	for i in cup_flash.size():
		cup_flash[i] = maxf(cup_flash[i] - delta * 2.5, 0.0)
	for k in _peg_flash.keys():
		_peg_flash[k] = float(_peg_flash[k]) - delta * 4.0
		if float(_peg_flash[k]) <= 0.0:
			_peg_flash.erase(k)
	var ai := FortuneEcon.putt_auto_interval(Game.levels)
	if ai > 0.0:
		_auto_t -= delta
		if _auto_t <= 0.0:
			_auto_t = ai
			_multi_drop(_rng.randf_range(BOARD.position.x + 40.0, BOARD.end.x - 40.0))
	if golden_queue > 0:
		_golden_t -= delta
		if _golden_t <= 0.0:
			_golden_t = 0.18
			golden_queue -= 1
			drop(_rng.randf_range(120.0, 202.0), true)
	var h := delta / SUBSTEPS
	for s in SUBSTEPS:
		_step(h)


func _step(h: float) -> void:
	var done: Array[Dictionary] = []
	var bump := FortuneEcon.bumper_pay(Game.levels)
	for b in balls:
		var v: Vector2 = b["v"]
		var p: Vector2 = b["p"]
		v.y += GRAVITY * h
		p += v * h
		for i in pegs.size():
			var d := p - pegs[i]
			var min_d := BALL_R + PEG_R
			if d.length_squared() < min_d * min_d:
				var n := d.normalized() if d.length_squared() > 0.0001 else Vector2(_rng.randf_range(-1, 1), -1).normalized()
				p = pegs[i] + n * min_d
				var vn := v.dot(n)
				if vn < 0.0:
					v -= n * vn * 1.5
					v.x += _rng.randf_range(-22.0, 22.0)
					v *= 0.8
					if not _peg_flash.has(i) or float(_peg_flash[i]) < 0.5:
						_peg_flash[i] = 1.0
						b["hits"] = int(b["hits"]) + 1
						if bump > 0.0:
							Game.earn(bump, "green")
						if visible and _rng.randf() < 0.5:
							Audio.play_plink(int(b["hits"]))
		var lo := BOARD.position.x + 5.0 + BALL_R
		var hi := BOARD.end.x - 5.0 - BALL_R
		if p.x < lo:
			p.x = lo
			v.x = absf(v.x) * 0.6
		elif p.x > hi:
			p.x = hi
			v.x = -absf(v.x) * 0.6
		v.x = clampf(v.x, -120.0, 120.0)
		b["v"] = v
		b["p"] = p
		if p.y >= CUP_Y:
			_score(b)
			done.append(b)
	for b in done:
		balls.erase(b)


func _score(b: Dictionary) -> void:
	var p: Vector2 = b["p"]
	var golden := bool(b["golden"])
	var base := FortuneEcon.putt_value(Game.levels) * (5.0 if golden else 1.0)
	var half := FortuneEcon.jackpot_width(Game.levels) * 0.5
	if absf(p.x - jackpot_center()) <= half:
		var paid := Game.earn(base * FortuneEcon.jackpot_mult(Game.levels), "green")
		Game.add_permanent(FortuneEcon.jackpot_permanent(int(Game.stats["jackpots"])), "JACKPOT!")
		Game.bump("jackpots")
		_jack_flash = 1.0
		pop(Vector2(jackpot_center(), CUP_Y - 8), "JACKPOT +$" + TourFormat.money(paid), Color(1.0, 0.85, 0.3), true)
		jackpot.emit()
		Audio.play("ace")
		return
	var cup := clampi(int((p.x - cup_left()) / cup_w()), 0, FortuneEcon.CUP_MULTS.size() - 1)
	var paid2 := Game.earn(base * FortuneEcon.cup_mult(Game.levels, cup), "green")
	cup_flash[cup] = 1.0
	var col := Color(1.0, 0.85, 0.3) if golden else (Color(1, 1, 0.7) if FortuneEcon.CUP_MULTS[cup] >= 2.0 else Color(1, 1, 1))
	pop(Vector2(cup_left() + (cup + 0.5) * cup_w(), CUP_Y - 6), "+$" + TourFormat.money(paid2), col, golden)
	if visible:
		Audio.play("green" if FortuneEcon.CUP_MULTS[cup] >= 2.0 or golden else "land", 1.0 + 0.05 * cup)


# --- input ------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_x = (event as InputEventMouseMotion).position.x
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		player_drop((event as InputEventMouseButton).position.x)
		accept_event()


func key_drop() -> void:
	player_drop(_hover_x if _hover_x >= 0.0 else 161.0 + _rng.randf_range(-20, 20))


# --- draw ---------------------------------------------------------------------------------

func _draw() -> void:
	var auto := FortuneEcon.putt_auto_interval(Game.levels)
	draw_header("PUTTING GREEN", "PUTT $%s%s" % [TourFormat.money(FortuneEcon.putt_value(Game.levels) * Game.global_mult()),
		("   RATTLING %.1fS" % auto) if auto > 0.0 else ""])
	## Board: a deep green, mown in stripes, with a wooden rim.
	var b := BOARD
	draw_rect(b.grow(3), Color(0.32, 0.2, 0.12))
	draw_rect(b.grow(2), Color(0.5, 0.33, 0.18))
	draw_rect(b, Color(0.2, 0.46, 0.24))
	for i in 12:
		if i % 2 == 0:
			draw_rect(Rect2(b.position.x, b.position.y + i * b.size.y / 12.0, b.size.x, b.size.y / 12.0), Color(1, 1, 1, 0.035))
	## Drop guide.
	if _hover_x >= b.position.x and _hover_x <= b.end.x:
		var gx := clampf(_hover_x, b.position.x + 12.0, b.end.x - 12.0)
		for y in range(int(TOP_Y), int(TOP_Y) + 14, 3):
			draw_rect(Rect2(gx, y, 1, 1), Color(1, 1, 1, 0.5 if _cool <= 0.0 else 0.2))
		draw_circle(Vector2(gx, TOP_Y), BALL_R, Color(1, 1, 1, 0.35 if _cool <= 0.0 else 0.12))
	## Pegs.
	for i in pegs.size():
		var fl := float(_peg_flash.get(i, 0.0))
		draw_circle(pegs[i] + Vector2(0.6, 1.2), PEG_R, Color(0, 0, 0, 0.3))
		draw_circle(pegs[i], PEG_R + fl * 0.8, Color(0.93, 0.93, 0.88).lerp(Color(1.0, 0.9, 0.4), fl))
	## Cups.
	var cw := cup_w()
	for i in FortuneEcon.CUP_MULTS.size():
		var r := Rect2(cup_left() + i * cw + 1, CUP_Y, cw - 2, 22)
		var m := FortuneEcon.CUP_MULTS[i]
		var base := Color(0.12, 0.3, 0.16) if m < 1.0 else (Color(0.16, 0.36, 0.2) if m < 2.0 else Color(0.22, 0.42, 0.22))
		draw_rect(r, base.lerp(Color(0.9, 1.0, 0.7), cup_flash[i] * 0.6))
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Color(0.06, 0.12, 0.08))
		var label := "x" + TourFormat.mult(FortuneEcon.cup_mult(Game.levels, i))
		TinyText.draw(self, Vector2(r.position.x + (r.size.x - TinyText.width(label)) * 0.5, r.position.y + 9), label,
			Color(1, 1, 0.8) if m >= 2.0 else Color(0.85, 0.95, 0.85), Color(0, 0, 0, 0.5))
		if i > 0:
			draw_rect(Rect2(cup_left() + i * cw - 1, CUP_Y - 4, 2, 26), Color(0.93, 0.93, 0.88))
	## The sliding jackpot hole.
	var jw := FortuneEcon.jackpot_width(Game.levels)
	var jx := jackpot_center()
	var glow := 0.5 + 0.5 * sin(t * 8.0)
	draw_rect(Rect2(jx - jw * 0.5 - 2, CUP_Y - 7, jw + 4, 6), Color(1.0, 0.8, 0.25, 0.3 + 0.3 * glow + _jack_flash * 0.4))
	draw_rect(Rect2(jx - jw * 0.5, CUP_Y - 6, jw, 4), Color(1.0, 0.85, 0.3).lerp(Color.WHITE, _jack_flash))
	TinyText.draw(self, Vector2(jx - TinyText.width("JACKPOT") * 0.5, CUP_Y - 13), "JACKPOT", Color(1.0, 0.9, 0.4), Color(0.1, 0.05, 0, 0.7))
	if _jack_flash > 0.0:
		draw_rect(b, Color(1.0, 0.9, 0.5, _jack_flash * 0.25))
	## Balls.
	for ball in balls:
		var p: Vector2 = ball["p"]
		var golden := bool(ball["golden"])
		draw_circle(p + Vector2(1, 1.5), BALL_R, Color(0, 0, 0, 0.3))
		if golden:
			draw_circle(p, BALL_R + 2.0, Color(1.0, 0.85, 0.3, 0.3))
		draw_circle(p, BALL_R, Color(1.0, 0.85, 0.3) if golden else Color(1, 1, 1))
		draw_circle(p + Vector2(-0.8, -0.8), 1.0, Color(1, 1, 1, 0.8))
	if golden_queue > 0:
		TinyText.draw(self, Vector2(b.position.x + 4, b.position.y + 4), "GOLDEN PUTTS x%d" % golden_queue, Color(1.0, 0.85, 0.3), Color(0, 0, 0, 0.5))
	if not Game.flags.get("green_hint", false):
		text_c(161, 46, "Click to drop a putt", Color(1, 1, 1, 0.5 + 0.5 * sin(t * 4.0)))
	draw_pops()
