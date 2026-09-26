class_name TeeLine
extends Node3D
## v9 Tee Line: the 3D range. You (and later Ratina and the cousins, one per
## bay down the line) hit balls at a giant target painted on the fairway.
## Balls pay where they land; the PIN drops golden putts on the green.

signal ball_scored(amount: float, ring: int, pos: Vector3, golden: bool)
signal pin_hit
signal swing_resolved(tier: int, err_ms: float)

const GroundShader := preload("res://scripts/tour/tour_ground.gdshader")
const TeeShader := preload("res://scripts/tour/tour_tee.gdshader")

const FOV := 50.0
const HORIZON_Y := 96.0
const CAM_BACK := 3.4
const CAM_UP := 1.45
const CAM_SIDE := 0.9
const CAM_YAW_DEG := 9.0
## Lens shift (screen px): slides the whole view left so the range is framed
## in the part of the screen the upgrade panel doesn't cover.
const LENS_SHIFT_PX := 78.0
## Bays run forward-left from yours, so the line of golfers recedes into the view.
const BAY_STEP := Vector2(-1.5, -2.8)
const TEE_TO_LIP := 1.2
const VENUE_TEE := {"barley": 8.0, "cliffs": 14.0, "mesa": 20.0, "frost": 16.0, "edge": 30.0}
const AUTO_RELEASE_LATE_MS := 300.0

var camera: Camera3D
var sun: DirectionalLight3D
var ground_mat: ShaderMaterial
var backdrop: Node
var venue := "barley"
var look: Dictionary = {}
var tee_height := 8.0
var home_xform := Transform3D()
var time_s := 0.0

## Golfers down the line: {kind, x, interval, timer, swing_t, tint}
var golfers: Array[Dictionary] = []
var charging := false
var charge_t := 0.0
var cooldown := 0.0
var last_tier := -1
var input_enabled := true

var flying: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var puffs: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var _flash := 0.0
var _rng := RandomNumberGenerator.new()
var _props_root: Node3D
var _tee_mesh: MeshInstance3D
var _shadow_material: StandardMaterial3D


func _ready() -> void:
	_rng.randomize()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.near = 0.3
	camera.size = 2.0 * camera.near * tan(deg_to_rad(FOV * 0.5))
	camera.frustum_offset = Vector2(LENS_SHIFT_PX * camera.size / 270.0, 0.0)
	camera.far = 9000.0
	add_child(camera)
	camera.make_current()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.position = Vector3(0, 0, -4000)
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GroundShader
	ground.material_override = ground_mat
	add_child(ground)
	Game.upgrades_changed.connect(_sync)
	set_venue(FortuneData.RENOVATIONS[mini(Game.level("tee_reno"), 4)])
	_sync()


# --- venue --------------------------------------------------------------------------

func set_venue(id: String) -> void:
	venue = id
	look = TourLooks.look(id)
	tee_height = float(VENUE_TEE.get(id, 8.0))
	var m := ground_mat
	m.set_shader_parameter("style", int(look["style"]))
	for key in ["fairway_a", "fairway_b", "rough_a", "rough_b", "outer_a", "outer_b",
			"green_a", "green_b", "fringe", "hazard_a", "hazard_b", "accent", "haze"]:
		m.set_shader_parameter(key, TourLooks.c(look[key]))
	m.set_shader_parameter("mist_color", TourLooks.c(look["mist_color"]))
	m.set_shader_parameter("haze_start", float(look["haze_start"]))
	m.set_shader_parameter("haze_end", float(look["haze_end"]))
	m.set_shader_parameter("haze_max", float(look["haze_max"]))
	m.set_shader_parameter("mist_amount", float(look["mist"]) * 0.6)
	m.set_shader_parameter("mist_far", float(look["mist_far"]))
	m.set_shader_parameter("darkness", float(look["darkness"]) * 0.55)
	m.set_shader_parameter("half_width", 40.0)
	m.set_shader_parameter("stripe_len", float(look["stripe"]))
	m.set_shader_parameter("sea_side", float(look.get("sea_side", 0.0)))
	m.set_shader_parameter("cloud_shadows", float(look.get("cloud_shadows", 0.0)))
	m.set_shader_parameter("grass_waves", float(look.get("grass_waves", 0.0)))
	m.set_shader_parameter("hazards", [Vector4.ZERO, Vector4.ZERO])
	m.set_shader_parameter("island", Vector3(0, -9999, 0))
	var none: Array[Vector4] = []
	for i in 6:
		none.append(Vector4(0, 0, 0, -1))
	m.set_shader_parameter("greens", none)
	m.set_shader_parameter("reach", -100.0)
	m.set_shader_parameter("target_center", Vector2(0.0, FortuneEcon.TARGET_Z))
	_build_tee()
	_spawn_props()
	_frame_camera()
	if backdrop != null:
		backdrop.set_range(id)
		backdrop.set_view_alpha(1.0)


func _frame_camera() -> void:
	var f := 135.0 / tan(deg_to_rad(FOV * 0.5))
	var pitch := atan((135.0 - HORIZON_Y) / f)
	var basis := Basis.from_euler(Vector3(-pitch, deg_to_rad(CAM_YAW_DEG), 0.0))
	home_xform = Transform3D(basis, Vector3(CAM_SIDE, tee_height + CAM_UP, CAM_BACK))
	camera.global_transform = home_xform


func bay_pos(i: int) -> Vector3:
	return Vector3(BAY_STEP.x * i, tee_height, BAY_STEP.y * i)


func _build_tee() -> void:
	if _tee_mesh != null:
		_tee_mesh.queue_free()
	var h := tee_height
	var w := 22.0
	var lip := -TEE_TO_LIP
	var back := 30.0
	var slope := h * 0.5
	## The lip runs straight on your right, then angles forward along the bays.
	var k := BAY_STEP.y / BAY_STEP.x
	var lip_l := lip + (-w) * k
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		var n := (b - a).cross(c - a).normalized()
		for v in [a, b, c, a, c, d]:
			st.set_normal(n)
			st.add_vertex(v)
	quad.call(Vector3(0, h, back), Vector3(w, h, back), Vector3(w, h, lip), Vector3(0, h, lip))
	quad.call(Vector3(-w, h, back), Vector3(0, h, back), Vector3(0, h, lip), Vector3(-w, h, lip_l))
	quad.call(Vector3(0, h, lip), Vector3(w, h, lip), Vector3(w + slope, 0, lip - slope), Vector3(0, 0, lip - slope))
	var d := Vector2(w, lip - lip_l).normalized()
	var n := Vector3(d.y, 0, -d.x) * slope
	quad.call(Vector3(-w, h, lip_l), Vector3(0, h, lip), Vector3(0, 0, lip - slope), Vector3(-w, 0, lip_l) + n)
	quad.call(Vector3(-w, h, lip_l), Vector3(-w, 0, lip_l) + n, Vector3(-w - slope, 0, lip_l), Vector3(-w - slope, 0, lip_l))
	_tee_mesh = MeshInstance3D.new()
	_tee_mesh.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = TeeShader
	var b: Array = look.get("bluff", ["8a6e52", "74593f", "4a3a30"])
	mat.set_shader_parameter("top_a", TourLooks.c(look["fairway_a"]))
	mat.set_shader_parameter("top_b", TourLooks.c(look["fairway_b"]))
	mat.set_shader_parameter("face_a", TourLooks.c(b[0]))
	mat.set_shader_parameter("face_b", TourLooks.c(b[1]))
	mat.set_shader_parameter("face_dark", TourLooks.c(b[2]))
	mat.set_shader_parameter("lip", TourLooks.c(look["rough_a"]))
	mat.set_shader_parameter("top_y", h)
	mat.set_shader_parameter("darkness", float(look["darkness"]) * 0.55)
	_tee_mesh.material_override = mat
	add_child(_tee_mesh)


func _spawn_props() -> void:
	if _props_root != null:
		_props_root.queue_free()
	_props_root = Node3D.new()
	add_child(_props_root)
	var list: Array = look.get("props", [])
	if list.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(venue)
	var total := 0.0
	for p in list:
		total += float(p[1])
	var sea := float(look.get("sea_side", 0.0))
	for i in 80:
		var pick := rng.randf() * total
		var chosen: Array = list[0]
		for p in list:
			pick -= float(p[1])
			if pick <= 0.0:
				chosen = p
				break
		var z := rng.randf_range(25.0, 260.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := side * (46.0 + rng.randf() * rng.randf() * 110.0)
		if sea > 0.0 and x > sea - 8.0:
			x = -absf(x)
		_add_prop(String(chosen[0]), Vector3(x, 0, -z), float(chosen[2]), float(look["darkness"]) > 0.5)


func _add_prop(name: String, pos: Vector3, px: float, dark: bool) -> void:
	var tex: Texture2D = load("res://assets/sprites/tour/props/%s.png" % name)
	if tex == null:
		return
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.offset = Vector2(0, tex.get_height() * 0.5 - 1.0)
	s.position = pos
	if dark:
		s.modulate = Color(0.55, 0.6, 0.82)
	_props_root.add_child(s)
	var shadow := MeshInstance3D.new()
	var q := QuadMesh.new()
	var w := tex.get_width() * px
	q.size = Vector2(w * 1.1, w * 0.55)
	q.orientation = PlaneMesh.FACE_Y
	shadow.mesh = q
	shadow.position = pos + Vector3(w * 0.15, 0.05, -w * 0.08)
	shadow.material_override = _shadow_mat()
	_props_root.add_child(shadow)


func _shadow_mat() -> StandardMaterial3D:
	if _shadow_material == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.03, 0.06, 0.42))
		g.set_color(1, Color(0.02, 0.03, 0.06, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		_shadow_material = StandardMaterial3D.new()
		_shadow_material.albedo_texture = gt
		_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _shadow_material


# --- golfers --------------------------------------------------------------------------

const COUSIN_TINTS := [Color(1.0, 0.95, 0.85), Color(0.75, 0.72, 0.8), Color(1.0, 0.82, 0.62),
	Color(0.62, 0.6, 0.58), Color(1.05, 1.05, 1.05), Color(0.85, 0.7, 0.62)]


## Keep the line of golfers in step with what's been hired.
func _sync() -> void:
	var want := ["rat"]
	if Game.level("tee_ratina") > 0:
		want.append("ratina")
	for i in FortuneEcon.cousin_count(Game.levels):
		want.append("cousin")
	while golfers.size() < want.size():
		var i := golfers.size()
		golfers.append({"kind": want[i], "bay": i, "timer": _rng.randf_range(0.2, 1.5), "swing_t": -1.0,
			"tint": COUSIN_TINTS[(i - 2) % COUSIN_TINTS.size()] if want[i] == "cousin" else Color.WHITE})
	var reno: String = FortuneData.RENOVATIONS[mini(Game.level("tee_reno"), 4)]
	if reno != venue:
		set_venue(reno)
	ground_mat.set_shader_parameter("target_radii", Vector4(
		FortuneEcon.ring_radius(Game.levels, 0), FortuneEcon.ring_radius(Game.levels, 1),
		FortuneEcon.ring_radius(Game.levels, 2), FortuneEcon.ring_radius(Game.levels, 3)))


func _golfer_interval(g: Dictionary) -> float:
	var base := FortuneEcon.ratina_interval(Game.levels) if g["kind"] == "ratina" else FortuneEcon.COUSIN_INTERVAL
	return base * (0.5 if Game.frenzy > 0.0 else 1.0)


## Helpers are decent, not perfect: mostly Good/Great, a Perfect now and then.
func _helper_tier(g: Dictionary) -> int:
	var r := _rng.randf()
	if g["kind"] == "ratina":
		return 0 if r < 0.25 else (1 if r < 0.65 else (2 if r < 0.9 else 3))
	return 0 if r < 0.12 else (1 if r < 0.45 else (2 if r < 0.85 else 3))


# --- swing (you) --------------------------------------------------------------------------

func player_cooldown() -> float:
	return FortuneEcon.tee_cooldown(Game.levels) * (0.5 if Game.frenzy > 0.0 else 1.0)


func can_swing() -> bool:
	return input_enabled and not charging and cooldown <= 0.0


func begin_swing() -> void:
	if not can_swing():
		return
	charging = true
	charge_t = 0.0


func release_swing() -> void:
	if not charging:
		return
	charging = false
	var err_ms := (charge_t - FortuneEcon.WINDUP_SEC) * 1000.0
	var tier := FortuneEcon.tier_for_error(err_ms, FortuneEcon.window_scale(Game.levels))
	last_tier = tier
	cooldown = player_cooldown()
	Game.bump("swings")
	if tier == 0:
		Game.bump("perfects")
	golfers[0]["swing_t"] = 0.0
	_launch(0, tier, signf(err_ms))
	swing_resolved.emit(tier, err_ms)


func windup_progress() -> float:
	return clampf(charge_t / FortuneEcon.WINDUP_SEC, 0.0, 1.0) if charging else 0.0


func _launch(bay: int, tier: int, sign_lr: float) -> void:
	var n := FortuneEcon.balls_per_swing(Game.levels)
	var start := bay_pos(bay)
	## Helpers are steady but never as sharp as you.
	var scatter := FortuneEcon.TIER_SCATTER[tier] * (1.0 if bay == 0 else 1.5)
	for i in n:
		var fan := (float(i) - (n - 1) * 0.5) * 3.0
		var aim := Vector2(fan + _rng.randfn(0.0, scatter) + sign_lr * scatter * 0.4, FortuneEcon.TARGET_Z + _rng.randfn(0.0, scatter))
		var golden := _rng.randf() < FortuneEcon.golden_chance(Game.levels)
		var carry := Vector2(aim.x - start.x, aim.y).length()
		flying.append({
			"start": start, "land": aim, "tier": tier, "golden": golden, "t": 0.0 - i * 0.05,
			"dur": 1.4 + 0.08 * sqrt(carry) + _rng.randf_range(-0.05, 0.05),
			"apex": carry * 0.14 + 3.0, "pos": start, "trail": [],
		})
	if bay == 0:
		Audio.play_hit(tier)
	elif _rng.randf() < 0.5:
		Audio.play_hit(mini(tier + 1, 5))


# --- frame ------------------------------------------------------------------------------

const DRAG_K := 1.3


func flight_point(b: Dictionary, t: float) -> Vector3:
	var s := (1.0 - exp(-DRAG_K * t)) / (1.0 - exp(-DRAG_K))
	var st: Vector3 = b["start"]
	var land: Vector2 = b["land"]
	var gx := lerpf(st.x, land.x, s)
	var gz := lerpf(0.0, land.y, s)
	var y := st.y * (1.0 - s) + float(b["apex"]) * sin(PI * pow(t, 0.85))
	return Vector3(gx, maxf(y, 0.0), -gz)


func _process(delta: float) -> void:
	time_s += delta
	ground_mat.set_shader_parameter("time_s", time_s)
	_flash = maxf(_flash - delta * 2.0, 0.0)
	ground_mat.set_shader_parameter("target_flash", _flash)
	cooldown = maxf(cooldown - delta, 0.0)
	if charging:
		charge_t += delta
		if charge_t * 1000.0 > FortuneEcon.WINDUP_SEC * 1000.0 + AUTO_RELEASE_LATE_MS * FortuneEcon.window_scale(Game.levels):
			release_swing()
	## Helpers swing on their own clocks.
	for i in range(1, golfers.size()):
		var g: Dictionary = golfers[i]
		g["timer"] = float(g["timer"]) - delta
		if float(g["timer"]) <= 0.0:
			g["timer"] = _golfer_interval(g) * _rng.randf_range(0.85, 1.15)
			g["swing_t"] = 0.0
			g["pending"] = _helper_tier(g)
		if float(g["swing_t"]) >= 0.0:
			var before := float(g["swing_t"])
			g["swing_t"] = before + delta
			if before < 0.33 and float(g["swing_t"]) >= 0.33 and g.has("pending"):
				_launch(i, int(g["pending"]), _rng.randf_range(-1, 1))
				g.erase("pending")
			if float(g["swing_t"]) > 1.2:
				g["swing_t"] = -1.0
	if float(golfers[0]["swing_t"]) >= 0.0:
		golfers[0]["swing_t"] = float(golfers[0]["swing_t"]) + delta
		if float(golfers[0]["swing_t"]) > 1.2:
			golfers[0]["swing_t"] = -1.0
	_update_balls(delta)
	for c in coins:
		c["t"] = float(c["t"]) + delta
	coins = coins.filter(func(c: Dictionary) -> bool: return float(c["t"]) < 1.1)
	for p in puffs:
		p["t"] = float(p["t"]) + delta
	puffs = puffs.filter(func(p: Dictionary) -> bool: return float(p["t"]) < 0.8)
	for f in floaters:
		f["t"] = float(f["t"]) + delta
	floaters = floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < float(f.get("life", 1.2)))


func _update_balls(delta: float) -> void:
	var done: Array[Dictionary] = []
	for b in flying:
		b["t"] = float(b["t"]) + delta / float(b["dur"])
		var t := clampf(float(b["t"]), 0.0, 1.0)
		var p := flight_point(b, t)
		b["pos"] = p
		var trail: Array = b["trail"]
		if float(b["t"]) > 0.0:
			trail.append(p)
			if trail.size() > 30:
				trail.pop_front()
		if float(b["t"]) >= 1.0:
			_land(b)
			done.append(b)
	for b in done:
		flying.erase(b)


func _land(b: Dictionary) -> void:
	var land: Vector2 = b["land"]
	var dist := land.distance_to(Vector2(0, FortuneEcon.TARGET_Z))
	var ring := FortuneEcon.ring_for(dist, Game.levels)
	var raw := FortuneEcon.tee_value(Game.levels) * FortuneEcon.landing_mult(dist, Game.levels) * FortuneEcon.TIER_BONUS[int(b["tier"])]
	if bool(b["golden"]):
		raw *= 10.0
	var paid := Game.earn(raw, "tee")
	var pos3 := Vector3(land.x, 0.0, -land.y)
	puffs.append({"pos": pos3, "t": 0.0})
	coins.append({"pos": pos3, "t": 0.0, "n": 3 + ring * 2 + (6 if b["golden"] else 0), "gold": b["golden"], "seed": _rng.randf() * 100.0})
	var col := Color(1, 1, 1)
	var label := "+$" + TourFormat.money(paid)
	if ring == 3:
		col = Color(1.0, 0.45, 0.4)
		label = "PIN! " + label
		_flash = 1.0
		Game.bump("pins")
		pin_hit.emit()
		Audio.play("ace")
	elif ring == 2:
		col = Color(1.0, 0.75, 0.35)
	elif ring == 1:
		col = Color(1.0, 0.95, 0.5)
	elif ring < 0:
		col = Color(0.85, 0.85, 0.85, 0.8)
	if bool(b["golden"]):
		col = Color(1.0, 0.85, 0.3)
		label = "GOLD " + label
	floaters.append({"pos": pos3 + Vector3(0, 3, 0), "text": label, "color": col, "t": 0.0, "big": ring >= 2 or b["golden"],
		"life": 1.6 if ring >= 2 else 1.0})
	ball_scored.emit(paid, ring, pos3, b["golden"])
