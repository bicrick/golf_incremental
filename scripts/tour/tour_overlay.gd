class_name TourOverlay
extends Node2D
## v8 — everything that must stay pixel-crisp is drawn here in 2D, projected
## from the 3D world: flags, reticle, balls, the rat, the timing ring, the
## cart, keepsakes, floating text and weather.

const TOUR := "res://assets/sprites/tour/"
const FLAG_W := 15
const RING_START_R := 26.0
const RING_TARGET_R := 4.0
const RAT_BALL_OFFSET := Vector2(38, 43) ## ball position inside a 52×52 rat frame

var world: TourWorld
var rat: AnimatedSprite2D
var ratina: AnimatedSprite2D
var font: Font
var _tex := {}
var _weather: Array[Dictionary] = []
var _weather_kind := ""
var _streaks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _flag_frame := 0
var _flag_timer := 0.0
var _shake := 0.0
var _critters: Array[Dictionary] = []
var _popup := {"text": "", "color": Color.WHITE, "t": 99.0}
var _critter_timer := 2.0


func setup(w: TourWorld) -> void:
	world = w
	font = PixelFont.font_for_size(8)
	for n in ["flag_red", "flag_pink", "lantern_off", "lantern_on", "cart"]:
		_tex[n] = load(TOUR + n + ".png")
	for k in TourData.all_keepsakes():
		_tex[k["id"]] = load(TOUR + k["id"] + ".png")
	_tex["sparkle"] = load("res://assets/sprites/tour/sparkle.png")
	rat = AnimatedSprite2D.new()
	rat.sprite_frames = RangeRatSpriteFrames.make_golfer_frames()
	rat.centered = false
	rat.position = Vector2(TourWorld.TEE_X, TourWorld.TEE_Y) - RAT_BALL_OFFSET
	rat.play(&"idle")
	add_child(rat)
	world.swing_resolved.connect(_on_swing)
	## Ratina, waiting at the Edge.
	ratina = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation(&"wait")
	frames.set_animation_speed(&"wait", 6.0)
	frames.set_animation_loop(&"wait", true)
	var sheet: Texture2D = load("res://assets/sprites/ratina/ratina-waiting-sheet.png")
	for i in 17:
		var a := AtlasTexture.new()
		a.atlas = sheet
		a.region = Rect2((i % 5) * 52, (i / 5) * 52, 52, 52)
		frames.add_frame(&"wait", a)
	frames.remove_animation(&"default")
	ratina.sprite_frames = frames
	ratina.centered = false
	ratina.position = Vector2(TourWorld.TEE_X - 118, TourWorld.TEE_Y - 46)
	ratina.play(&"wait")
	ratina.visible = false
	add_child(ratina)


func set_weather(kind: String) -> void:
	_critters.clear()
	_weather_kind = kind
	_weather.clear()
	for i in _weather_count():
		_weather.append(_spawn_particle(true))


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _weather_count() -> int:
	match _weather_kind:
		"snow":
			return 90
		"pollen":
			return 26
		"dust":
			return 30
		"motes":
			return 40
		"spray":
			return 18
	return 0


func _spawn_particle(anywhere: bool) -> Dictionary:
	var p := {
		"pos": Vector2(_rng.randf_range(0, 480), _rng.randf_range(0, 270) if anywhere else -4.0),
		"v": Vector2.ZERO, "seed": _rng.randf() * TAU, "size": 1,
	}
	match _weather_kind:
		"snow":
			p["v"] = Vector2(_rng.randf_range(-6, 4), _rng.randf_range(10, 24))
			p["size"] = 1 if _rng.randf() < 0.7 else 2
			p["color"] = Color(1, 1, 1, _rng.randf_range(0.55, 0.95))
		"pollen":
			p["v"] = Vector2(_rng.randf_range(3, 9), _rng.randf_range(-2, 2))
			p["color"] = Color(1.0, 0.95, 0.7, _rng.randf_range(0.5, 0.9))
		"dust":
			p["v"] = Vector2(_rng.randf_range(12, 30), _rng.randf_range(-1, 1))
			p["color"] = Color(1.0, 0.82, 0.6, _rng.randf_range(0.25, 0.55))
			if not anywhere:
				p["pos"] = Vector2(-4, _rng.randf_range(90, 270))
		"motes":
			p["v"] = Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-5, -1))
			p["color"] = Color(1.0, 0.92, 0.8, _rng.randf_range(0.3, 0.8))
			if not anywhere:
				p["pos"] = Vector2(_rng.randf_range(0, 480), 274)
		"spray":
			p["v"] = Vector2(_rng.randf_range(-14, -6), _rng.randf_range(-3, 3))
			p["color"] = Color(1, 1, 1, _rng.randf_range(0.3, 0.6))
			if not anywhere:
				p["pos"] = Vector2(484, _rng.randf_range(60, 200))
	return p


func _process(delta: float) -> void:
	_flag_timer += delta
	if _flag_timer > 0.45:
		_flag_timer = 0.0
		_flag_frame = 1 - _flag_frame
	_shake = maxf(_shake - delta * 12.0, 0.0)
	_popup["t"] = float(_popup["t"]) + delta
	position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake
	for p in _weather:
		var v: Vector2 = p["v"]
		var sway := sin(world.time_s * 1.3 + float(p["seed"])) * 6.0
		p["pos"] = (p["pos"] as Vector2) + (v + Vector2(sway, 0)) * delta
		var pos: Vector2 = p["pos"]
		if pos.y > 274 or pos.x > 486 or pos.x < -6 or pos.y < -8:
			var np := _spawn_particle(false)
			p.merge(np, true)
	_update_streaks(delta)
	_update_critters(delta)
	_update_rat()
	queue_redraw()


## Little life on each range: birds at dawn, gulls by the sea, a tumbleweed
## on the mesa, shooting stars over Frostpine.
func _update_critters(delta: float) -> void:
	var id: String = world.range_def.get("id", "")
	_critter_timer -= delta
	if _critter_timer <= 0.0 and world.mode == TourWorld.Mode.PLAY:
		_critter_timer = _rng.randf_range(4.0, 10.0)
		match id:
			"barley", "cliffs":
				var n := _rng.randi_range(1, 3 if id == "cliffs" else 4)
				var dir := 1.0 if _rng.randf() < 0.5 else -1.0
				var y := _rng.randf_range(18, 70)
				for i in n:
					_critters.append({"kind": "gull" if id == "cliffs" else "bird",
						"pos": Vector2(-10.0 if dir > 0 else 490.0, y) + Vector2(-dir * i * 9, i * 4 * (1 if i % 2 else -1)),
						"v": Vector2(dir * _rng.randf_range(18, 30), _rng.randf_range(-2, 2)), "seed": _rng.randf() * 10.0})
			"mesa":
				var z := _rng.randf_range(40, 220)
				var from_left := _rng.randf() < 0.5
				_critters.append({"kind": "tumble", "g": Vector2(-90.0 if from_left else 90.0, z),
					"v": Vector2(14.0 if from_left else -14.0, 0), "rot": 0.0, "seed": _rng.randf() * 10.0})
			"frost":
				if _rng.randf() < 0.6:
					_critters.append({"kind": "star", "pos": Vector2(_rng.randf_range(40, 440), _rng.randf_range(6, 40)),
						"v": Vector2(_rng.randf_range(-160, 160), _rng.randf_range(40, 70)), "t": 0.0})
	for c in _critters:
		match c["kind"]:
			"tumble":
				c["g"] = (c["g"] as Vector2) + (c["v"] as Vector2) * delta
				c["rot"] = float(c["rot"]) + delta * 5.0 * signf((c["v"] as Vector2).x)
			"star":
				c["t"] = float(c["t"]) + delta
				c["pos"] = (c["pos"] as Vector2) + (c["v"] as Vector2) * delta
			_:
				c["pos"] = (c["pos"] as Vector2) + (c["v"] as Vector2) * delta
	_critters = _critters.filter(func(c: Dictionary) -> bool:
		if c["kind"] == "tumble":
			return absf((c["g"] as Vector2).x) < 100.0
		if c["kind"] == "star":
			return float(c["t"]) < 0.7
		var p: Vector2 = c["pos"]
		return p.x > -30 and p.x < 510
	)
	if world.range_def.is_empty() or _critters.size() > 0 and id == "":
		_critters.clear()


func _draw_critters() -> void:
	for c in _critters:
		match c["kind"]:
			"bird", "gull":
				var p: Vector2 = (c["pos"] as Vector2).floor()
				var up := int(world.time_s * 6.0 + float(c["seed"])) % 2 == 0
				var col := Color(0.22, 0.16, 0.26) if c["kind"] == "bird" else Color(0.97, 0.98, 1.0)
				var w := 2 if c["kind"] == "bird" else 3
				for i in range(1, w + 1):
					var dy := -i if up else -1 + (1 if i == w else 0)
					draw_rect(Rect2(p + Vector2(-i, dy), Vector2.ONE), col)
					draw_rect(Rect2(p + Vector2(i, dy), Vector2.ONE), col)
				draw_rect(Rect2(p, Vector2.ONE), col)
			"tumble":
				var g: Vector2 = c["g"]
				var bounce := absf(sin(float(c["rot"]) * 0.8)) * 1.5
				var p3 := Vector3(g.x, bounce, -g.y)
				if not _visible_point(p3):
					continue
				var sp := _proj(p3).round()
				var r := clampf(260.0 / maxf(_cam_dist(p3), 1.0), 2.0, 6.0)
				draw_rect(Rect2(_proj(Vector3(g.x, 0, -g.y)).round() + Vector2(-r, 0), Vector2(r * 2, 1)), Color(0, 0, 0, 0.2))
				for i in 10:
					var a := float(c["rot"]) + float(i) * TAU / 10.0
					var pp := sp + Vector2(cos(a), sin(a) * 0.9) * r * (0.5 + 0.5 * float(i % 2))
					draw_rect(Rect2(pp.floor(), Vector2.ONE), Color(0.72, 0.56, 0.34))
				draw_arc(sp, r, 0, TAU, 10, Color(0.56, 0.42, 0.26), 1.0)
			"star":
				var p2: Vector2 = c["pos"]
				var dir := (c["v"] as Vector2).normalized()
				var a2 := 1.0 - float(c["t"]) / 0.7
				draw_line(p2, p2 - dir * 14.0, Color(1, 1, 1, a2 * 0.8), 1.0)
				draw_rect(Rect2(p2.floor(), Vector2.ONE), Color(1, 1, 1, a2))


func _update_streaks(delta: float) -> void:
	if world.range_def.get("mechanic", "") != "wind" or world.mode != TourWorld.Mode.PLAY:
		_streaks.clear()
		return
	var strength := clampf(absf(world.wind.x) / 7.0 + maxf(world.wind.y, 0.0) * 4.0, 0.1, 1.0)
	if _rng.randf() < strength * delta * 14.0:
		var dir := 1.0 if world.wind.x >= 0.0 else -1.0
		_streaks.append({
			"pos": Vector2(-30.0 if dir > 0 else 510.0, _rng.randf_range(20, 200)),
			"v": Vector2(dir * _rng.randf_range(160, 260), _rng.randf_range(-6, 6)),
			"len": _rng.randf_range(10, 26),
		})
	for s in _streaks:
		s["pos"] = (s["pos"] as Vector2) + (s["v"] as Vector2) * delta
	_streaks = _streaks.filter(func(s: Dictionary) -> bool: return (s["pos"] as Vector2).x > -60 and (s["pos"] as Vector2).x < 540)


# --- rat -------------------------------------------------------------------------

func _on_swing(tier: int, err: float) -> void:
	var text: String = TourData.TIER_NAMES[tier]
	if tier > 0:
		text += "  early" if err < 0.0 else "  late"
	_popup = {"text": text, "color": TourData.TIER_COLORS[tier], "t": 0.0}
	if tier == 0:
		shake(1.0)
	rat.animation = &"swing"
	rat.frame = RangeRatSpriteFrames.CONTACT_FRAME
	rat.pause()
	get_tree().create_timer(0.06).timeout.connect(func() -> void:
		if not world.charging:
			rat.play(&"follow")
	)


func _update_rat() -> void:
	rat.visible = world.mode == TourWorld.Mode.PLAY or world.mode == TourWorld.Mode.LOCKED
	ratina.visible = rat.visible and world.range_def.get("id", "") == "edge"
	if world.charging:
		rat.animation = &"swing"
		rat.pause()
		rat.frame = clampi(int(world.windup_progress() * RangeRatSpriteFrames.WINDUP_LAST), 0, RangeRatSpriteFrames.WINDUP_LAST)
		return
	if rat.animation == &"follow" and not rat.is_playing():
		if world.cooldown <= 0.0:
			rat.play(&"return_to_address")
	elif rat.animation == &"return_to_address" and not rat.is_playing():
		rat.play(&"idle" if Tour.bucket_remaining > 0 else &"idle_out_of_balls")
	elif rat.animation == &"idle" and Tour.bucket_remaining <= 0:
		rat.play(&"idle_out_of_balls")
	elif rat.animation == &"idle_out_of_balls" and Tour.bucket_remaining > 0:
		rat.play(&"idle")


# --- projection helpers ------------------------------------------------------------

func _proj(p: Vector3) -> Vector2:
	return world.camera.unproject_position(p)


func _visible_point(p: Vector3) -> bool:
	return not world.camera.is_position_behind(p)


func _ground(g: Vector2) -> Vector3:
	return Vector3(g.x, 0.0, -g.y)


func _cam_dist(p: Vector3) -> float:
	return world.camera.global_position.distance_to(p)


# --- draw -----------------------------------------------------------------------------

func _draw() -> void:
	if world == null or world.range_def.is_empty():
		return
	var playing := world.mode == TourWorld.Mode.PLAY
	var sweeping := world.mode == TourWorld.Mode.SWEEP or world.mode == TourWorld.Mode.TRANSITION
	_draw_weather(true)
	if playing:
		_draw_critters()
	_draw_flags()
	if playing and world.input_enabled:
		_draw_aim()
	_draw_resting()
	_draw_splashes()
	if sweeping:
		_draw_keepsakes()
		_draw_cart()
		_draw_offscreen_arrows()
	_draw_flying()
	_draw_floaters()
	for s in _streaks:
		var p: Vector2 = s["pos"]
		var dir := (s["v"] as Vector2).normalized()
		draw_line(p, p - dir * float(s["len"]), Color(1, 1, 1, 0.55), 1.0)
	_draw_weather(false)
	if playing:
		_draw_tee()
		_draw_popup()


func _draw_popup() -> void:
	var t := float(_popup["t"])
	var y := TourWorld.TEE_Y - 34.0
	if t < 1.1:
		var a := clampf((1.1 - t) / 0.3, 0.0, 1.0)
		var text: String = _popup["text"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var pos := Vector2(TourWorld.TEE_X + 18, y - minf(t, 0.25) * 16.0).round()
		var col: Color = _popup["color"]
		col.a = a
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.08, 0.06, 0.1, a))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	if Tour.streak >= 2:
		var cap := TourPhysics.streak_cap(Tour.levels)
		var st := "STREAK x%d" % mini(Tour.streak, cap)
		var sc := Color(1.0, 0.86, 0.3) if Tour.streak >= cap else Color(1, 1, 1, 0.9)
		TinyText.draw(self, Vector2(TourWorld.TEE_X + 18, TourWorld.TEE_Y - 24), st, sc, Color(0.08, 0.06, 0.1, 0.8))


func _draw_weather(back: bool) -> void:
	for i in _weather.size():
		if (i % 3 == 0) != back:
			continue
		var p: Dictionary = _weather[i]
		var s := int(p["size"])
		var pos: Vector2 = (p["pos"] as Vector2).floor()
		draw_rect(Rect2(pos, Vector2(s, s)), p["color"])


func _draw_flags() -> void:
	var list: Array = []
	for g in world.range_def["greens"]:
		if not world.green_visible(g):
			continue
		var base := _ground(Vector2(g["x"], g["z"]))
		if not _visible_point(base):
			continue
		list.append({"g": g, "base": base, "d": _cam_dist(base)})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d"] > b["d"])
	var aim := world.current_aim_option()
	var reach := Tour.reach()
	for item in list:
		var g: Dictionary = item["g"]
		var sp := _proj(item["base"]).round()
		var in_reach := Vector2(g["x"], g["z"]).length() <= reach * (1.0 + world._expected_roll()) + float(g["r"])
		var aimed: bool = aim.get("id", "") == g["id"] and world.mode == TourWorld.Mode.PLAY
		var starred: bool = Tour.stars.get(g["id"], false)
		var tex: Texture2D
		var frame_w := FLAG_W
		if g.get("lantern", false):
			tex = _tex["lantern_on"] if starred else _tex["lantern_off"]
			frame_w = tex.get_width()
		elif g.get("ratina", false):
			tex = _tex["flag_pink"]
		else:
			tex = _tex["flag_red"]
		var h := tex.get_height()
		var bob := -1.0 if aimed and int(world.time_s * 3.0) % 2 == 0 else 0.0
		var src := Rect2(frame_w * _flag_frame if tex.get_width() > frame_w else 0, 0, frame_w, h)
		var dst := Rect2(sp + Vector2(-4, -h + 1 + bob), Vector2(frame_w, h))
		var mod := Color(1, 1, 1, 1) if in_reach else Color(0.7, 0.7, 0.75, 0.75)
		if g.get("lantern", false) and starred:
			_draw_glow(sp + Vector2(-2, -h + 12), 14.0, Color(1.0, 0.8, 0.45, 0.22))
		draw_texture_rect_region(tex, dst, src, mod)
		if starred and not g.get("lantern", false):
			_draw_star(sp + Vector2(-4, -h - 3), Color(1.0, 0.86, 0.3))
		var label := TourFormat.yards(float(g["z"]))
		var lc := Color(1, 1, 1) if in_reach else Color(0.85, 0.85, 0.9, 0.8)
		if aimed:
			lc = Color(1.0, 0.92, 0.45)
		TinyText.draw(self, sp + Vector2(4, -h + 12 + bob), label, lc, Color(0.1, 0.1, 0.14, 0.85))


func _draw_star(c: Vector2, col: Color) -> void:
	var pts := [Vector2(0, -2), Vector2(-2, 0), Vector2(0, 2), Vector2(2, 0)]
	for p in pts:
		draw_rect(Rect2((c + p).floor(), Vector2.ONE), col)
	draw_rect(Rect2(c.floor() - Vector2(1, 1), Vector2(3, 3)), col)


func _draw_glow(c: Vector2, r: float, col: Color) -> void:
	for i in 3:
		var rr := r * (1.0 - i * 0.28)
		draw_circle(c, rr, Color(col.r, col.g, col.b, col.a * (0.6 + i * 0.4)))


func _draw_aim() -> void:
	var aim := world.aim_point()
	var land := world.expected_land(aim)
	var rest := world.expected_rest(land)
	var show_wind: bool = world.range_def.get("mechanic", "") == "wind"
	var show_roll: bool = float(world.range_def.get("roll", 0.0)) > 0.05
	## Trajectory preview: a dotted arc from the tee.
	var apex := clampf(aim.length() * 0.16, 2.0, 70.0)
	var pulse := fmod(world.time_s * 1.2, 1.0)
	for i in range(1, 14):
		var t := (float(i) + pulse) / 14.0
		var gp := Vector2.ZERO.lerp(aim, t)
		var p := Vector3(gp.x, apex * 4.0 * t * (1.0 - t), -gp.y)
		if not _visible_point(p):
			continue
		var sp := _proj(p).floor()
		var a := 0.45 + 0.45 * sin(t * PI)
		draw_rect(Rect2(sp + Vector2(1, 1), Vector2(1, 1)), Color(0.1, 0.08, 0.12, a * 0.6))
		draw_rect(Rect2(sp, Vector2(1, 1)), Color(1, 1, 1, a))
	_draw_reticle(aim, Color(1, 1, 1, 0.9), true)
	if show_wind and land.distance_to(aim) > 1.0:
		if Tour.level("wind") > 0:
			_draw_reticle(land, Color(0.7, 0.95, 1.0, 0.8), false)
	if show_roll and Tour.level("roll") > 0:
		for i in range(0, 8):
			var gp2 := land.lerp(rest, float(i) / 7.0)
			var sp2 := _proj(_ground(gp2)).floor()
			draw_rect(Rect2(sp2, Vector2(1, 1)), Color(1.0, 0.9, 0.6, 0.8))
		_draw_reticle(rest, Color(1.0, 0.85, 0.5, 0.8), false)


func _draw_reticle(g: Vector2, col: Color, main: bool) -> void:
	var c3 := _ground(g)
	if not _visible_point(c3):
		return
	## Ground ring (sized in yards, so it shows the landing zone honestly).
	var r := clampf(g.length() * 0.03, 2.5, 9.0)
	var pts := PackedVector2Array()
	for i in 17:
		var a := TAU * float(i) / 16.0
		pts.append(_proj(_ground(g + Vector2(cos(a), sin(a)) * r)).round())
	for i in range(0, 16, 1 if main else 2):
		draw_line(pts[i], pts[i + 1], Color(col, col.a * 0.7), 1.0)
	## Screen-space brackets so the target always reads.
	var c := _proj(c3).round()
	var s := 5.0 + (1.0 if main and int(world.time_s * 4.0) % 2 == 0 else 0.0)
	var ink := Color(0.1, 0.08, 0.12, 0.8)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := c + Vector2(sx * s, sy * s)
			for o in [Vector2(1, 1), Vector2.ZERO]:
				var cc := ink if o != Vector2.ZERO else col
				draw_rect(Rect2(corner + o - Vector2(0 if sx < 0 else 2, 0 if sy < 0 else 0), Vector2(3, 1)), cc)
				draw_rect(Rect2(corner + o - Vector2(0, 0 if sy < 0 else 2), Vector2(1, 3)), cc)
	if main:
		draw_rect(Rect2(c - Vector2(0, 0), Vector2(1, 1)), col)


func _ball_radius(p: Vector3) -> float:
	var d := _cam_dist(p)
	return clampf(160.0 / maxf(d, 1.0), 1.0, 3.0)


func _draw_ball(sp: Vector2, r: float, golden: bool, glow: bool) -> void:
	var col := Color(1.0, 0.86, 0.3) if golden else Color(1, 1, 1)
	if glow:
		_draw_glow(sp, r + 4.0, Color(col.r, col.g, col.b, 0.18))
	if r <= 1.2:
		draw_rect(Rect2(sp.floor(), Vector2(1, 1)), col)
		return
	var ri := int(round(r))
	draw_circle(sp.floor() + Vector2(0.5, 0.5), float(ri), col)
	draw_rect(Rect2(sp.floor() + Vector2(ri - 1, ri - 1) * 0.5, Vector2(1, 1)), col.darkened(0.25))


func _draw_resting() -> void:
	var night := float(world.look.get("darkness", 0.0)) > 0.5
	var arr: Array = world.resting + world._pulled
	for b in arr:
		var p: Vector3 = b["pos"]
		if not _visible_point(p):
			continue
		var sp := _proj(p)
		var r := _ball_radius(p)
		_draw_ball(sp, maxf(r - 0.5, 1.0), bool(b["golden"]), night)


func _draw_flying() -> void:
	var night := float(world.look.get("darkness", 0.0)) > 0.5
	for b in world.flying:
		var p: Vector3 = b["pos"]
		if not _visible_point(p):
			continue
		var golden := bool(b["golden"])
		## Trail.
		var trail: Array = b["trail"]
		for i in range(1, trail.size()):
			var a := float(i) / trail.size()
			var p0: Vector3 = trail[i - 1]
			var p1: Vector3 = trail[i]
			if _visible_point(p0) and _visible_point(p1):
				var tc := Color(1.0, 0.9, 0.5, a * 0.5) if golden else Color(1, 1, 1, a * 0.35)
				draw_line(_proj(p0), _proj(p1), tc, 1.0)
		## Shadow on the ground.
		var shadow := Vector3(p.x, 0.0, p.z)
		if _visible_point(shadow):
			var ss := _proj(shadow).floor()
			draw_rect(Rect2(ss - Vector2(1, 0), Vector2(3, 1)), Color(0, 0, 0, 0.28))
		_draw_ball(_proj(p), _ball_radius(p), golden, night or golden)


func _draw_splashes() -> void:
	for s in world.splashes:
		var t := float(s["t"])
		var sp := _proj(s["pos"])
		var water: bool = s["kind"] == "water"
		var col := Color(0.85, 0.95, 1.0, 1.0 - t) if water else Color(0.8, 0.5, 0.35, 1.0 - t)
		for i in 7:
			var a := -PI * float(i) / 6.0
			var r := 3.0 + t * 10.0
			var pp := sp + Vector2(cos(a) * r, sin(a) * r * 0.9 - t * 6.0 * (1.0 - t) * 4.0)
			draw_rect(Rect2(pp.floor(), Vector2(1, 1)), col)
		if water:
			draw_arc(sp, 2.0 + t * 8.0, 0, TAU, 12, Color(1, 1, 1, 0.6 * (1.0 - t)), 1.0)


func _draw_keepsakes() -> void:
	for k in world._visible_keepsakes():
		var p := _ground(Vector2(k["x"], k["z"]))
		if not _visible_point(p):
			continue
		var sp := _proj(p).round()
		var tex: Texture2D = _tex.get(k["id"])
		var bob := sin(world.time_s * 3.0 + float(k["z"])) * 1.5
		_draw_glow(sp + Vector2(0, -6), 9.0, Color(1.0, 0.95, 0.6, 0.18))
		if tex:
			draw_texture(tex, (sp + Vector2(-7, -16 + bob)).round())
		var sparkle: Texture2D = _tex["sparkle"]
		if int(world.time_s * 4.0 + float(k["z"])) % 3 == 0:
			draw_texture(sparkle, sp + Vector2(4, -20))


func _draw_cart() -> void:
	var p := _ground(world.cart_pos)
	if not _visible_point(p):
		return
	var sp := _proj(p).round()
	## Pickup radius, drawn on the ground.
	var r := world.cart_radius_world()
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		pts.append(_proj(_ground(world.cart_pos + Vector2(cos(a), sin(a)) * r)))
	for i in range(0, 24, 2):
		draw_line(pts[i], pts[i + 1], Color(1, 1, 1, 0.5), 1.0)
	var tex: Texture2D = _tex["cart"]
	var flip := cos(world.cart_heading) < -0.2
	var dst := Rect2(sp + Vector2(-12, -14), Vector2(24, 18))
	if flip:
		draw_set_transform(sp, 0.0, Vector2(-1, 1))
		draw_texture(tex, Vector2(-12, -14))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, dst, false)
	if world.chain > 1:
		TinyText.draw(self, sp + Vector2(10, -20), "x%d" % world.chain, Color(1.0, 0.92, 0.45), Color(0.1, 0.1, 0.1, 0.8))


## Little arrows on the screen edge pointing at balls and keepsakes you can't see.
func _draw_offscreen_arrows() -> void:
	var targets: Array = []
	for b in world.resting:
		targets.append([b["pos"], Color(1, 1, 1, 0.9)])
	for k in world._visible_keepsakes():
		targets.append([_ground(Vector2(k["x"], k["z"])), Color(1.0, 0.9, 0.5, 0.95)])
	var screen := Rect2(Vector2(10, 30), Vector2(460, 200))
	var center := Vector2(240, 135)
	for tgt in targets:
		var p: Vector3 = tgt[0]
		var sp: Vector2
		if world.camera.is_position_behind(p):
			sp = center + (center - _proj(p)) * 10.0
		else:
			sp = _proj(p)
		if screen.has_point(sp):
			continue
		var dir := (sp - center).normalized()
		## Walk from the centre to the edge of the inset rect.
		var tx := (screen.size.x * 0.5) / maxf(absf(dir.x), 0.001)
		var ty := (screen.size.y * 0.5) / maxf(absf(dir.y), 0.001)
		var edge := center + dir * minf(tx, ty)
		var side := Vector2(-dir.y, dir.x)
		var col: Color = tgt[1]
		var pts := PackedVector2Array([edge + dir * 4.0, edge - dir * 2.0 + side * 3.0, edge - dir * 2.0 - side * 3.0])
		draw_colored_polygon(pts, Color(0.08, 0.06, 0.1, 0.6))
		draw_colored_polygon(PackedVector2Array([pts[0] - dir, pts[1] - dir * 0.5 + side * -0.5, pts[2] - dir * 0.5 + side * 0.5]), col)


func _draw_floaters() -> void:
	for f in world.floaters:
		var t := float(f["t"])
		var life := 2.2 if f["big"] else 1.4
		var p: Vector3 = f["pos"]
		if not _visible_point(p):
			continue
		var sp := _proj(p) + Vector2(0, -t * (10.0 if f["big"] else 16.0))
		var a := clampf((life - t) / 0.4, 0.0, 1.0)
		var col: Color = f["color"]
		col.a = a
		var text: String = f["text"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var pos := (sp - Vector2(w * 0.5, 0)).round()
		pos.x = clampf(pos.x, 2, 478 - w)
		pos.y = clampf(pos.y, 12, 266)
		if f["big"] and t < 0.18:
			pos.y -= (0.18 - t) * 30.0
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.08, 0.08, 0.12, a))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _draw_tee() -> void:
	var tee := Vector2(TourWorld.TEE_X, TourWorld.TEE_Y)
	var has_ball := Tour.bucket_remaining > 0 and (world.charging or world.cooldown <= 0.0)
	if has_ball:
		draw_rect(Rect2(tee + Vector2(-1, 1), Vector2(3, 1)), Color(0, 0, 0, 0.3))
		draw_circle(tee + Vector2(0.5, -0.5), 1.6, Color(1, 1, 1))
	if world.charging:
		var t := world.charge_t
		var target := TourData.WINDUP_SEC
		var r := lerpf(RING_START_R, RING_TARGET_R, clampf(t / target, 0.0, 1.0))
		if t > target:
			r = RING_TARGET_R - (t - target) * 12.0
		var err := absf(t - target) * 1000.0
		var scale := TourPhysics.window_scale(Tour.levels, Tour.keepsakes)
		var tier := TourPhysics.tier_for_error(err, scale)
		var col := TourData.TIER_COLORS[tier] if tier <= 1 else Color(1, 1, 1, 0.9)
		draw_arc(tee, RING_TARGET_R, 0, TAU, 16, Color(1.0, 0.86, 0.3, 0.55), 1.0)
		if r > 0.5:
			draw_arc(tee, r, 0, TAU, 24, col, 1.0)
