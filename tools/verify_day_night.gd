extends SceneTree
## Headless day/night cycle tests — run:
## godot --headless --script res://tools/verify_day_night.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_cycle_duration() and ok
	ok = _check_phase_sampling() and ok
	ok = _check_smooth_transitions() and ok
	ok = _check_celestial_arc() and ok
	ok = await _check_atmosphere_application() and ok
	ok = await _check_sun_light_scene() and ok
	ok = await _check_sky_dome() and ok
	print("day_night_ok=", ok)
	quit(0 if ok else 1)


func _check_cycle_duration() -> bool:
	if DayNightPalette.CYCLE_SEC != 120.0:
		print("FAIL: CYCLE_SEC expected 120, got ", DayNightPalette.CYCLE_SEC)
		return false
	print("OK: 120s multi-phase cycle")
	return true


func _check_phase_sampling() -> bool:
	var day_snap := DayNightPalette.sample_at(40.0)
	if not day_snap.sky.is_equal_approx(DayNightPalette.SKY_DAY):
		print("FAIL: mid-day sky mismatch at t=40")
		return false

	var midnight_moon_alpha := DayNightPalette.celestial_alpha(0.0, true)
	var midnight_sun_alpha := DayNightPalette.celestial_alpha(0.0, false)
	if midnight_sun_alpha > 0.15:
		print("FAIL: sun should be near horizon at midnight, alpha=", midnight_sun_alpha)
		return false
	if midnight_moon_alpha < 0.7:
		print("FAIL: moon should be high at midnight, alpha=", midnight_moon_alpha)
		return false

	var dusk_snap := DayNightPalette.sample_at(84.0)
	if dusk_snap.sky.r <= day_snap.sky.r:
		print("FAIL: dusk sky should be warmer/brighter red than day")
		return false

	if DayNightPalette.phase_name_at(45.0) != "day":
		print("FAIL: phase_name_at(45) expected day")
		return false
	if DayNightPalette.phase_name_at(98.0) != "night":
		print("FAIL: phase_name_at(98) expected night")
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

	var dawn_mid := DayNightPalette.sample_at(6.0)
	var midnight := DayNightPalette.sample_at(0.0)
	var day := DayNightPalette.sample_at(40.0)
	if dawn_mid.sky.g <= midnight.sky.g or dawn_mid.sky.g >= day.sky.g:
		print("FAIL: dawn midpoint not between midnight and day")
		return false

	print("OK: smooth transitions between phases")
	return true


func _check_celestial_arc() -> bool:
	var moon_at_day := DayNightPalette.celestial_alpha(50.0, true)
	if moon_at_day > 0.2:
		print("FAIL: moon should be below horizon during day, alpha=", moon_at_day)
		return false

	var sun_at_day := DayNightPalette.celestial_alpha(50.0, false)
	if sun_at_day < 0.7:
		print("FAIL: sun should be visible during day, alpha=", sun_at_day)
		return false

	var sun_at_midnight := DayNightPalette.celestial_alpha(0.0, false)
	if sun_at_midnight > 0.15:
		print("FAIL: sun should be near-absent at midnight, alpha=", sun_at_midnight)
		return false

	print("OK: sun/moon visibility follows day/night cycle")
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

	range_view.apply_atmosphere(40.0)
	var world_env: WorldEnvironment = range_view.get_node("WorldEnvironment")
	if not world_env.environment.background_color.is_equal_approx(DayNightPalette.SKY_DAY):
		print("FAIL: background not day-colored at t=40")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(0.0)
	if world_env.environment.background_color.g > 0.2:
		print("FAIL: background not dark at midnight")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: apply_atmosphere drives WorldEnvironment background by cycle time")
	return true


func _check_sun_light_scene() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var sun: DirectionalLight3D = range_view.get_node("Sun")

	range_view.apply_atmosphere(40.0)
	var day_energy := sun.light_energy
	range_view.apply_atmosphere(0.0)
	var night_energy := sun.light_energy

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


func _check_sky_dome() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn for sky dome check")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var sky_dome := range_view.get_node_or_null("SkyDome")
	if sky_dome == null:
		print("FAIL: RangeView missing SkyDome node")
		range_view.queue_free()
		return false

	if not sky_dome.has_method(&"update_atmosphere"):
		print("FAIL: SkyDome missing update_atmosphere")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(50.0)
	if not sky_dome.has_method(&"get_sun_alpha"):
		print("FAIL: SkyDome missing get_sun_alpha")
		range_view.queue_free()
		return false
	if sky_dome.get_sun_alpha() < 0.5:
		print("FAIL: sun should be visible during day, alpha=", sky_dome.get_sun_alpha())
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(0.0)
	if sky_dome.get_sun_alpha() > 0.15:
		print("FAIL: sun should be hidden at midnight, alpha=", sky_dome.get_sun_alpha())
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(110.0)
	if not sky_dome.has_method(&"get_star_alpha"):
		print("FAIL: SkyDome missing get_star_alpha")
		range_view.queue_free()
		return false
	if sky_dome.get_star_alpha() <= 0.0:
		print("FAIL: stars should be visible at night, alpha=", sky_dome.get_star_alpha())
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: SkyDome sun and star visibility follow day/night cycle")
	return true
