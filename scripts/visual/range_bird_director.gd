class_name RangeBirdDirector
extends Node3D
## Fairway perch birds + high sky flyover packs across the 300yd range.

enum Mood { QUIET, NORMAL, BUSY }

const POOL_SIZE := 32
const PERCH_MIN_SEP := 3.8
const FLUSH_RADIUS := 12.0
const STARTLE_HOP_RADIUS := 22.0
const BAY_EXCLUSION_X := 8.0
const BAY_EXCLUSION_Z_NEAR := -24.0
const PERCH_Z_NEAR := -28.0
## Most of VISUAL_MAX_YARDS (world unit = 1 yard).
const PERCH_Z_FAR := -250.0
## Softened so mid/deep fairway still get birds.
const PERCH_FRONT_BIAS := 1.75
const PERCH_X_INNER := 6.0
const PERCH_X_OUTER := 17.0
const MIN_APPROACH_Y := 9.0
const MAX_APPROACH_Y := 15.0
const MIN_FLYOVER_Y := 11.0
const MAX_FLYOVER_Y := 17.0
const SIDE_SPAWN_X := 24.0
const TREELINE_SCREEN_Y := 0.40
const PAIR_CHANCE := 0.28
## Screen-space click radius (px) for perched birds in harvest ortho.
const CLICK_RADIUS_PX := 36.0
const SQUAWK_COOLDOWN_SEC := 0.4

var _birds: Array[RangeBird] = []
var _rng := RandomNumberGenerator.new()
var _camera: Camera3D
var _next_arrival := 1.2
var _next_pack := 8.0
var _atmosphere_tint := Color.WHITE
var _range_view: Node = null
var _mood: Mood = Mood.NORMAL
var _mood_left := 30.0
var _perch_target := 12
var _squawk_cooldown := 0.0


func _ready() -> void:
	_rng.randomize()
	_range_view = get_parent()
	_camera = _find_active_camera()
	_build_pool()
	if Engine.is_editor_hint():
		set_process(false)
		return
	var bus := get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("fairway_impact"):
		if not bus.fairway_impact.is_connected(_on_fairway_impact):
			bus.fairway_impact.connect(_on_fairway_impact)
	_roll_mood()
	_launch_arrival()
	_next_arrival = _rng.randf_range(1.5, 4.0)
	_schedule_next_pack()
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


func perch_lifecycle_count() -> int:
	var n := 0
	for bird in _birds:
		if bird.is_perch_lifecycle():
			n += 1
	return n


func flyover_count() -> int:
	var n := 0
	for bird in _birds:
		if bird.is_flyover():
			n += 1
	return n


func target_active_count() -> int:
	return target_perch_count()


func target_perch_count() -> int:
	var day_factor := _day_factor()
	var target := _perch_target
	## Night dampens toward quiet.
	if day_factor < 0.22:
		target = mini(target, 5)
	elif day_factor < 0.55:
		target = mini(target, 12)
	return target


func current_mood() -> Mood:
	return _mood


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
	for _i in 24:
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
	_squawk_cooldown = maxf(_squawk_cooldown - delta, 0.0)
	_mood_left -= delta
	if _mood_left <= 0.0:
		_roll_mood()

	_next_arrival -= delta
	if _next_arrival <= 0.0:
		var perch_cap := target_perch_count()
		if perch_lifecycle_count() < perch_cap:
			_launch_arrival()
			if (
				_rng.randf() < PAIR_CHANCE
				and perch_lifecycle_count() < perch_cap
			):
				_launch_arrival()
			## Busy mood: burst a few more arrivals when slots are free.
			if _mood == Mood.BUSY:
				for _i in 2:
					if perch_lifecycle_count() >= perch_cap:
						break
					if _rng.randf() < 0.55:
						_launch_arrival()
		_next_arrival = _rng.randf_range(1.8, 5.5)

	_next_pack -= delta
	if _next_pack <= 0.0:
		_try_launch_packs()
		_schedule_next_pack()


func _roll_mood() -> void:
	var roll := _rng.randf()
	if roll < 0.22:
		_mood = Mood.QUIET
		_perch_target = _rng.randi_range(4, 6)
	elif roll < 0.72:
		_mood = Mood.NORMAL
		_perch_target = _rng.randi_range(10, 14)
	else:
		_mood = Mood.BUSY
		_perch_target = _rng.randi_range(16, 20)
	_mood_left = _rng.randf_range(20.0, 50.0)


func _schedule_next_pack() -> void:
	match _mood:
		Mood.QUIET:
			_next_pack = _rng.randf_range(28.0, 48.0)
		Mood.BUSY:
			_next_pack = _rng.randf_range(8.0, 16.0)
		_:
			_next_pack = _rng.randf_range(14.0, 28.0)


func _try_launch_packs() -> void:
	var packs := 1
	if _mood == Mood.BUSY and _rng.randf() < 0.45:
		packs = 2
	elif _mood == Mood.QUIET and _rng.randf() < 0.55:
		## Quiet often skips the pack tick entirely.
		return
	for _i in packs:
		_launch_flyover_pack()


func _pack_size_for_mood() -> int:
	match _mood:
		Mood.QUIET:
			return _rng.randi_range(4, 5)
		Mood.BUSY:
			return _rng.randi_range(5, 8)
		_:
			return _rng.randi_range(5, 7)


func _launch_flyover_pack() -> void:
	var size := _pack_size_for_mood()
	var idle := _idle_count()
	if idle < 3:
		return
	size = mini(size, idle)
	var species := _rng.randi_range(0, SkyBirdFrames.SPECIES_COUNT - 1)
	var path := _sample_flyover_path()
	var right := path["right"] as Vector3
	var from_base: Vector3 = path["from"]
	var to_base: Vector3 = path["to"]
	for i in size:
		## Shallow V: lead bird on the path, trailers offset back/side.
		var wing := float(i) - float(size - 1) * 0.5
		var lateral := right * (wing * 0.55)
		var trail := (from_base - to_base).normalized() * (absf(wing) * 0.85)
		var from := from_base + lateral + trail
		var to := to_base + lateral + trail * 0.35
		from.y = clampf(from.y + _rng.randf_range(-0.4, 0.4), MIN_FLYOVER_Y, MAX_FLYOVER_Y)
		to.y = clampf(to.y + _rng.randf_range(-0.4, 0.4), MIN_FLYOVER_Y, MAX_FLYOVER_Y)
		var delay := float(i) * _rng.randf_range(0.08, 0.16)
		if delay <= 0.001:
			_spawn_flyover_member(from, to, species)
		else:
			get_tree().create_timer(delay).timeout.connect(
				_spawn_flyover_member.bind(from, to, species)
			)


func _spawn_flyover_member(from: Vector3, to: Vector3, species: int) -> void:
	if not is_inside_tree():
		return
	var bird := _idle_bird()
	if bird == null:
		return
	bird.start_flyover(from, to, species)


func _sample_flyover_path() -> Dictionary:
	var strike_cam := _find_strike_camera()
	var right := Vector3.RIGHT
	if strike_cam != null and strike_cam.is_inside_tree():
		right = strike_cam.global_transform.basis.x.normalized()
	var go_right := _rng.randf() < 0.5
	var side_in := 1.0 if go_right else -1.0
	var z := _sample_flyover_z()
	var y := _rng.randf_range(MIN_FLYOVER_Y, MAX_FLYOVER_Y)
	var from := Vector3(side_in * -SIDE_SPAWN_X, y, z)
	var to := Vector3(side_in * SIDE_SPAWN_X, y + _rng.randf_range(-0.8, 1.2), z + _rng.randf_range(-6.0, 6.0))
	## Nudge altitude up until treeline-safe when a camera exists.
	for _i in 6:
		if is_above_treeline(strike_cam, from) and is_above_treeline(strike_cam, to):
			break
		from.y = minf(from.y + 1.2, MAX_FLYOVER_Y + 2.0)
		to.y = minf(to.y + 1.2, MAX_FLYOVER_Y + 2.0)
	return {"from": from, "to": to, "right": right}


func _sample_flyover_z() -> float:
	## Near / mid / far sky bands across the 300yd fairway.
	var band := _rng.randi() % 3
	match band:
		0:
			return _rng.randf_range(-40.0, -90.0)
		1:
			return _rng.randf_range(-90.0, -160.0)
		_:
			return _rng.randf_range(-160.0, -240.0)


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
		_play_squawk_throttled()
	bird.flush_to(pick_exit(bird.position, bird.faces_screen_right()))


func _on_leave_requested(bird: RangeBird) -> void:
	if bird == null or not bird.is_perched():
		return
	bird.takeoff_to(pick_exit(bird.position, bird.faces_screen_right()))


func _on_hop_requested(bird: RangeBird) -> void:
	if bird == null or not bird.is_perched():
		return
	var next := _pick_startle_hop(bird)
	if next == Vector3.ZERO:
		return
	bird.hop_to(next)


func _pick_startle_hop(bird: RangeBird) -> Vector3:
	var next := pick_perch()
	if next.distance_to(bird.position) > 18.0:
		return Vector3.ZERO
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
			if next.distance_to(bird.position) > 18.0:
				return Vector3.ZERO
	return next


func _on_fairway_impact(world_pos: Vector3) -> void:
	var flushed := 0
	for bird in _birds:
		if not bird.is_perched():
			continue
		var dist := bird.position.distance_to(world_pos)
		if dist <= FLUSH_RADIUS:
			bird.flush_to(pick_exit(bird.position, bird.faces_screen_right()))
			flushed += 1
		elif dist <= STARTLE_HOP_RADIUS and _rng.randf() < 0.55:
			var hop := _pick_startle_hop(bird)
			if hop != Vector3.ZERO:
				bird.hop_to(hop)
	if flushed > 0:
		_play_squawk_throttled()


func _play_squawk_throttled() -> void:
	if _squawk_cooldown > 0.0:
		return
	var sfx := get_node_or_null("/root/SfxManager")
	if sfx != null and sfx.has_method("play_bird_squawk"):
		sfx.play_bird_squawk()
	_squawk_cooldown = SQUAWK_COOLDOWN_SEC


func _idle_bird() -> RangeBird:
	for bird in _birds:
		if not bird.is_busy():
			return bird
	return null


func _idle_count() -> int:
	var n := 0
	for bird in _birds:
		if not bird.is_busy():
			n += 1
	return n


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
		if not bird.is_busy() or bird.is_flyover():
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
