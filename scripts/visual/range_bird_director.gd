class_name RangeBirdDirector
extends Node3D
## Spawns near-fairway birds that enter high, perch, then climb out.

const POOL_SIZE := 5
const PERCH_MIN_SEP := 3.2
const FLUSH_RADIUS := 8.0
const BAY_EXCLUSION_X := 8.0
const BAY_EXCLUSION_Z_NEAR := -24.0
const PERCH_Z_NEAR := -28.0
const PERCH_Z_FAR := -88.0
## depth^POWER — higher = more birds near the tee / front of the range.
const PERCH_FRONT_BIAS := 2.35
const PERCH_X_INNER := 6.0
const PERCH_X_OUTER := 17.0
const MIN_APPROACH_Y := 9.0
const MAX_APPROACH_Y := 15.0
const SIDE_SPAWN_X := 22.0
const TREELINE_SCREEN_Y := 0.40
const PAIR_CHANCE := 0.16
## Screen-space click radius (px) for perched birds in harvest ortho.
const CLICK_RADIUS_PX := 36.0

var _birds: Array[RangeBird] = []
var _rng := RandomNumberGenerator.new()
var _camera: Camera3D
var _next_arrival := 1.2
var _atmosphere_tint := Color.WHITE
var _range_view: Node = null


func _ready() -> void:
	_rng.randomize()
	_range_view = get_parent()
	_camera = _find_active_camera()
	_build_pool()
	if Engine.is_editor_hint():
		set_process(false)
		return
	var bus := get_node_or_null("/root/EventBus")
	if bus != null and not bus.litter_spawned.is_connected(_on_litter_spawned):
		bus.litter_spawned.connect(_on_litter_spawned)
	_launch_arrival()
	_next_arrival = _rng.randf_range(2.5, 6.0)
	set_process(true)


func apply_atmosphere_tint(tint: Color) -> void:
	_atmosphere_tint = tint
	for bird in _birds:
		bird.apply_atmosphere_tint(tint)


func birds() -> Array[RangeBird]:
	return _birds


func active_count() -> int:
	var n := 0
	for bird in _birds:
		if bird.is_busy():
			n += 1
	return n


func perched_count() -> int:
	var n := 0
	for bird in _birds:
		if bird.is_perched():
			n += 1
	return n


func target_active_count() -> int:
	var day_factor := _day_factor()
	if day_factor > 0.55:
		return 3
	if day_factor > 0.22:
		return 2
	return 1


static func is_above_treeline(camera: Camera3D, world_pos: Vector3) -> bool:
	if camera == null or not camera.is_inside_tree():
		return world_pos.y >= MIN_APPROACH_Y
	if camera.is_position_behind(world_pos):
		return world_pos.y >= MIN_APPROACH_Y
	var viewport := camera.get_viewport()
	if viewport == null:
		return world_pos.y >= MIN_APPROACH_Y
	var height := viewport.get_visible_rect().size.y
	if height < 1.0:
		return world_pos.y >= MIN_APPROACH_Y
	var screen := camera.unproject_position(world_pos)
	return screen.y < height * TREELINE_SCREEN_Y


func pick_perch() -> Vector3:
	for _i in 16:
		var candidate := _sample_perch()
		if _perch_free(candidate):
			return candidate
	return _sample_perch()


func pick_approach(perch: Vector3) -> Vector3:
	var strike_cam := _find_strike_camera()
	for _i in 10:
		var candidate := _sample_approach(perch)
		if is_above_treeline(strike_cam, candidate):
			return candidate
	var fallback := perch + Vector3(0.0, MAX_APPROACH_Y, 6.0)
	fallback.y = MAX_APPROACH_Y
	return fallback


func pick_exit(from: Vector3, prefer_screen_right: Variant = null) -> Vector3:
	var strike_cam := _find_strike_camera()
	var right := Vector3.RIGHT
	if strike_cam != null and strike_cam.is_inside_tree():
		right = strike_cam.global_transform.basis.x.normalized()
	## Prefer continuing the way the bird already faces (beak leads takeoff).
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	if prefer_screen_right is bool:
		side = 1.0 if prefer_screen_right else -1.0
	for _i in 10:
		var candidate := _sample_exit(from, right, side)
		if is_above_treeline(strike_cam, candidate):
			return candidate
	return from + right * (side * _rng.randf_range(10.0, 18.0)) + Vector3(
		0.0, _rng.randf_range(MIN_APPROACH_Y + 1.0, MAX_APPROACH_Y + 2.0), _rng.randf_range(1.0, 8.0)
	)


func get_view_camera() -> Camera3D:
	return _find_active_camera()


func _process(delta: float) -> void:
	var parent_3d := get_parent() as Node3D
	if parent_3d != null and not parent_3d.visible:
		return
	_next_arrival -= delta
	if _next_arrival > 0.0:
		return
	if active_count() >= target_active_count():
		_next_arrival = _rng.randf_range(2.5, 5.0)
		return
	_launch_arrival()
	if randf() < PAIR_CHANCE and active_count() < target_active_count():
		_launch_arrival()
	_next_arrival = _rng.randf_range(3.5, 9.0)


func _launch_arrival() -> void:
	var bird := _idle_bird()
	if bird == null:
		return
	var perch := pick_perch()
	var from := pick_approach(perch)
	var perch_sec := _rng.randf_range(9.0, 22.0)
	var species := _rng.randi_range(0, SkyBirdFrames.SPECIES_COUNT - 1)
	var golden := _rng.randf() < Balance.GOLDEN_BIRD_CHANCE
	bird.start_cycle(from, perch, species, perch_sec, golden)


## Harvest click: flush a perched bird under the cursor. Returns true if handled.
func try_harvest_click(screen_pos: Vector2) -> bool:
	var camera := _find_active_camera()
	if camera == null:
		return false
	var bird := _pick_perched_at(screen_pos, camera)
	if bird == null:
		return false
	_flush_clicked(bird)
	return true


func _pick_perched_at(screen_pos: Vector2, camera: Camera3D) -> RangeBird:
	var best: RangeBird = null
	var best_dist := CLICK_RADIUS_PX
	for bird in _birds:
		## Fog-bank birds are visual only — no flush / golden click.
		if not bird.is_clickable():
			continue
		if camera.is_position_behind(bird.global_position):
			continue
		## Aim at mid-body so the clickable blob matches the sprite.
		var aim := bird.global_position + Vector3(0.0, 0.18, 0.0)
		var bird_screen := camera.unproject_position(aim)
		var dist := screen_pos.distance_to(bird_screen)
		if dist <= best_dist:
			best_dist = dist
			best = bird
	return best


func _flush_clicked(bird: RangeBird) -> void:
	var reward := bird.claim_golden_reward()
	if reward > 0.0:
		var sfx := get_node_or_null("/root/SfxManager")
		if sfx != null and sfx.has_method("play_golden_bird_reward"):
			sfx.play_golden_bird_reward()
		var gs := get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("add_currency"):
			gs.add_currency(reward)
		if _range_view != null and _range_view.has_method("show_pickup_cash_float"):
			_range_view.show_pickup_cash_float(bird.global_position, reward, 1, true)
		var bus := get_node_or_null("/root/EventBus")
		if bus != null and bus.has_signal("pickup_payout"):
			bus.pickup_payout.emit(reward, 1)
	else:
		var sfx2 := get_node_or_null("/root/SfxManager")
		if sfx2 != null and sfx2.has_method("play_bird_squawk"):
			sfx2.play_bird_squawk()
	bird.flush_to(pick_exit(bird.position, bird.faces_screen_right()))


func _on_leave_requested(bird: RangeBird) -> void:
	if bird == null or not bird.is_perched():
		return
	bird.takeoff_to(pick_exit(bird.position, bird.faces_screen_right()))


func _on_hop_requested(bird: RangeBird) -> void:
	if bird == null or not bird.is_perched():
		return
	var next := pick_perch()
	if next.distance_to(bird.position) > 14.0:
		return
	## Prefer a hop that continues the beak direction when possible.
	var cam := _find_active_camera()
	var right := Vector3.RIGHT
	if cam != null:
		right = cam.global_transform.basis.x.normalized()
	var want_right := bird.faces_screen_right()
	var lateral := (next - bird.position).dot(right)
	if (lateral > 0.0) != want_right:
		## Mirror hop across the bird so facing and travel stay aligned.
		var along := right * lateral
		next = bird.position + ((next - bird.position) - along * 2.0)
		next.y = RangeBird.PERCH_Y
		if not _perch_free(next) or absf(next.x) > PERCH_X_OUTER + 1.0:
			next = pick_perch()
	bird.hop_to(next)


func _on_litter_spawned(
	_litter_id: int,
	world_pos: Vector3,
	_quality: int,
	_yardage: float,
	_is_golden: bool,
	_source: String
) -> void:
	for bird in _birds:
		if not bird.is_busy():
			continue
		if bird.position.distance_to(world_pos) > FLUSH_RADIUS:
			continue
		bird.flush_to(pick_exit(bird.position, bird.faces_screen_right()))


func _idle_bird() -> RangeBird:
	for bird in _birds:
		if not bird.is_busy():
			return bird
	return null


func _build_pool() -> void:
	for child in get_children():
		if child is RangeBird:
			_birds.append(child)
	while _birds.size() < POOL_SIZE:
		var bird := RangeBird.new()
		bird.name = "RangeBird_%d" % _birds.size()
		add_child(bird)
		_birds.append(bird)
	for bird in _birds:
		bird.apply_atmosphere_tint(_atmosphere_tint)
		if not bird.leave_requested.is_connected(_on_leave_requested):
			bird.leave_requested.connect(_on_leave_requested.bind(bird))
		if not bird.hop_requested.is_connected(_on_hop_requested):
			bird.hop_requested.connect(_on_hop_requested.bind(bird))


func _sample_perch() -> Vector3:
	var x_mag := _rng.randf_range(PERCH_X_INNER, PERCH_X_OUTER)
	if _rng.randf() < 0.55:
		x_mag = _rng.randf_range(PERCH_X_INNER, 13.5)
	var x := x_mag if _rng.randf() < 0.5 else -x_mag
	## Smooth front bias: u^k clusters toward the near edge (PERCH_Z_NEAR).
	var depth_t := pow(_rng.randf(), PERCH_FRONT_BIAS)
	var z := lerpf(PERCH_Z_NEAR, PERCH_Z_FAR, depth_t)
	if _in_bay_exclusion(x, z):
		z = minf(z, PERCH_Z_NEAR - 2.0)
		if absf(x) < BAY_EXCLUSION_X:
			x = signf(x) * BAY_EXCLUSION_X if x != 0.0 else BAY_EXCLUSION_X
	return Vector3(x, RangeBird.PERCH_Y, z)


func _sample_approach(perch: Vector3) -> Vector3:
	var side := signf(perch.x)
	if side == 0.0:
		side = 1.0 if _rng.randf() < 0.5 else -1.0
	if _rng.randf() < 0.35:
		side = -side
	var x := side * _rng.randf_range(SIDE_SPAWN_X - 3.0, SIDE_SPAWN_X + 4.0)
	var y := _rng.randf_range(MIN_APPROACH_Y, MAX_APPROACH_Y)
	var z := perch.z + _rng.randf_range(2.0, 10.0)
	return Vector3(x, y, z)


func _sample_exit(from: Vector3, right: Vector3 = Vector3.RIGHT, side: float = 0.0) -> Vector3:
	if side == 0.0:
		side = 1.0 if _rng.randf() < 0.5 else -1.0
	var lateral := right.normalized() * (side * _rng.randf_range(10.0, 18.0))
	var y := _rng.randf_range(MIN_APPROACH_Y + 1.0, MAX_APPROACH_Y + 2.0)
	var z := from.z + _rng.randf_range(1.0, 8.0)
	return Vector3(from.x + lateral.x, y, z + lateral.z)


func _perch_free(candidate: Vector3) -> bool:
	for bird in _birds:
		if not bird.is_busy():
			continue
		if bird.perch.distance_to(candidate) < PERCH_MIN_SEP:
			return false
	return true


func _in_bay_exclusion(x: float, z: float) -> bool:
	return absf(x) < BAY_EXCLUSION_X and z > BAY_EXCLUSION_Z_NEAR


func _day_factor() -> float:
	var cycle := get_parent().get_node_or_null("DayNightCycle") if get_parent() else null
	if cycle != null and cycle.has_method("cycle_elapsed"):
		return DayNightPalette.day_light_factor(cycle.cycle_elapsed())
	return 1.0


func _find_strike_camera() -> Camera3D:
	var parent := get_parent()
	if parent == null:
		return null
	if parent.has_method("get_perspective_camera"):
		return parent.get_perspective_camera()
	return parent.get_node_or_null("PerspectiveCamera") as Camera3D


func _find_active_camera() -> Camera3D:
	var parent := get_parent()
	if parent == null:
		return _camera
	if parent.has_method("get_flight_camera"):
		var cam: Camera3D = parent.get_flight_camera()
		if cam != null:
			_camera = cam
			return cam
	if parent.has_method("get_camera"):
		var cam2: Camera3D = parent.get_camera()
		if cam2 != null:
			_camera = cam2
			return cam2
	return _find_strike_camera()
