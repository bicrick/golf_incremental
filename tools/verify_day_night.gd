extends SceneTree
## Headless day/night cycle tests — run:
## godot --headless --script res://tools/verify_day_night.gd

const DAY_TIME := 60.0
const NIGHT_TIME := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_cycle_duration() and ok
	ok = _check_phase_sampling() and ok
	ok = _check_smooth_transitions() and ok
	ok = _check_celestial_arc() and ok
	ok = await _check_celestial_placement() and ok
	ok = await _check_atmosphere_application() and ok
	ok = await _check_yardage_marker_atmosphere() and ok
	ok = await _check_ground_mesh_stability() and ok
	ok = await _check_sun_light_scene() and ok
	ok = await _check_celestial_lights_and_fog() and ok
	ok = await _check_procedural_sky() and ok
	ok = await _check_gameplay_ui_atmosphere() and ok
	print("day_night_ok=", ok)
	quit(0 if ok else 1)


func _check_cycle_duration() -> bool:
	if DayNightPalette.CYCLE_SEC != 120.0:
		print("FAIL: CYCLE_SEC expected 120, got ", DayNightPalette.CYCLE_SEC)
		return false
	if DayNightPalette.PHASE_SEC != 30.0:
		print("FAIL: PHASE_SEC expected 30, got ", DayNightPalette.PHASE_SEC)
		return false
	print("OK: 120s multi-phase cycle")
	return true


func _check_phase_sampling() -> bool:
	var day_snap := DayNightPalette.sample_at(DAY_TIME)
	if not day_snap.sky.is_equal_approx(DayNightPalette.SKY_DAY):
		print("FAIL: mid-day sky mismatch at t=", DAY_TIME)
		return false

	var midnight_moon_alpha := DayNightPalette.celestial_alpha(NIGHT_TIME, true)
	var midnight_sun_alpha := DayNightPalette.celestial_alpha(NIGHT_TIME, false)
	if midnight_sun_alpha > 0.15:
		print("FAIL: sun should be below horizon at midnight, alpha=", midnight_sun_alpha)
		return false
	if midnight_moon_alpha < 0.7:
		print("FAIL: moon should be high at midnight, alpha=", midnight_moon_alpha)
		return false

	var dusk_snap := DayNightPalette.sample_at(DayNightPalette.PHASE_SEC * 3.0)
	if dusk_snap.sky.r <= day_snap.sky.r:
		print("FAIL: dusk sky should be warmer/brighter red than day")
		return false

	if DayNightPalette.phase_name_at(75.0) != "day":
		print("FAIL: phase_name_at(75) expected day")
		return false
	if DayNightPalette.phase_name_at(105.0) != "night":
		print("FAIL: phase_name_at(105) expected night")
		return false

	print("OK: phase sampling at day/dusk/midnight")
	return true


func _check_smooth_transitions() -> bool:
	var prev := DayNightPalette.sample_at(0.0)
	var max_step := 0.0
	for i in range(1, int(DayNightPalette.CYCLE_SEC) + 1):
		var snap := DayNightPalette.sample_at(float(i))
		var step := prev.sky.r - snap.sky.r
		step *= step
		step += (prev.sky.g - snap.sky.g) * (prev.sky.g - snap.sky.g)
		step += (prev.sky.b - snap.sky.b) * (prev.sky.b - snap.sky.b)
		step = sqrt(step)
		max_step = maxf(max_step, step)
		prev = snap
	if max_step > 0.25:
		print("FAIL: per-second sky jump too large (", max_step, ")")
		return false

	var dawn_mid := DayNightPalette.sample_at(DayNightPalette.PHASE_SEC * 0.5)
	var midnight := DayNightPalette.sample_at(0.0)
	var day := DayNightPalette.sample_at(DAY_TIME)
	if dawn_mid.sky.g <= midnight.sky.g or dawn_mid.sky.g >= day.sky.g:
		print("FAIL: dawn midpoint not between midnight and day")
		return false

	print("OK: smooth transitions between phases")
	return true


func _check_celestial_arc() -> bool:
	var moon_at_day := DayNightPalette.celestial_alpha(DAY_TIME, true)
	if moon_at_day > 0.15:
		print("FAIL: moon should be hidden during day, alpha=", moon_at_day)
		return false

	var sun_at_day := DayNightPalette.celestial_alpha(DAY_TIME, false)
	if sun_at_day < 0.7:
		print("FAIL: sun should be visible at noon, alpha=", sun_at_day)
		return false

	var sun_at_midnight := DayNightPalette.celestial_alpha(NIGHT_TIME, false)
	if sun_at_midnight > 0.15:
		print("FAIL: sun should be below horizon at midnight, alpha=", sun_at_midnight)
		return false

	var moon_elev_midnight := DayNightPalette.celestial_elevation(NIGHT_TIME, true)
	if moon_elev_midnight < 0.85:
		print("FAIL: moon should be high at midnight, elev=", moon_elev_midnight)
		return false

	print("OK: sun by day, moon by night, below horizon when down")
	return true


func _check_celestial_placement() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn for celestial placement")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var sun_noon := DayNightPalette.celestial_view_direction(DAY_TIME, false, Vector3.ZERO)
	if sun_noon.y < 0.85:
		print("FAIL: noon sun should be near zenith, y=", sun_noon.y)
		range_view.queue_free()
		return false
	if absf(sun_noon.x) > 0.05:
		print("FAIL: noon sun should stay on fairway -Z axis (x≈0), x=", sun_noon.x)
		range_view.queue_free()
		return false

	var sun_dawn := DayNightPalette.celestial_view_direction(30.0, false, Vector3.ZERO)
	if sun_dawn.z > -0.85 or absf(sun_dawn.x) > 0.05:
		print("FAIL: dawn sun should be on far -Z horizon, dir=", sun_dawn)
		range_view.queue_free()
		return false

	var sun_midnight := DayNightPalette.celestial_view_direction(NIGHT_TIME, false, Vector3.ZERO)
	if sun_midnight.y > -0.5:
		print("FAIL: midnight sun should be below horizon, y=", sun_midnight.y)
		range_view.queue_free()
		return false

	var moon_midnight := DayNightPalette.celestial_view_direction(NIGHT_TIME, true, Vector3.ZERO)
	if moon_midnight.y < 0.85:
		print("FAIL: midnight moon should be opposite the sun, y=", moon_midnight.y)
		range_view.queue_free()
		return false
	if absf(moon_midnight.x) > 0.05:
		print("FAIL: midnight moon should stay on fairway -Z axis (x≈0), x=", moon_midnight.x)
		range_view.queue_free()
		return false

	for check_time in [0.0, 30.0, 60.0, 90.0]:
		var sun_v := DayNightPalette.celestial_view_direction(check_time, false, Vector3.ZERO)
		var moon_v := DayNightPalette.celestial_view_direction(check_time, true, Vector3.ZERO)
		if absf(sun_v.x) > 0.05 or absf(moon_v.x) > 0.05:
			print("FAIL: celestial dirs should stay on -Z axis (x≈0) at t=", check_time)
			range_view.queue_free()
			return false
		if absf(sun_v.dot(moon_v) + 1.0) > 0.15:
			print(
				"FAIL: sun/moon should stay 180° apart at t=%.0f, dot=%.3f"
				% [check_time, sun_v.dot(moon_v)]
			)
			range_view.queue_free()
			return false

	range_view.queue_free()
	print("OK: fairway -Z orbit with rise/set and 180° opposition")
	return true


func _check_atmosphere_application() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	if not range_view.has_method(&"apply_atmosphere"):
		print("FAIL: range_view missing apply_atmosphere")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(DAY_TIME)
	var world_env: WorldEnvironment = range_view.get_node("WorldEnvironment")
	var env := world_env.environment
	if env.background_mode != Environment.BG_SKY:
		print("FAIL: expected Environment.BG_SKY, got ", env.background_mode)
		range_view.queue_free()
		return false
	if not env.background_color.is_equal_approx(DayNightPalette.SKY_DAY):
		print("FAIL: background not day-colored at t=", DAY_TIME)
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(0.0)
	if env.background_color.g > 0.2:
		print("FAIL: background not dark at midnight")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: apply_atmosphere drives WorldEnvironment background by cycle time")
	return true


func _check_yardage_marker_atmosphere() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn for yardage marker tint check")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var cycle: Node = range_view.get_node_or_null("DayNightCycle")
	if cycle:
		cycle.set_process(false)

	var markers: Node3D = range_view.get_node_or_null("Foreground/YardageMarkers")
	if markers == null or markers.get_child_count() < 12:
		print("FAIL: YardageMarkers missing or incomplete (need left+right sets)")
		range_view.queue_free()
		return false

	var day_tint := DayNightPalette.sample_at(DAY_TIME).canvas_modulate
	var night_tint := DayNightPalette.sample_at(NIGHT_TIME).canvas_modulate
	if day_tint.is_equal_approx(night_tint):
		print("FAIL: day and night canvas_modulate should differ")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(DAY_TIME)
	for child in markers.get_children():
		if child is SpriteBase3D and not (child as SpriteBase3D).modulate.is_equal_approx(day_tint):
			print("FAIL: ", child.name, " day modulate expected ", day_tint, " got ", (child as SpriteBase3D).modulate)
			range_view.queue_free()
			return false

	range_view.apply_atmosphere(NIGHT_TIME)
	for child in markers.get_children():
		if child is SpriteBase3D and not (child as SpriteBase3D).modulate.is_equal_approx(night_tint):
			print("FAIL: ", child.name, " night modulate expected ", night_tint, " got ", (child as SpriteBase3D).modulate)
			range_view.queue_free()
			return false

	range_view.queue_free()
	print("OK: yardage markers follow DayNightPalette canvas_modulate")
	return true


func _check_ground_mesh_stability() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn for mesh stability check")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var ground: MeshInstance3D = range_view.get_node("Ground")
	if ground.mesh == null:
		print("FAIL: ground mesh should be built on load")
		range_view.queue_free()
		return false

	var ground_mesh_id := ground.mesh.get_instance_id()
	var ground_vert_count := ground.mesh.get_surface_count()
	if ground_vert_count < 1:
		print("FAIL: ground mesh missing surfaces after load")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(DAY_TIME)
	await process_frame
	range_view.apply_atmosphere(0.0)
	await process_frame

	if ground.mesh.get_instance_id() != ground_mesh_id:
		print("FAIL: apply_atmosphere replaced Ground mesh")
		range_view.queue_free()
		return false

	var ground_verts: int = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	if ground_verts != 4:
		print("FAIL: Ground mesh should be a single quad, got ", ground_verts, " verts")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: apply_atmosphere updates palette without rebuilding ground meshes")
	return true


func _check_sun_light_scene() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var sun: DirectionalLight3D = range_view.get_node("Sun")

	range_view.apply_atmosphere(DAY_TIME)
	var day_energy := sun.light_energy
	range_view.apply_atmosphere(0.0)
	var night_energy := sun.light_energy

	if day_energy <= 0.5:
		print("FAIL: sun should be bright at midday, energy=", day_energy)
		range_view.queue_free()
		return false
	if night_energy > 0.01:
		print("FAIL: sun energy should be ~0 at midnight, got ", night_energy)
		range_view.queue_free()
		return false
	if day_energy <= night_energy:
		print(
			"FAIL: sun light should be brighter by day than at midnight (day=%.2f night=%.2f)"
			% [day_energy, night_energy]
		)
		range_view.queue_free()
		return false

	if sun.shadow_enabled:
		print("FAIL: sun shadows should stay disabled (billboards cast odd shadows)")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print(
		"OK: DirectionalLight3D energy follows day/night (day=%.2f night=%.2f)"
		% [day_energy, night_energy]
	)
	return true


func _check_celestial_lights_and_fog() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn for celestial lights/fog check")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var sun: DirectionalLight3D = range_view.get_node_or_null("Sun")
	var moon: DirectionalLight3D = range_view.get_node_or_null("Moon")
	if sun == null or moon == null:
		print("FAIL: RangeView missing Sun or Moon DirectionalLight3D")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(DAY_TIME)
	var sun_dir_day := DayNightPalette.celestial_view_direction(DAY_TIME, false, Vector3.ZERO)
	var sun_forward := -sun.global_transform.basis.z.normalized()
	if sun_forward.dot(-sun_dir_day) < 0.95:
		print(
			"FAIL: midday sun -Z should align with -celestial dir, dot=",
			sun_forward.dot(-sun_dir_day)
		)
		range_view.queue_free()
		return false
	if moon.light_energy > 0.01:
		print("FAIL: moon energy should be ~0 at midday, got ", moon.light_energy)
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(NIGHT_TIME)
	if sun.light_energy > 0.01:
		print("FAIL: sun energy should be ~0 at midnight, got ", sun.light_energy)
		range_view.queue_free()
		return false
	if moon.light_energy <= 0.05:
		print("FAIL: moon should be visible at midnight, energy=", moon.light_energy)
		range_view.queue_free()
		return false
	var moon_dir := DayNightPalette.celestial_view_direction(NIGHT_TIME, true, Vector3.ZERO)
	var moon_forward := -moon.global_transform.basis.z.normalized()
	if moon_forward.dot(-moon_dir) < 0.95:
		print(
			"FAIL: midnight moon -Z should align with -celestial dir, dot=",
			moon_forward.dot(-moon_dir)
		)
		range_view.queue_free()
		return false
	if moon.shadow_enabled:
		print("FAIL: moon shadows should stay disabled")
		range_view.queue_free()
		return false

	var world_env: WorldEnvironment = range_view.get_node("WorldEnvironment")
	var env := world_env.environment
	if env.fog_enabled:
		print("FAIL: fog should stay disabled")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: sun/moon aim+energy on fairway -Z axis; fog disabled")
	return true


func _check_procedural_sky() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn for procedural sky check")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	if range_view.get_node_or_null("SkyDome") != null:
		print("FAIL: SkyDome mesh path should be removed")
		range_view.queue_free()
		return false

	var world_env: WorldEnvironment = range_view.get_node("WorldEnvironment")
	var env := world_env.environment
	if env.background_mode != Environment.BG_SKY:
		print("FAIL: expected Environment.BG_SKY, got ", env.background_mode)
		range_view.queue_free()
		return false
	if env.sky == null:
		print("FAIL: Environment missing Sky resource")
		range_view.queue_free()
		return false

	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		print("FAIL: expected ProceduralSkyMaterial on Environment.sky")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(DAY_TIME)
	var day_horizon := DayNightPalette.SKY_DAY.lightened(0.12)
	var day_top := DayNightPalette.SKY_DAY.darkened(0.08)
	if not sky_mat.sky_horizon_color.is_equal_approx(day_horizon):
		print(
			"FAIL: day sky_horizon_color expected ",
			day_horizon,
			" got ",
			sky_mat.sky_horizon_color
		)
		range_view.queue_free()
		return false
	if not sky_mat.sky_top_color.is_equal_approx(day_top):
		print("FAIL: day sky_top_color expected ", day_top, " got ", sky_mat.sky_top_color)
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(NIGHT_TIME)
	var night_snap := DayNightPalette.sample_at(NIGHT_TIME)
	var night_horizon := night_snap.sky.lightened(0.12)
	if not sky_mat.sky_horizon_color.is_equal_approx(night_horizon):
		print(
			"FAIL: night sky_horizon_color expected ",
			night_horizon,
			" got ",
			sky_mat.sky_horizon_color
		)
		range_view.queue_free()
		return false
	if sky_mat.sky_top_color.g > 0.25:
		print("FAIL: night sky_top_color should be dark, got ", sky_mat.sky_top_color)
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: ProceduralSkyMaterial colors follow day/night cycle")
	return true


func _check_gameplay_ui_atmosphere() -> bool:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		print("FAIL: could not load main.tscn for gameplay UI atmosphere check")
		return false

	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var range_view: Node3D = main.get_node("RangeView")
	var gameplay_chrome: CanvasItem = main.get_node("UI/UIRoot/GameplayChrome")
	if gameplay_chrome == null:
		print("FAIL: GameplayChrome missing from main scene")
		main.queue_free()
		return false

	range_view.apply_atmosphere(0.0)
	await process_frame
	var midnight_tint := DayNightPalette.sample_at(0.0).canvas_modulate
	var expected_midnight: Color = UiTheme.ui_atmosphere_modulate(midnight_tint)
	if not gameplay_chrome.modulate.is_equal_approx(expected_midnight):
		print(
			"FAIL: GameplayChrome modulate at midnight expected %s, got %s"
			% [expected_midnight, gameplay_chrome.modulate]
		)
		main.queue_free()
		return false

	range_view.apply_atmosphere(DAY_TIME)
	await process_frame
	var expected_day: Color = UiTheme.ui_atmosphere_modulate(Color.WHITE)
	if not gameplay_chrome.modulate.is_equal_approx(expected_day):
		print(
			"FAIL: GameplayChrome modulate at day expected %s, got %s"
			% [expected_day, gameplay_chrome.modulate]
		)
		main.queue_free()
		return false

	main.queue_free()
	print("OK: gameplay UI chrome uses soft day/night atmosphere tint")
	return true
