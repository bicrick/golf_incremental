class_name Scorecards
extends FortuneRoom
## v9 Scorecards: buy a card, scratch the foil hole by hole. Par pays a
## little, birdies more, eagles a lot — every birdie or better sends the Tee
## Line into a frenzy, and a hole in one is +5% to everything, forever.

signal ace

const CARD := Rect2(12, 24, 298, 150)
const LABEL_W := 36.0
const CELL_W := 28.0
const BLOCK := Vector2(4, 4)
const BLOCKS_X := 6
const BLOCKS_Y := 4
const SCRATCH_R := 7.0
const REVEAL_AT := 0.55
const PARS := [4, 3, 5, 4, 4, 3, 5, 4, 4, 4, 5, 3, 4, 4, 3, 5, 4, 4]

var card: Dictionary = {} ## {price, holes: [{par, outcome, revealed, foil: PackedByteArray}], paid}
var _auto_t := 2.0
var _scratching := false
var _owl_pop := {"text": "", "t": 9.0}
var _sparkles: Array[Dictionary] = []
var _buy_rect := Rect2(12, 212, 128, 20)


func setup() -> void:
	room_id = "cards"


func price() -> float:
	return FortuneEcon.card_price(Game.levels)


func card_done() -> bool:
	if card.is_empty():
		return true
	for h in card["holes"]:
		if not h["revealed"]:
			return false
	return true


func roll_outcome() -> int:
	var odds := FortuneEcon.card_odds(Game.levels)
	var r := _rng.randf()
	for i in odds.size():
		r -= odds[i]
		if r <= 0.0:
			return i
	return 0


func buy_card() -> bool:
	if not card_done():
		return false
	var p := price()
	if not Game.spend(p):
		Audio.play("ui_error")
		return false
	var holes: Array[Dictionary] = []
	for i in FortuneEcon.card_holes(Game.levels):
		var foil := PackedByteArray()
		foil.resize(BLOCKS_X * BLOCKS_Y)
		foil.fill(1)
		var o := roll_outcome()
		var par: int = PARS[i]
		if o == 4:
			par = 3 ## a hole in one reads best on a par 3
		elif o == 3 and par == 3:
			par = 4
		holes.append({"par": par, "outcome": o, "revealed": false, "foil": foil})
	card = {"price": p, "holes": holes, "won": 0.0}
	Game.bump("cards")
	Audio.play("page")
	return true


## Pays one hole. Shared by your card and the Owl's.
func _pay_hole(outcome: int, card_price: float, pos: Vector2, show: bool) -> float:
	var paid := Game.earn(FortuneEcon.CARD_PAYS[outcome] * card_price, "cards")
	if outcome >= 2:
		Game.frenzy = minf(Game.frenzy + FortuneEcon.frenzy_sec(Game.levels), FortuneEcon.FRENZY_CAP)
	if outcome == 4:
		Game.bump("aces")
		Game.add_permanent(FortuneEcon.ACE_PERMANENT, "HOLE IN ONE!")
		ace.emit()
		if show:
			Audio.play("ace")
	if show:
		var col: Color = [Color(0.8, 0.8, 0.8), Color(1, 1, 1), Color(1.0, 0.6, 0.55), Color(1.0, 0.8, 0.35), Color(1.0, 0.9, 0.3)][outcome]
		var label: String = FortuneEcon.CARD_OUTCOMES[outcome]
		if paid > 0.0:
			label += "  +$" + TourFormat.money(paid)
		pop(pos, label, col, outcome == 4)
		if outcome >= 2:
			Audio.play("star" if outcome >= 3 else "green")
	return paid


func reveal(i: int) -> void:
	var h: Dictionary = card["holes"][i]
	if h["revealed"]:
		return
	h["revealed"] = true
	var r := cell_rect(i)
	card["won"] = float(card["won"]) + _pay_hole(int(h["outcome"]), float(card["price"]), r.get_center() + Vector2(0, -8), true)
	for k in 8:
		_sparkles.append({"p": r.get_center() + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-6, 6)),
			"v": Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-40, -5)), "t": 0.0})
	Audio.play("ui_tick", 1.6)
	if card_done():
		Audio.play("buy")


func reveal_next() -> void:
	if card.is_empty():
		return
	for i in card["holes"].size():
		if not card["holes"][i]["revealed"]:
			reveal(i)
			return


## Space: buy a card when none is in play, otherwise scratch the next hole.
func key_action() -> void:
	if card_done():
		buy_card()
	else:
		reveal_next()


func tick(delta: float) -> void:
	_owl_pop["t"] = float(_owl_pop["t"]) + delta
	for s in _sparkles:
		s["t"] = float(s["t"]) + delta
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
		s["v"] = (s["v"] as Vector2) + Vector2(0, 90) * delta
	_sparkles = _sparkles.filter(func(s: Dictionary) -> bool: return float(s["t"]) < 0.6)
	var ai := FortuneEcon.card_auto_interval(Game.levels)
	if ai > 0.0:
		_auto_t -= delta
		if _auto_t <= 0.0:
			_auto_t = ai
			_owl_card()


## The Old Owl buys and scratches a whole card in one go.
func _owl_card() -> void:
	var p := price()
	if not Game.spend(p):
		return
	Game.bump("cards")
	var won := 0.0
	var best := 0
	for i in FortuneEcon.card_holes(Game.levels):
		var o := roll_outcome()
		best = maxi(best, o)
		won += _pay_hole(o, p, Vector2.ZERO, false)
	_owl_pop = {"text": "OWL  +$%s%s" % [TourFormat.money(won), ("  " + FortuneEcon.CARD_OUTCOMES[best].to_upper()) if best >= 2 else ""],
		"t": 0.0, "best": best}
	if best == 4 and visible:
		Audio.play("ace")


# --- layout -------------------------------------------------------------------------------

func _rows() -> int:
	return 2 if FortuneEcon.card_holes(Game.levels) > 9 else 1


func cell_rect(i: int) -> Rect2:
	var block := i / 9
	var col := i % 9
	var y0 := CARD.position.y + 22.0 + block * 60.0
	return Rect2(CARD.position.x + 8.0 + LABEL_W + col * CELL_W, y0 + 26.0, CELL_W - 2.0, 20.0)


# --- input ----------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if _buy_rect.has_point(mb.position) and card_done():
				buy_card()
			else:
				_scratching = true
				_scratch_at(mb.position)
		else:
			_scratching = false
		accept_event()
	elif event is InputEventMouseMotion and _scratching:
		var mm := event as InputEventMouseMotion
		## Scratch along the whole stroke so fast swipes don't skip.
		var from := mm.position - mm.relative
		var steps := maxi(int(mm.relative.length() / 3.0), 1)
		for k in steps + 1:
			_scratch_at(from.lerp(mm.position, float(k) / steps))


func _scratch_at(p: Vector2) -> void:
	if card.is_empty():
		return
	for i in card["holes"].size():
		var h: Dictionary = card["holes"][i]
		if h["revealed"]:
			continue
		var r := cell_rect(i)
		if not r.grow(SCRATCH_R).has_point(p):
			continue
		var foil: PackedByteArray = h["foil"]
		var cleared := 0
		for by in BLOCKS_Y:
			for bx in BLOCKS_X:
				var k := by * BLOCKS_X + bx
				var c := r.position + Vector2((bx + 0.5) * r.size.x / BLOCKS_X, (by + 0.5) * r.size.y / BLOCKS_Y)
				if foil[k] == 1 and c.distance_to(p) < SCRATCH_R:
					foil[k] = 0
					if _rng.randf() < 0.25:
						_sparkles.append({"p": c, "v": Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-30, 0)), "t": 0.3})
				if foil[k] == 0:
					cleared += 1
		h["foil"] = foil
		if float(cleared) / (BLOCKS_X * BLOCKS_Y) >= REVEAL_AT:
			reveal(i)


# --- draw -----------------------------------------------------------------------------------

func _draw() -> void:
	var ai := FortuneEcon.card_auto_interval(Game.levels)
	draw_header("SCORECARDS", "CARD $%s%s" % [TourFormat.money(price()), ("   OWL %.1fS" % ai) if ai > 0.0 else ""])
	## A felt-topped clubhouse desk.
	draw_rect(Rect2(0, 16, size.x, size.y - 16), Color(0.24, 0.16, 0.12, 0.92))
	for i in 7:
		draw_rect(Rect2(0, 16 + i * 32, size.x, 1), Color(0, 0, 0, 0.15))
	if card.is_empty():
		_draw_empty_card()
	else:
		_draw_card()
	_draw_footer()
	if int(Game.stats["cards"]) < 2 and not card.is_empty():
		text_c(161, 186, "Drag to scratch   (Space: next hole)", Color(1, 1, 1, 0.6 + 0.4 * sin(t * 4.0)))
	for s in _sparkles:
		var a := 1.0 - float(s["t"]) / 0.6
		draw_rect(Rect2((s["p"] as Vector2).round(), Vector2.ONE), Color(0.9, 0.9, 0.95, a))
	if float(_owl_pop["t"]) < 2.0:
		var a2 := clampf((2.0 - float(_owl_pop["t"])) / 0.4, 0.0, 1.0)
		var col := Color(1.0, 0.85, 0.35, a2) if int(_owl_pop.get("best", 0)) >= 2 else Color(0.9, 0.95, 1.0, a2)
		text(Vector2(160, 226 - minf(float(_owl_pop["t"]), 0.3) * 20.0), _owl_pop["text"], col)
	draw_pops()


func _draw_empty_card() -> void:
	var r := Rect2(CARD.position + Vector2(40, 30), Vector2(CARD.size.x - 80, 90))
	draw_rect(r.grow(1), Color(0, 0, 0, 0.35))
	draw_rect(r, Color(0.96, 0.93, 0.84, 0.25))
	text_c(r.get_center().x, r.position.y + 36, "Buy a card and scratch it", Color(1, 1, 1, 0.9))
	text_c(r.get_center().x, r.position.y + 52, "Birdies start a Tee Line FRENZY", Color(1.0, 0.8, 0.5, 0.9))
	text_c(r.get_center().x, r.position.y + 68, "Hole in one: +3% forever", Color(1.0, 0.9, 0.4, 0.9))


func _draw_card() -> void:
	var rows := _rows()
	var r := Rect2(CARD.position, Vector2(CARD.size.x, 34.0 + rows * 60.0))
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, TourUi.PAPER)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 18)), TourUi.GREEN_DARK)
	text(r.position + Vector2(6, 13), "RANGE RAT CLUB", TourUi.PAPER_HI, 8, TourUi.INK)
	TinyText.draw(self, r.position + Vector2(r.size.x - 70, 7), "PRICE $" + TourFormat.money(float(card["price"])), TourUi.PAPER_HI)
	var holes: Array = card["holes"]
	for block in rows:
		var y0 := CARD.position.y + 22.0 + block * 60.0
		var x0 := CARD.position.x + 8.0
		TinyText.draw(self, Vector2(x0, y0 + 3), "HOLE", TourUi.INK_SOFT)
		TinyText.draw(self, Vector2(x0, y0 + 15), "PAR", TourUi.INK_SOFT)
		TinyText.draw(self, Vector2(x0, y0 + 33), "SCORE", TourUi.INK)
		for col in 9:
			var i := block * 9 + col
			if i >= holes.size():
				break
			var h: Dictionary = holes[i]
			var cx := x0 + LABEL_W + col * CELL_W
			draw_rect(Rect2(cx - 1, y0, 1, 48), TourUi.PAPER_DIM)
			var hn := str(i + 1)
			TinyText.draw(self, Vector2(cx + (CELL_W - 2 - TinyText.width(hn)) * 0.5, y0 + 3), hn, TourUi.INK_SOFT)
			var pn := str(int(h["par"]))
			TinyText.draw(self, Vector2(cx + (CELL_W - 2 - TinyText.width(pn)) * 0.5, y0 + 15), pn, TourUi.INK)
			_draw_cell(i, h)
		draw_rect(Rect2(x0, y0 + 11, LABEL_W + 9 * CELL_W - 2, 1), TourUi.PAPER_DIM)
		draw_rect(Rect2(x0, y0 + 23, LABEL_W + 9 * CELL_W - 2, 1), TourUi.PAPER_DIM)


func _draw_cell(i: int, h: Dictionary) -> void:
	var r := cell_rect(i)
	var o := int(h["outcome"])
	var par := int(h["par"])
	var score: int = [par + 1, par, par - 1, par - 2, 1][o]
	var c := r.get_center()
	## The score underneath, in scorecard notation.
	match o:
		0:
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), TourUi.INK_SOFT, false, 1.0)
		2:
			draw_arc(c, 6.5, 0, TAU, 20, TourUi.RED, 1.0, true)
		3:
			draw_arc(c, 6.5, 0, TAU, 20, TourUi.RED, 1.0, true)
			draw_arc(c, 8.5, 0, TAU, 24, TourUi.RED, 1.0, true)
		4:
			draw_circle(c, 9.0, Color(1.0, 0.82, 0.3, 0.6 + 0.3 * sin(t * 6.0)))
	var s := str(score)
	var col := TourUi.INK_SOFT if o == 0 else (TourUi.RED if o >= 2 and o < 4 else TourUi.INK)
	draw_string(font, Vector2(c.x - font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x * 0.5, c.y + 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	if h["revealed"]:
		return
	## Silver foil, in scratchable blocks.
	var foil: PackedByteArray = h["foil"]
	var bw := r.size.x / BLOCKS_X
	var bh := r.size.y / BLOCKS_Y
	for by in BLOCKS_Y:
		for bx in BLOCKS_X:
			if foil[by * BLOCKS_X + bx] == 1:
				var shade := 0.72 + 0.08 * float((bx + by) % 2) + 0.06 * sin(t * 3.0 + bx * 0.7 + by)
				draw_rect(Rect2(r.position + Vector2(bx * bw, by * bh), Vector2(ceil(bw), ceil(bh))), Color(shade, shade, shade + 0.04))
	if foil.count(1) == foil.size():
		draw_string(font, Vector2(c.x - 3, c.y + 3), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.55, 0.6))


func _draw_footer() -> void:
	var done := card_done()
	var can := Game.cash >= price()
	_buy_rect = Rect2(12, 210, 128, 20)
	var fill := TourUi.GREEN if (done and can) else Color(0.35, 0.3, 0.32)
	if done and can:
		fill = fill.lerp(Color(0.45, 0.7, 0.45), 0.5 + 0.5 * sin(t * 5.0))
	draw_rect(_buy_rect, TourUi.INK)
	draw_rect(_buy_rect.grow(-1), fill)
	var label := ("BUY CARD $" + TourFormat.money(price())) if done else "SCRATCH IT!"
	text_c(_buy_rect.get_center().x, _buy_rect.position.y + 14, label, TourUi.PAPER_HI)
	if not card.is_empty():
		var won := float(card["won"])
		var net := won - float(card["price"])
		var s := ("THIS CARD +$" if net >= 0.0 else "THIS CARD $") + TourFormat.money(won)
		TinyText.draw(self, Vector2(150, 206), s, Color(0.85, 1.0, 0.75) if net >= 0.0 else Color(1, 0.8, 0.75), Color(0, 0, 0, 0.5))
	var legend := "PAR x%s  BIRDIE x%s  EAGLE x%s  ACE x%s" % [TourFormat.mult(FortuneEcon.CARD_PAYS[1]),
		TourFormat.mult(FortuneEcon.CARD_PAYS[2]), TourFormat.mult(FortuneEcon.CARD_PAYS[3]), TourFormat.mult(FortuneEcon.CARD_PAYS[4])]
	TinyText.draw(self, Vector2(12, 194), legend, Color(1, 0.95, 0.85, 0.85), Color(0, 0, 0, 0.5))
