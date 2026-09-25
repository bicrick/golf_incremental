class_name TourWorld
extends Node3D
## v8 — the range you're standing on. Owns the 3D ground, the camera, the
## swing, every ball in the air or on the grass, the sweep, and the wind.
## Drawing of balls / flags / reticle / rat lives in TourOverlay (2D, crisp).

signal swing_resolved(tier: int, err_ms: float)
signal ball_came_to_rest(result: Dictionary)
signal new_star(green: Dictionary, bonus: float)
signal flag_reached(green: Dictionary, result: Dictionary)
signal bucket_emptied
signal sweep_started
signal sweep_finished(collected: int, tips: float)
signal keepsake_picked(keepsake: Dictionary)
signal aim_changed

const GroundShader := preload("res://scripts/tour/tour_ground.gdshader")
const TeeShader := preload("res://scripts/tour/tour_tee.gdshader")

const FOV := 50.0
const HORIZON_Y := 96.0
## Over the rat's right shoulder, like the old game: a little behind, a little
## above, a little to the right, turned slightly left so the rat's stance
## lines up with the fairway.
const CAM_BACK := 2.4
const CAM_UP := 1.25
const CAM_SIDE := 0.65
const CAM_YAW_DEG := 5.0
## The tee stands at the lip of a rise; this far back from the edge.
const TEE_TO_LIP := 1.0
const AUTO_RELEASE_LATE_MS := 300.0
const SWEEP_PITCH_DEG := 56.0
const CHAIN_GAP_SEC := 1.3
const MAGNET_SEC := 0.22

enum Mode { PLAY, SWEEP, TRANSITION, LOCKED }

var mode: int = Mode.PLAY
var range_def: Dictionary = {}
var look: Dictionary = {}
var camera: Camera3D
var sun: DirectionalLight3D
var ground_mat: ShaderMaterial
var env: Environment
var overlay: Node2D ## TourOverlay
var backdrop: Node ## TourBackdrop

## Aim: index into aim_options (greens you can see + a straight drive), plus a nudge.
var aim_options: Array[Dictionary] = []
var aim_index := 0
var aim_nudge := Vector2.ZERO
var hovered_option := -1

## Swing
var charging := false
var charge_t := 0.0
var cooldown := 0.0
var last_tier := -1
var last_err_ms := 0.0
var swing_anim_t := -1.0

## Balls: {shot, verdict, t, dur, apex, phase ("fly","roll","rest"), pos(Vector3), trail, golden, ...}
var flying: Array[Dictionary] = []
var resting: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var splashes: Array[Dictionary] = []
var puffs: Array[Dictionary] = []

## Wind (cliffs): x = crosswind yd per 100 yd (+ right), y = along share (+ tail).
var wind := Vector2.ZERO
var _wind_target := Vector2.ZERO
var _wind_timer := 0.0

## Sweep
var sweep_collected := 0
var _pulled: Array[Dictionary] = []

var cinematic_ball: Dictionary = {}
var home_xform := Transform3D()
var frame_distance := 150.0
var _cam_tween: Tween
var _rng := RandomNumberGenerator.new()
var time_s := 0.0
var input_enabled := true
## Set while a story beat is waiting (e.g. Ratina's flag was just reached).
var hold_swings := false
var finale_ready := false


func _ready() -> void:
	_rng.randomize()
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.5
	camera.far = 9000.0
	add_child(camera)
	camera.make_current()

	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.position = Vector3(0, 0, -4000)
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GroundShader
	ground.material_override = ground_mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	Tour.upgrades_changed.connect(_refresh_aim_options)
	Tour.green_starred.connect(func(_r: int, _g: String) -> void: _push_greens())


# --- range setup --------------------------------------------------------------

func load_range(index: int) -> void:
	range_def = TourData.get_range(index)
	look = TourLooks.look(range_def["id"])
	flying.clear()
	resting.clear()
	floaters.clear()
	splashes.clear()
	_pulled.clear()
	charging = false
	cinematic_ball = {}
	mode = Mode.PLAY
	wind = Vector2.ZERO
	_wind_target = Vector2.ZERO
	_wind_timer = 0.0
	finale_ready = false
	hold_swings = false
	frame_distance = float(TourData.flag_green(range_def).get("z", 150.0))
	tee_height = float(range_def.get("tee_height", 8.0))
	_apply_look()
	_build_tee()
	_spawn_props()
	_frame_camera()
	camera.global_transform = home_xform
	_refresh_aim_options()
	_push_greens()
	if backdrop != null and backdrop.has_method("set_range"):
		backdrop.set_range(range_def["id"])
		backdrop.set_view_alpha(1.0)


func _apply_look() -> void:
	var m := ground_mat
	m.set_shader_parameter("style", int(look["style"]))
	for key in ["fairway_a", "fairway_b", "rough_a", "rough_b", "outer_a", "outer_b",
			"green_a", "green_b", "fringe", "hazard_a", "hazard_b", "accent", "haze"]:
		m.set_shader_parameter(key, TourLooks.c(look[key]))
	m.set_shader_parameter("mist_color", TourLooks.c(look["mist_color"]))
	m.set_shader_parameter("haze_start", float(look["haze_start"]))
	m.set_shader_parameter("haze_end", float(look["haze_end"]))
	m.set_shader_parameter("haze_max", float(look["haze_max"]))
	m.set_shader_parameter("mist_amount", float(look["mist"]))
	m.set_shader_parameter("mist_far", float(look["mist_far"]))
	m.set_shader_parameter("darkness", float(look["darkness"]))
	m.set_shader_parameter("half_width", float(range_def["fairway_half_width"]))
	m.set_shader_parameter("stripe_len", float(look["stripe"]))
	m.set_shader_parameter("sea_side", float(look.get("sea_side", 0.0)))
	m.set_shader_parameter("cloud_shadows", float(look.get("cloud_shadows", 0.0)))
	m.set_shader_parameter("grass_waves", float(look.get("grass_waves", 0.0)))
	var hz: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO]
	var hazards: Array = range_def["hazards"]
	for i in mini(hazards.size(), 2):
		var h: Dictionary = hazards[i]
		hz[i] = Vector4(h["z0"], h["z1"], 1.0 if h["type"] == "water" else 2.0, 0.0)
	m.set_shader_parameter("hazards", hz)
	var island := Vector3(0, -9999, 0)
	for g in range_def["greens"]:
		if g.has("island"):
			island = Vector3(g["x"], g["z"], g["island"])
	m.set_shader_parameter("island", island)


var _props_root: Node3D
var _tee_mesh: MeshInstance3D


## The rise the rat tees off from: a flat grassy top that ends just past the
## tee, and a steep face dropping to the range below.
func _build_tee() -> void:
	if _tee_mesh != null:
		_tee_mesh.queue_free()
	var h := tee_height
	var w := 11.0
	var lip := -TEE_TO_LIP
	var back := 30.0
	var slope := h * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		var n := (b - a).cross(c - a).normalized()
		for v in [a, b, c, a, c, d]:
			st.set_normal(n)
			st.add_vertex(v)
	## Top.
	quad.call(Vector3(-w, h, back), Vector3(w, h, back), Vector3(w, h, lip), Vector3(-w, h, lip))
	## Front face down to the range.
	quad.call(Vector3(-w, h, lip), Vector3(w, h, lip), Vector3(w + slope, 0, lip - slope), Vector3(-w - slope, 0, lip - slope))
	## Sides.
	quad.call(Vector3(w, h, lip), Vector3(w, h, back), Vector3(w + slope, 0, back), Vector3(w + slope, 0, lip - slope))
	quad.call(Vector3(-w, h, back), Vector3(-w, h, lip), Vector3(-w - slope, 0, lip - slope), Vector3(-w - slope, 0, back))
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
	mat.set_shader_parameter("darkness", float(look["darkness"]))
	_tee_mesh.material_override = mat
	add_child(_tee_mesh)


## Billboards in the rough: trees, rocks, cacti, snowy pines, clouds. Seeded
## per range so the same range always looks the same.
func _spawn_props() -> void:
	if _props_root != null:
		_props_root.queue_free()
	_props_root = Node3D.new()
	add_child(_props_root)
	var list: Array = look.get("props", [])
	if list.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(range_def["id"])
	var total := 0.0
	for p in list:
		total += float(p[1])
	var d_max := float(TourData.flag_green(range_def).get("z", 150.0)) * 1.25
	var scale := 1.0
	var hw := float(range_def["fairway_half_width"])
	var sea := float(look.get("sea_side", 0.0))
	var dark := float(look.get("darkness", 0.0)) > 0.5
	var count := 90
	for i in count:
		var pick := rng.randf() * total
		var chosen: Array = list[0]
		for p in list:
			pick -= float(p[1])
			if pick <= 0.0:
				chosen = p
				break
		var z := rng.randf_range(20.0, d_max)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := side * (hw + rng.randf_range(6.0, 14.0) + rng.randf() * rng.randf() * 110.0)
		if sea > 0.0 and x > sea - 8.0:
			x = -absf(x)
		if _in_any_hazard(z):
			continue
		_add_prop(String(chosen[0]), Vector3(x, 0, -z), float(chosen[2]) * scale, dark)
	if range_def["id"] == "barley":
		for yd in [50, 100, 150]:
			_add_prop("sign_%d" % yd, Vector3(-hw - 5.0, 0, -float(yd)), 0.16, false)


func _in_any_hazard(z: float) -> bool:
	for h in range_def["hazards"]:
		if z > float(h["z0"]) - 4.0 and z < float(h["z1"]) + 4.0:
			return true
	return false


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
	s.centered = true
	s.offset = Vector2(0, tex.get_height() * 0.5 - 1.0)
	s.position = pos
	if dark:
		s.modulate = Color(0.42, 0.48, 0.72)
	_props_root.add_child(s)
	## Soft contact shadow on the ground, stretched away from the sun.
	var shadow := MeshInstance3D.new()
	var q := QuadMesh.new()
	var w := tex.get_width() * px
	q.size = Vector2(w * 1.1, w * 0.55)
	q.orientation = PlaneMesh.FACE_Y
	shadow.mesh = q
	shadow.position = pos + Vector3(w * 0.15, 0.05, -w * 0.08)
	shadow.material_override = _shadow_mat()
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_props_root.add_child(shadow)


var _shadow_material: StandardMaterial3D


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
		gt.width = 64
		gt.height = 64
		_shadow_material = StandardMaterial3D.new()
		_shadow_material.albedo_texture = gt
		_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _shadow_material


func _push_greens() -> void:
	if range_def.is_empty():
		return
	var arr: Array[Vector4] = []
	var lit := Tour.lit_count(range_def)
	for g in range_def["greens"]:
		var state := 0.0
		if g.get("lantern", false):
			state = 3.0 if Tour.stars.get(g["id"], false) else 2.0
		elif Tour.stars.get(g["id"], false):
			state = 1.0
		if g.has("needs_lit") and lit < int(g["needs_lit"]):
			state = 4.0
		arr.append(Vector4(g["x"], g["z"], g["r"], state))
	while arr.size() < 6:
		arr.append(Vector4(0, 0, 0, -1))
	ground_mat.set_shader_parameter("greens", arr)
	_refresh_aim_options()


func green_visible(g: Dictionary) -> bool:
	return not (g.has("needs_lit") and Tour.lit_count(range_def) < int(g["needs_lit"]))


var tee_height := 8.0
var tee_screen := Vector2(188, 239)


## Every range tees off from a high place (a knoll, a cliff top, a butte, a
## ridge, a crag over the clouds), so you look out and down over the whole
## range. Pitch is set so the horizon sits on the painted backdrop's horizon.
func _frame_camera() -> void:
	var f := 135.0 / tan(deg_to_rad(FOV * 0.5))
	var pitch := atan((135.0 - HORIZON_Y) / f)
	var basis := Basis.from_euler(Vector3(-pitch, deg_to_rad(CAM_YAW_DEG), 0.0))
	home_xform = Transform3D(basis, Vector3(CAM_SIDE, tee_height + CAM_UP, CAM_BACK))
	camera.global_transform = home_xform
	tee_screen = camera.unproject_position(tee_pos()).round()


func tee_pos() -> Vector3:
	return Vector3(0.0, tee_height, 0.0)


func horizon_y() -> float:
	return HORIZON_Y


# --- aim ------------------------------------------------------------------------

func _refresh_aim_options() -> void:
	if range_def.is_empty():
		return
	var prev_id := ""
	if aim_index >= 0 and aim_index < aim_options.size():
		prev_id = aim_options[aim_index].get("id", "")
	aim_options.clear()
	var reach := Tour.reach()
	for g in range_def["greens"]:
		if not green_visible(g):
			continue
		var in_reach := landing_for(Vector2(g["x"], g["z"]), g).length() <= reach + 0.5
		aim_options.append({"id": g["id"], "green": g, "point": Vector2(g["x"], g["z"]), "in_reach": in_reach})
	for k in visible_keepsakes():
		var kp := Vector2(k["x"], k["z"])
		aim_options.append({"id": k["id"], "green": {}, "keepsake": k, "point": kp, "in_reach": kp.length() <= reach + 0.5})
	aim_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["point"].y < b["point"].y)
	aim_options.append({"id": "drive", "green": {}, "point": Vector2(0, reach), "in_reach": true})
	aim_index = -1
	for i in aim_options.size():
		if aim_options[i]["id"] == prev_id and aim_options[i]["in_reach"]:
			aim_index = i
	if aim_index < 0:
		aim_index = _default_aim()
	aim_changed.emit()


## Farthest green in reach that still has no star; else the farthest in reach.
func _default_aim() -> int:
	var best := aim_options.size() - 1
	var best_score := -1.0
	for i in aim_options.size():
		var o: Dictionary = aim_options[i]
		if not o["in_reach"] or o["id"] == "drive" or o.has("keepsake"):
			continue
		var score: float = o["point"].y
		if not Tour.stars.get(o["id"], false):
			score += 10000.0
		if o["green"].get("ratina", false):
			score += 20000.0
		if score > best_score:
			best_score = score
			best = i
	return best


func cycle_aim(step: int) -> void:
	if aim_options.is_empty():
		return
	for _i in aim_options.size():
		aim_index = wrapi(aim_index + step, 0, aim_options.size())
		if aim_options[aim_index]["in_reach"]:
			break
	aim_nudge = Vector2.ZERO
	aim_changed.emit()
	_sfx("ui_tick")


func select_aim(i: int) -> void:
	if i < 0 or i >= aim_options.size() or not aim_options[i]["in_reach"]:
		_sfx("ui_error")
		return
	aim_index = i
	aim_nudge = Vector2.ZERO
	aim_changed.emit()
	_sfx("ui_tick")


func current_aim_option() -> Dictionary:
	if aim_index < 0 or aim_index >= aim_options.size():
		return {}
	return aim_options[aim_index]


## The ground point a Perfect would land on (before wind / roll).
func aim_point() -> Vector2:
	var o := current_aim_option()
	if o.is_empty():
		return Vector2(0, Tour.reach())
	var target: Vector2 = o["point"] + aim_nudge
	if o["id"] != "drive":
		target = landing_for(target, o["green"])
		if range_def.get("mechanic", "") == "wind" and Tour.level("wind") > 0:
			## The reader aims into the wind for you.
			target.x -= wind.x * target.y / 100.0 * _drift_cut()
			target.y /= 1.0 + _along_boost(wind.y)
	var reach := Tour.reach()
	if target.length() > reach:
		target = target.normalized() * reach
	if o["id"] == "drive":
		target = TourPhysics.safe_drive(target, range_def, Tour.levels, Tour.keepsakes)
	return target


func expected_land(aim: Vector2) -> Vector2:
	var land := aim
	if range_def.get("mechanic", "") == "wind":
		land = aim * (1.0 + _along_boost(wind.y))
		land.x += wind.x * land.length() / 100.0 * _drift_cut()
	return land


func expected_rest(land: Vector2) -> Vector2:
	return land * (1.0 + _expected_roll())


func landing_for(target: Vector2, green: Dictionary = {}) -> Vector2:
	return TourPhysics.landing_for(target, green, range_def, Tour.levels, Tour.keepsakes)


func _expected_roll() -> float:
	return TourPhysics.roll_share_for(range_def, Tour.levels, Tour.keepsakes)


func _drift_cut() -> float:
	return clampf(1.0 - 0.15 * Tour.level("wind") - TourPhysics.bonus_sum(Tour.keepsakes, "drift"), 0.2, 1.0)


func _along_boost(along: float) -> float:
	return along * (1.0 + 0.1 * Tour.level("wind")) if along > 0.0 else along


# --- frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	time_s += delta
	ground_mat.set_shader_parameter("time_s", time_s)
	ground_mat.set_shader_parameter("reach", Tour.reach() if mode == Mode.PLAY else -100.0)
	cooldown = maxf(cooldown - delta, 0.0)
	if swing_anim_t >= 0.0:
		swing_anim_t += delta
	_update_wind(delta)
	if charging:
		charge_t += delta
		if charge_t * 1000.0 > TourData.WINDUP_SEC * 1000.0 + AUTO_RELEASE_LATE_MS * TourPhysics.window_scale(Tour.levels, Tour.keepsakes):
			release_swing()
	_update_balls(delta)
	_update_floaters(delta)
	if mode == Mode.SWEEP:
		_update_sweep(delta)
	_update_cinematic(delta)


func _update_wind(delta: float) -> void:
	if range_def.get("mechanic", "") != "wind":
		return
	_wind_timer -= delta
	if _wind_timer <= 0.0:
		_wind_timer = _rng.randf_range(5.0, 9.0)
		var gusty := _rng.randf() < 0.35
		_wind_target = Vector2(
			_rng.randf_range(-7.0, 7.0),
			_rng.randf_range(0.06, 0.16) if gusty else _rng.randf_range(-0.12, 0.08)
		)
	var before := wind
	wind = wind.lerp(_wind_target, clampf(delta * 0.8, 0.0, 1.0))
	if before.distance_to(wind) > 0.001:
		aim_changed.emit()


# --- swing ----------------------------------------------------------------------

func can_swing() -> bool:
	return (mode == Mode.PLAY and input_enabled and not charging and cooldown <= 0.0
		and not cinematic_active() and not hold_swings
		and Tour.bucket_remaining > 0 and not range_def.is_empty())


func begin_swing() -> void:
	if not can_swing():
		if mode == Mode.PLAY and Tour.bucket_remaining <= 0 and flying.is_empty():
			begin_sweep()
		return
	charging = true
	charge_t = 0.0
	swing_anim_t = -1.0


func release_swing() -> void:
	if not charging:
		return
	charging = false
	var err_ms := (charge_t - TourData.WINDUP_SEC) * 1000.0
	var scale := TourPhysics.window_scale(Tour.levels, Tour.keepsakes)
	var tier := TourPhysics.tier_for_error(err_ms, scale)
	last_tier = tier
	last_err_ms = err_ms
	swing_anim_t = 0.0
	cooldown = TourData.SWING_COOLDOWN_SEC
	_launch(tier, err_ms)
	swing_resolved.emit(tier, err_ms)


func windup_progress() -> float:
	return clampf(charge_t / TourData.WINDUP_SEC, 0.0, 1.0) if charging else 0.0


func _launch(tier: int, err_ms: float) -> void:
	var aim := aim_point()
	var shot := TourPhysics.resolve_shot(aim, tier, signf(err_ms), wind, range_def, Tour.levels, Tour.keepsakes, _rng)
	var verdict := TourPhysics.judge(shot, range_def, Tour.lit_count(range_def))
	Tour.use_ball()
	Tour.record_swing(tier, shot["carry"])
	if tier <= 1:
		Tour.streak += 1
	else:
		Tour.streak = 0
	var golden := _rng.randf() < TourPhysics.golden_chance(Tour.levels)
	var carry: float = shot["carry"]
	var ball := {
		"shot": shot,
		"verdict": verdict,
		"tier": tier,
		"golden": golden,
		"t": 0.0,
		"dur": 1.0 + 0.11 * sqrt(maxf(carry, 1.0)),
		"apex": clampf(carry * (0.13 if tier <= 3 else 0.05) + (3.0 if tier <= 3 else 0.5), 1.5, 44.0),
		"phase": "fly",
		"pos": Vector3.ZERO,
		"trail": [],
		"roll_t": 0.0,
		"streak": Tour.streak,
		"id": _rng.randi(),
	}
	## Big moments get the camera: Ratina's flag, an ace.
	var g := _green_by_id(verdict["green"])
	if not g.is_empty() and (g.get("ratina", false) or verdict["ace"]) and cinematic_ball.is_empty():
		ball["cinematic"] = true
		ball["dur"] *= 1.35
		cinematic_ball = ball
	flying.append(ball)
	_sfx_hit(tier)


## A golf ball's flight, not a parabola: drag bleeds off speed so it covers
## ground fast early and slow late, the apex comes ~60% of the way out, and
## it falls more steeply than it climbed. Starts from the raised tee.
const DRAG_K := 1.3


func flight_point(land: Vector2, apex: float, t: float) -> Vector3:
	var s := (1.0 - exp(-DRAG_K * t)) / (1.0 - exp(-DRAG_K))
	var gp := land * s
	var y := tee_height * (1.0 - s) + apex * sin(PI * pow(t, 0.85))
	return Vector3(gp.x, maxf(y, 0.0), -gp.y)


func _green_by_id(id: String) -> Dictionary:
	if id == "":
		return {}
	for g in range_def["greens"]:
		if g["id"] == id:
			return g
	return {}


func _update_balls(delta: float) -> void:
	var done: Array[Dictionary] = []
	for b in flying:
		var shot: Dictionary = b["shot"]
		var land: Vector2 = shot["land"]
		if b["phase"] == "fly":
			b["t"] = float(b["t"]) + delta / float(b["dur"])
			var t := minf(float(b["t"]), 1.0)
			var p3 := flight_point(land, float(b["apex"]), t)
			b["pos"] = p3
			var trail: Array = b["trail"]
			trail.append(p3)
			if trail.size() > 40:
				trail.pop_front()
			if t >= 1.0:
				var verdict: Dictionary = b["verdict"]
				if verdict["lost"] != "" and (verdict["rest"] as Vector2).distance_to(land) < 0.5:
					_ball_lost(b)
					done.append(b)
				else:
					b["phase"] = "roll"
					b["roll_t"] = 0.0
					puffs.append({"pos": b["pos"], "t": 0.0, "big": int(b["tier"]) <= 1})
					_sfx("land")
		elif b["phase"] == "roll":
			var verdict2: Dictionary = b["verdict"]
			var rest: Vector2 = verdict2["rest"]
			var roll_len := land.distance_to(rest)
			var roll_dur := 0.25 + roll_len / 30.0
			b["roll_t"] = float(b["roll_t"]) + delta / roll_dur
			var rt := minf(float(b["roll_t"]), 1.0)
			var e := 1.0 - pow(1.0 - rt, 2.0)
			var hop := 0.0
			if roll_len > 1.0:
				hop = absf(sin(rt * PI * 2.0)) * (1.0 - rt) * minf(roll_len * 0.06, 1.5)
			var gp2 := land.lerp(rest, e)
			b["pos"] = Vector3(gp2.x, hop, -gp2.y)
			var trail2: Array = b["trail"]
			if not trail2.is_empty():
				trail2.pop_front()
			if rt >= 1.0:
				if verdict2["lost"] != "":
					_ball_lost(b)
				else:
					_ball_rests(b)
				done.append(b)
	for b in done:
		flying.erase(b)
	if Tour.bucket_remaining <= 0 and flying.is_empty() and mode == Mode.PLAY and not charging and input_enabled and not cinematic_active() and not hold_swings:
		bucket_emptied.emit()


func _ball_lost(b: Dictionary) -> void:
	var verdict: Dictionary = b["verdict"]
	var p: Vector2 = verdict["rest"]
	var kind: String = verdict["lost"]
	splashes.append({"pos": Vector3(p.x, 0, -p.y), "t": 0.0, "kind": kind})
	_float_text(Vector3(p.x, 2, -p.y), "Splash!" if kind == "water" else "Lost in the canyon", Color(0.8, 0.9, 1.0) if kind == "water" else Color(1.0, 0.75, 0.6), false)
	_sfx("splash" if kind == "water" else "lost")
	if b == cinematic_ball:
		cinematic_ball = {}
	ball_came_to_rest.emit({"lost": kind, "tier": b["tier"], "pay": 0.0})


func _ball_rests(b: Dictionary) -> void:
	var shot: Dictionary = b["shot"]
	var verdict: Dictionary = b["verdict"]
	var lit := Tour.lit_count(range_def)
	var pay := TourPhysics.payout(shot, verdict, int(b["streak"]), bool(b["golden"]), lit, range_def, Tour.levels, Tour.keepsakes)
	var rest: Vector2 = verdict["rest"]
	var pos3 := Vector3(rest.x, 0, -rest.y)
	var g := _green_by_id(verdict["green"])
	var text := "+$%s" % TourFormat.money(pay)
	if verdict["ace"]:
		Tour.stats["aces"] = int(Tour.stats["aces"]) + 1
		_float_text(pos3 + Vector3(0, 6, 0), "ACE!", Color(1.0, 0.85, 0.3), true)
		_sfx("ace")
	elif not g.is_empty():
		_float_text(pos3 + Vector3(0, 6, 0), "GREEN ×%s" % TourFormat.mult(TourPhysics.green_mult(Tour.levels)), Color(0.65, 1.0, 0.6), true)
		_sfx("green")
	if bool(b["golden"]):
		text = "GOLD " + text
	Tour.add_money(pay)
	_float_text(pos3 + Vector3(0, 2, 0), text, Color(1.0, 0.92, 0.5) if bool(b["golden"]) else Color(1, 1, 1), false)
	var ball := {"pos": pos3, "ground": rest, "golden": b["golden"], "pay": pay, "id": b["id"]}
	resting.append(ball)
	record_bucket_ball(int(b["tier"]), pay, not g.is_empty(), float(shot["carry"]))
	## A ball that stops near a keepsake in the grass turns it up.
	for k in visible_keepsakes():
		if rest.distance_to(Vector2(k["x"], k["z"])) <= 8.0:
			Tour.find_keepsake(k["id"])
			keepsake_picked.emit(k)
			_sfx("keepsake")
			_refresh_aim_options()
	var result := {"lost": "", "tier": b["tier"], "pay": pay, "green": verdict["green"], "ace": verdict["ace"],
		"carry": shot["carry"], "rest": rest}
	if b == cinematic_ball:
		cinematic_ball = {}
	if not g.is_empty():
		var first := Tour.star_green(g["id"])
		if first:
			var bonus := TourPhysics.first_green_bonus(shot["carry"], Tour.levels, Tour.keepsakes, range_def)
			Tour.add_money(bonus)
			new_star.emit(g, bonus)
			_push_greens()
		if g.get("ratina", false):
			flag_reached.emit(g, result)
	ball_came_to_rest.emit(result)


# --- floating text --------------------------------------------------------------

func _float_text(pos: Vector3, text: String, color: Color, big: bool) -> void:
	floaters.append({"pos": pos, "text": text, "color": color, "big": big, "t": 0.0})


func _update_floaters(delta: float) -> void:
	for f in floaters:
		f["t"] = float(f["t"]) + delta
	floaters = floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < (2.2 if f["big"] else 1.4))
	for pf in puffs:
		pf["t"] = float(pf["t"]) + delta
	puffs = puffs.filter(func(pf: Dictionary) -> bool: return float(pf["t"]) < 0.9)
	for s in splashes:
		s["t"] = float(s["t"]) + delta
	splashes = splashes.filter(func(s: Dictionary) -> bool: return float(s["t"]) < 1.0)


# --- cinematic follow --------------------------------------------------------------

## Big shots (Ratina's flag, an ace) get a follow-cam: it rides along behind
## the ball, holds on the landing, then eases home. Pitch never changes, so
## the painted backdrop stays true.
var cinematic_hold := 0.0
var _cine_focus := Vector2.ZERO


func cinematic_active() -> bool:
	return not cinematic_ball.is_empty() or cinematic_hold > 0.0


func _update_cinematic(delta: float) -> void:
	if mode != Mode.PLAY and mode != Mode.LOCKED:
		return
	var follow := 0.0
	if not cinematic_ball.is_empty():
		var t := minf(float(cinematic_ball["t"]), 1.0)
		var pos3: Vector3 = cinematic_ball["pos"]
		_cine_focus = Vector2(pos3.x, -pos3.z)
		follow = smoothstep(0.02, 0.6, t)
		cinematic_hold = 1.8
	elif cinematic_hold > 0.0:
		## Keep holding while the flag's note is up.
		if mode == Mode.PLAY:
			cinematic_hold -= delta
		follow = 1.0
	var target := home_xform
	if follow > 0.0:
		var home := home_xform.origin
		var near := Vector3(_cine_focus.x * 0.9, tee_height * 0.35 + 3.0, -_cine_focus.y + 16.0)
		target = Transform3D(home_xform.basis, home.lerp(near, follow))
	camera.global_transform = camera.global_transform.interpolate_with(target, clampf(delta * 2.6, 0.0, 1.0))


# --- the Big Picker ------------------------------------------------------------------

## When the bucket runs dry the big range tractor rumbles out and scoops up
## every ball while the camera watches from above; the bucket report pays a
## bonus for how well the bucket went. Space skips it.
const PICKER_SEC := 3.6

var picker: TourPicker
var _route: Array[Vector2] = []
var _route_i := 0
var _picker_pos := Vector2.ZERO
var _picker_yaw := 0.0
var _picker_speed := 60.0
var bucket_stats := {"pay": 0.0, "balls": 0, "perfects": 0, "greens": 0, "best": 0.0}
var last_report: Dictionary = {}


func begin_sweep() -> void:
	if mode != Mode.PLAY:
		return
	if resting.is_empty():
		_finish_sweep_now()
		return
	mode = Mode.TRANSITION
	sweep_collected = 0
	_pulled.clear()
	_build_route()
	if picker == null:
		picker = TourPicker.new()
		add_child(picker)
	picker.visible = true
	_place_picker(0.0)
	_tween_camera(_overview_xform(), 0.8)
	if backdrop != null:
		backdrop.fade_view(0.0, 0.5)
	sweep_started.emit()
	_sfx("sweep_start")
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if mode == Mode.TRANSITION:
			mode = Mode.SWEEP
	)


## Visit every ball, nearest first, entering from the rough on the left and
## driving out past the last one.
func _build_route() -> void:
	var left: Array = []
	for b in resting:
		left.append(b["ground"])
	var min_z := INF
	for g in left:
		min_z = minf(min_z, (g as Vector2).y)
	var start := Vector2(-float(range_def["fairway_half_width"]) - 25.0, maxf(min_z - 15.0, 5.0))
	_route = [start]
	var cur := start
	while not left.is_empty():
		var best := 0
		var bd := INF
		for i in left.size():
			var d := cur.distance_to(left[i])
			if d < bd:
				bd = d
				best = i
		cur = left[best]
		left.remove_at(best)
		_route.append(cur)
	var last: Vector2 = _route[-1]
	var prev: Vector2 = _route[-2] if _route.size() > 1 else start
	_route.append(last + (last - prev).normalized() * 30.0)
	var length := 0.0
	for i in range(1, _route.size()):
		length += _route[i - 1].distance_to(_route[i])
	_picker_speed = maxf(length / PICKER_SEC, 35.0)
	_picker_pos = start
	_route_i = 1
	var d0: Vector2 = _route[1] - start
	_picker_yaw = atan2(-d0.x, d0.y)


## High, framing every ball (pitch fixed so it reads like the sweep of old).
func _overview_xform() -> Transform3D:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in _route:
		lo = lo.min(p)
		hi = hi.max(p)
	var center := (lo + hi) * 0.5
	var extent := maxf(maxf((hi.y - lo.y) * 0.75, (hi.x - lo.x) * 0.45), 28.0)
	var q := deg_to_rad(SWEEP_PITCH_DEG)
	var look_at := Vector3(center.x, 0, -center.y)
	var pos := look_at + Vector3(0, sin(q), cos(q)) * extent * 1.15
	return Transform3D(Basis.from_euler(Vector3(-q, 0, 0)), pos)


func _tween_camera(xf: Transform3D, sec: float) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(camera, "global_transform", xf, sec)


func _place_picker(delta: float) -> void:
	picker.position = Vector3(_picker_pos.x, 0.0, -_picker_pos.y)
	picker.rotation.y = _picker_yaw
	picker.spin(_picker_speed * 0.12, delta)


func ground_at_screen(screen: Vector2) -> Variant:
	var o := camera.project_ray_origin(screen)
	var n := camera.project_ray_normal(screen)
	if n.y > -0.0001:
		return null
	var t := -o.y / n.y
	var hit := o + n * t
	return Vector2(hit.x, -hit.z)


func visible_keepsakes() -> Array:
	var out: Array = []
	for k in range_def.get("keepsakes", []):
		if Tour.keepsakes.get(k["id"], false):
			continue
		if float(k["z"]) <= Tour.reach() * 1.05:
			out.append(k)
	return out


func _update_sweep(delta: float) -> void:
	if _route_i < _route.size():
		var target: Vector2 = _route[_route_i]
		var to := target - _picker_pos
		var step := _picker_speed * delta
		if to.length() <= step:
			_picker_pos = target
			_route_i += 1
		else:
			_picker_pos += to.normalized() * step
		var want := atan2(-to.x, to.y) if to.length() > 0.5 else _picker_yaw
		_picker_yaw = lerp_angle(_picker_yaw, want, clampf(delta * 8.0, 0.0, 1.0))
		_place_picker(delta)
	## The reels sit out front; anything under them hops into the hopper.
	var fwd := Vector2(-sin(_picker_yaw), cos(_picker_yaw))
	var reel := _picker_pos + fwd * 1.6 * TourPicker.SCALE
	var reach := TourPicker.reach_width() * 0.6
	for b in resting.duplicate():
		if (b["ground"] as Vector2).distance_to(reel) <= reach:
			resting.erase(b)
			b["pull_t"] = 0.0
			b["from"] = b["ground"]
			_pulled.append(b)
	for b in _pulled.duplicate():
		b["pull_t"] = float(b["pull_t"]) + delta / MAGNET_SEC
		var k := minf(float(b["pull_t"]), 1.0)
		var hopper := _picker_pos - fwd * 1.4 * TourPicker.SCALE
		var gp: Vector2 = (b["from"] as Vector2).lerp(hopper, k)
		b["pos"] = Vector3(gp.x, sin(k * PI) * 3.0 * TourPicker.SCALE * 0.5 + k * 2.0, -gp.y)
		if k >= 1.0:
			_pulled.erase(b)
			sweep_collected += 1
			Audio.play_plink(mini(sweep_collected, 12))
	if _route_i >= _route.size() and _pulled.is_empty():
		_finish_sweep_now()


## Space: skip the show, every ball is in.
func finish_sweep() -> void:
	if mode != Mode.SWEEP and mode != Mode.TRANSITION:
		return
	sweep_collected += resting.size() + _pulled.size()
	resting.clear()
	_pulled.clear()
	_finish_sweep_now()


func record_bucket_ball(tier: int, pay: float, green: bool, carry: float) -> void:
	bucket_stats["balls"] = int(bucket_stats["balls"]) + 1
	bucket_stats["pay"] = float(bucket_stats["pay"]) + pay
	if tier == 0:
		bucket_stats["perfects"] = int(bucket_stats["perfects"]) + 1
	if green:
		bucket_stats["greens"] = int(bucket_stats["greens"]) + 1
	bucket_stats["best"] = maxf(float(bucket_stats["best"]), carry)


func _finish_sweep_now() -> void:
	mode = Mode.TRANSITION
	Tour.flags["swept"] = true
	var bonus := TourPhysics.bucket_bonus(bucket_stats, Tour.levels)
	Tour.add_money(bonus)
	last_report = bucket_stats.duplicate()
	last_report["bonus"] = bonus
	last_report["collected"] = sweep_collected
	bucket_stats = {"pay": 0.0, "balls": 0, "perfects": 0, "greens": 0, "best": 0.0}
	Tour.refill_bucket()
	if picker != null:
		picker.visible = false
	_tween_camera(home_xform, 0.7)
	if backdrop != null:
		backdrop.fade_view(1.0, 0.7)
	sweep_finished.emit(sweep_collected, bonus)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if mode == Mode.TRANSITION:
			mode = Mode.PLAY
	)


# --- sound ------------------------------------------------------------------------

func _sfx(kind: String) -> void:
	Audio.play(kind)


func _sfx_hit(tier: int) -> void:
	Audio.play_hit(tier)
