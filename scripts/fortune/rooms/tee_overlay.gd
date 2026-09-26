class_name TeeOverlay
extends Node2D
## v9 Tee Line 2D layer: golfers down the line, balls (true size, tracers,
## Perfect sparks), the pin flag and ring labels, coins that burst on landing
## and fly up to the cash counter, floating payouts, timing ring, weather.

const RAT_BALL := Vector2(46, 45)
const RATINA_BALL := Vector2(40, 45)
const COIN_TARGET := Vector2(40, 12)

var tee: TeeLine
var font: Font
var sprites: Array[AnimatedSprite2D] = []
var _sparks: Array[Dictionary] = []
var _flyers: Array[Dictionary] = [] ## coins flying to the counter
var _weather: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _flag_tex: Texture2D
var _popup := {"text": "", "color": Color.WHITE, "t": 99.0}
var _shake := 0.0
var _rat_frames: SpriteFrames
var _ratina_frames: SpriteFrames
var coin_landed := 0.0 ## counter bump signal for the HUD
var show_labels := true ## ring / PIN labels (off behind the title)


func setup(t: TeeLine) -> void:
	tee = t
	font = PixelFont.font_for_size(8)
	_flag_tex = load("res://assets/sprites/tour/flag_red.png")
	_rat_frames = RangeRatSpriteFrames.make_golfer_frames()
	_ratina_frames = _make_ratina_frames()
	tee.swing_resolved.connect(_on_swing)
	tee.ball_scored.connect(_on_scored)
	for i in 60:
		_weather.append(_spawn_mote(true))


func _make_ratina_frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	var idle: Texture2D = load("res://assets/sprites/ratina/ratina-idle-sheet.png")
	var swing: Texture2D = load("res://assets/sprites/ratina/ratina-swing-sheet.png")
	f.add_animation(&"idle")
	f.set_animation_speed(&"idle", 2.5)
	for i in 11:
		var a := AtlasTexture.new()
		a.atlas = idle
		a.region = Rect2((i % 4) * 52, (i / 4) * 52, 52, 52)
		f.add_frame(&"idle", a)
	f.add_animation(&"swing")
	f.set_animation_loop(&"swing", false)
	f.set_animation_speed(&"swing", 30.0)
	for i in 17:
		var a2 := AtlasTexture.new()
		a2.atlas = swing
		a2.region = Rect2((i % 5) * 52, (i / 5) * 52, 52, 52)
		f.add_frame(&"swing", a2)
	return f


func _on_swing(tier: int, err: float) -> void:
	var text: String = FortuneTier.name(tier)
	if tier > 0:
		text += "  early" if err < 0.0 else "  late"
	_popup = {"text": text, "color": FortuneTier.color(tier), "t": 0.0}
	if tier == 0:
		_shake = maxf(_shake, 1.2)


func _on_scored(_amount: float, ring: int, pos: Vector3, golden: bool) -> void:
	if ring >= 2 or golden:
		_shake = maxf(_shake, 1.0 + ring)
	if tee.camera.is_position_behind(pos):
		return
	var sp := tee.camera.unproject_position(pos)
	var n := 1 + maxi(ring, 0) + (2 if golden else 0)
	for i in n:
		_flyers.append({"from": sp, "t": -i * 0.05, "ctrl": sp + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-80, -30)),
			"gold": golden or ring >= 2})


# --- frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_shake = maxf(_shake - delta * 10.0, 0.0)
	position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake
	_popup["t"] = float(_popup["t"]) + delta
	for sp in _sparks:
		sp["t"] = float(sp["t"]) + delta
		sp["pos"] = (sp["pos"] as Vector2) + (sp["v"] as Vector2) * delta
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return float(sp["t"]) < float(sp["life"]))
	for f in _flyers:
		f["t"] = float(f["t"]) + delta * 1.6
	var arrived := _flyers.filter(func(f: Dictionary) -> bool: return float(f["t"]) >= 1.0)
	if not arrived.is_empty():
		coin_landed = 1.0
	_flyers = _flyers.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.0)
	var groove := 0.75 + Audio.energy * 0.7
	for p in _weather:
		p["pos"] = (p["pos"] as Vector2) + (p["v"] as Vector2) * delta * groove + Vector2(sin(tee.time_s + float(p["seed"])) * 4.0 * delta, 0)
		var pos: Vector2 = p["pos"]
		if pos.y > 274 or pos.x > 486 or pos.x < -6 or pos.y < -8:
			p.merge(_spawn_mote(false), true)
	_sync_sprites()
	queue_redraw()


func _spawn_mote(anywhere: bool) -> Dictionary:
	var kind: String = tee.look.get("weather", "pollen") if tee != null else "pollen"
	var p := {"pos": Vector2(_rng.randf_range(0, 480), _rng.randf_range(0, 270) if anywhere else -4.0), "seed": _rng.randf() * 10.0}
	match kind:
		"snow":
			p["v"] = Vector2(_rng.randf_range(-6, 4), _rng.randf_range(12, 26))
			p["color"] = Color(1, 1, 1, _rng.randf_range(0.5, 0.95))
		"dust":
			p["v"] = Vector2(_rng.randf_range(10, 26), _rng.randf_range(-1, 3))
			p["color"] = Color(1.0, 0.85, 0.6, _rng.randf_range(0.25, 0.5))
		"motes":
			p["v"] = Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-5, -1))
			p["color"] = Color(1.0, 0.92, 0.8, _rng.randf_range(0.3, 0.8))
			if not anywhere:
				p["pos"] = Vector2(_rng.randf_range(0, 480), 274)
		"spray":
			p["v"] = Vector2(_rng.randf_range(-14, -6), _rng.randf_range(-2, 4))
			p["color"] = Color(1, 1, 1, _rng.randf_range(0.3, 0.6))
		_:
			p["v"] = Vector2(_rng.randf_range(4, 12), _rng.randf_range(2, 8))
			p["color"] = Color(1.0, 0.85, 0.9, 0.85) if _rng.randf() < 0.3 else Color(1.0, 0.95, 0.7, 0.7)
	return p


## One sprite per golfer, placed at their bay's projection and scaled by distance.
func _sync_sprites() -> void:
	while sprites.size() < tee.golfers.size():
		var g: Dictionary = tee.golfers[sprites.size()]
		var s := AnimatedSprite2D.new()
		s.sprite_frames = _ratina_frames if g["kind"] == "ratina" else _rat_frames
		s.centered = false
		s.modulate = g["tint"]
		s.play(&"idle")
		add_child(s)
		sprites.append(s)
	var ref := tee.camera.global_position.distance_to(tee.bay_pos(0))
	for i in sprites.size():
		var g: Dictionary = tee.golfers[i]
		var s := sprites[i]
		var bp := tee.bay_pos(i)
		var sp := tee.camera.unproject_position(bp)
		var k := clampf(ref / tee.camera.global_position.distance_to(bp), 0.3, 1.2)
		var off: Vector2 = RATINA_BALL if g["kind"] == "ratina" else RAT_BALL
		s.scale = Vector2(k, k)
		s.position = sp - off * k
		s.z_index = -i
		var swing_t := float(g["swing_t"])
		if i == 0 and tee.charging:
			s.animation = &"swing"
			s.pause()
			s.frame = clampi(int(tee.windup_progress() * RangeRatSpriteFrames.WINDUP_LAST), 0, RangeRatSpriteFrames.WINDUP_LAST)
		elif swing_t >= 0.0:
			if s.animation != &"swing" or s.is_playing() == false and swing_t < 0.05:
				s.animation = &"swing"
			var contact := RangeRatSpriteFrames.CONTACT_FRAME if g["kind"] != "ratina" else 12
			var frame := int(swing_t * 30.0) if i > 0 else contact + int(swing_t * 14.0)
			s.pause()
			s.frame = clampi(frame, 0, 16)
		elif s.animation != &"idle":
			s.play(&"idle")


# --- draw ---------------------------------------------------------------------------------

func _proj(p: Vector3) -> Vector2:
	return tee.camera.unproject_position(p)


func _vis(p: Vector3) -> bool:
	return not tee.camera.is_position_behind(p)


func _ball_radius(p: Vector3) -> float:
	var f := 135.0 / tan(deg_to_rad(TeeLine.FOV * 0.5))
	return 0.0235 * f / maxf(tee.camera.global_position.distance_to(p), 0.1)


func _draw() -> void:
	if tee == null:
		return
	for i in _weather.size():
		if i % 3 == 0:
			var p: Dictionary = _weather[i]
			draw_circle(p["pos"], 0.9, p["color"])
	_draw_target()
	for pf in tee.puffs:
		_draw_puff(pf)
	for c in tee.coins:
		_draw_coins(c)
	for b in tee.flying:
		_draw_ball_flight(b)
	for sp in _sparks:
		var t := float(sp["t"]) / float(sp["life"])
		var c := Color(1.0, 0.86, 0.45, 1.0 - t)
		var s := 1.5 * (1.0 - t) + 0.5
		draw_line(sp["pos"] - Vector2(s, 0), sp["pos"] + Vector2(s, 0), c, 0.8, true)
		draw_line(sp["pos"] - Vector2(0, s), sp["pos"] + Vector2(0, s), c, 0.8, true)
	_draw_floaters()
	for i in _weather.size():
		if i % 3 != 0:
			var p: Dictionary = _weather[i]
			draw_circle(p["pos"], 0.8, p["color"])
	_draw_tee_ball()
	_draw_popup()
	_draw_flyers()


func _draw_target() -> void:
	var c := Vector3(0, 0, -FortuneEcon.TARGET_Z)
	if not _vis(c):
		return
	var sp := _proj(c).round()
	var h := _flag_tex.get_height()
	draw_texture_rect_region(_flag_tex, Rect2(sp + Vector2(-4, -h + 1), Vector2(15, h)), Rect2(15 * (int(tee.time_s * 2.2) % 2), 0, 15, h))
	if not show_labels:
		return
	## Ring labels, floating at each ring's near edge.
	var labels := ["x1", "x2", "x5"]
	for r in 3:
		var rad := FortuneEcon.ring_radius(Game.levels, r)
		var p := _proj(Vector3(rad * 0.72, 0, -FortuneEcon.TARGET_Z + rad * 0.72))
		TinyText.draw(self, p, labels[r], Color(1, 1, 1, 0.85), Color(0.1, 0.1, 0.12, 0.6))
	var pin := "PIN x%d" % int(FortuneEcon.ring_mult(Game.levels, 3))
	TinyText.draw(self, sp + Vector2(10, -h + 10), pin, Color(1.0, 0.55, 0.5), Color(0.1, 0.1, 0.12, 0.7))


func _draw_ball_flight(b: Dictionary) -> void:
	if float(b["t"]) <= 0.0:
		return
	var p: Vector3 = b["pos"]
	if not _vis(p):
		return
	var tier := int(b["tier"])
	var golden := bool(b["golden"])
	var trail: Array = b["trail"]
	var col := Color(1.0, 0.82, 0.35) if (tier == 0 or golden) else (Color(0.7, 0.9, 1.0) if tier == 1 else Color(1, 1, 1))
	var width := 2.6 if (tier == 0 or golden) else (1.8 if tier == 1 else 1.2)
	var n := trail.size()
	for i in range(1, n):
		var p0: Vector3 = trail[i - 1]
		var p1: Vector3 = trail[i]
		if not (_vis(p0) and _vis(p1)):
			continue
		var f := float(i) / n
		var a := f * f * (0.7 if tier <= 1 or golden else 0.4)
		var a0 := _proj(p0)
		var a1 := _proj(p1)
		if tier == 0 or golden:
			draw_line(a0, a1, Color(col.r, col.g, col.b, a * 0.25), width * f * 2.6, true)
		draw_line(a0, a1, Color(col.r, col.g, col.b, a), maxf(width * f, 0.6), true)
	var sp := _proj(p)
	var r := maxf(_ball_radius(p), 0.55)
	var bc := Color(1.0, 0.86, 0.3) if golden else Color(1, 1, 1)
	draw_circle(sp, r + 1.8, Color(bc.r, bc.g, bc.b, 0.16))
	draw_circle(sp, r, bc)
	if (tier == 0 or golden) and _rng.randf() < 0.6:
		_sparks.append({"pos": sp, "v": Vector2(_rng.randf_range(-6, 6), _rng.randf_range(4, 16)), "t": 0.0, "life": _rng.randf_range(0.4, 0.9)})


func _draw_puff(pf: Dictionary) -> void:
	var p: Vector3 = pf["pos"]
	if not _vis(p):
		return
	var t := float(pf["t"]) / 0.8
	var sp := _proj(p)
	var scale := clampf(_ball_radius(p) * 8.0, 1.5, 8.0)
	var tint := TourLooks.c(tee.look.get("fairway_a", "5fa83c")).lightened(0.35)
	for i in 7:
		var ang := -PI * (0.1 + 0.8 * float(i) / 6.0)
		var d := scale * (0.4 + t * 1.4)
		draw_circle(sp + Vector2(cos(ang) * d * 1.6, sin(ang) * d * (1.2 - t)), maxf(scale * 0.2 * (1.0 - t), 0.5), Color(tint, (1.0 - t) * 0.8))


## Coins pop up where a ball lands, spin and fall back.
func _draw_coins(c: Dictionary) -> void:
	var p: Vector3 = c["pos"]
	if not _vis(p):
		return
	var t := float(c["t"])
	var sp := _proj(p)
	var n := int(c["n"])
	var seed := float(c["seed"])
	for i in n:
		var a := seed + i * 2.399
		var vx := cos(a) * (8.0 + (i % 3) * 4.0)
		var vy := -26.0 - (i % 4) * 6.0
		var q := sp + Vector2(vx * t, vy * t + 60.0 * t * t)
		var w := absf(cos(t * 14.0 + i)) * 2.2 + 0.4
		var col := Color(1.0, 0.84, 0.3, clampf(1.6 - t * 1.6, 0.0, 1.0)) if c["gold"] or i % 2 == 0 else Color(1.0, 0.95, 0.6, clampf(1.6 - t * 1.6, 0.0, 1.0))
		draw_set_transform(q, 0.0, Vector2(w / 2.2, 1.0))
		draw_circle(Vector2.ZERO, 2.2, Color(0.55, 0.38, 0.1, col.a))
		draw_circle(Vector2.ZERO, 1.7, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_flyers() -> void:
	for f in _flyers:
		var t := float(f["t"])
		if t < 0.0:
			continue
		var e := t * t
		var from: Vector2 = f["from"]
		var ctrl: Vector2 = f["ctrl"]
		var q := from.lerp(ctrl, e).lerp(ctrl.lerp(COIN_TARGET, e), e)
		var col := Color(1.0, 0.84, 0.3) if f["gold"] else Color(1.0, 0.95, 0.65)
		draw_circle(q, 2.4, Color(col.r, col.g, col.b, 0.25))
		draw_circle(q, 1.6, col)


func _draw_floaters() -> void:
	for f in tee.floaters:
		var p: Vector3 = f["pos"]
		if not _vis(p):
			continue
		var t := float(f["t"])
		var life := float(f.get("life", 1.2))
		var sp := _proj(p) + Vector2(0, -t * 18.0 - (10.0 if f["big"] else 0.0))
		var a := clampf((life - t) / 0.35, 0.0, 1.0)
		var col: Color = f["color"]
		col.a *= a
		var text: String = f["text"]
		var sz := 16 if f["big"] and t < 0.12 else 8
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var pos := (sp - Vector2(w * 0.5, 0)).round()
		pos.x = clampf(pos.x, 2, 330 - w)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.08, 0.06, 0.1, a))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _draw_tee_ball() -> void:
	var tp := _proj(tee.bay_pos(0))
	var has_ball := tee.charging or tee.cooldown <= 0.0
	if has_ball:
		var r := _ball_radius(tee.bay_pos(0))
		draw_set_transform(tp + Vector2(0, r * 0.8), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, r * 1.3, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(tp - Vector2(0, r * 0.4), r, Color(1, 1, 1))
	if tee.charging:
		var t := tee.charge_t
		var target := FortuneEcon.WINDUP_SEC
		var r2 := lerpf(26.0, 4.0, clampf(t / target, 0.0, 1.0))
		if t > target:
			r2 = 4.0 - (t - target) * 12.0
		var tier := FortuneEcon.tier_for_error(absf(t - target) * 1000.0, FortuneEcon.window_scale(Game.levels))
		var col := FortuneTier.color(tier) if tier <= 1 else Color(1, 1, 1, 0.9)
		draw_arc(tp, 4.0, 0, TAU, 16, Color(1.0, 0.86, 0.3, 0.6), 1.0, true)
		if r2 > 0.5:
			draw_arc(tp, r2, 0, TAU, 28, col, 1.2, true)
	elif tee.cooldown > 0.0:
		var frac := tee.cooldown / maxf(tee.player_cooldown(), 0.01)
		draw_arc(tp, 5.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - frac), 20, Color(1, 1, 1, 0.5), 1.0, true)


func _draw_popup() -> void:
	var t := float(_popup["t"])
	if t > 1.0:
		return
	var tp := _proj(tee.bay_pos(0))
	var a := clampf((1.0 - t) / 0.3, 0.0, 1.0)
	var col: Color = _popup["color"]
	col.a = a
	var pos := (tp + Vector2(16, -30 - minf(t, 0.25) * 14.0)).round()
	draw_string_outline(font, pos, _popup["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.08, 0.06, 0.1, a))
	draw_string(font, pos, _popup["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
