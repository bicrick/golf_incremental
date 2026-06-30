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
	ok = _check_decor_visibility() and ok
	ok = await _check_atmosphere_application() and ok
	ok = await _check_celestial_scene() and ok
	ok = await _check_sky_decor_scene() and ok
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
	var noon_pos := DayNightPalette.celestial_position(30.0, false)
	if noon_pos.y >= 40.0:
		print("FAIL: sun zenith should be above mountains, y=", noon_pos.y)
		return false

	var dawn_pos := DayNightPalette.celestial_position(11.0, false)
	var dusk_pos := DayNightPalette.celestial_position(58.0, false)

	if dawn_pos.x >= noon_pos.x:
		print("FAIL: sun should move right from dawn to noon")
		return false
	if noon_pos.y >= dawn_pos.y:
		print("FAIL: sun should be higher at noon than dawn")
		return false
	if dusk_pos.x <= noon_pos.x:
		print("FAIL: sun should continue right toward dusk")
		return false
	if dusk_pos.y <= noon_pos.y:
		print("FAIL: sun should be lower at dusk than noon")
		return false

	var moon_at_day := DayNightPalette.celestial_alpha(50.0, true)
	if moon_at_day > 0.2:
		print("FAIL: moon should be below horizon during day, alpha=", moon_at_day)
		return false

	var sun_at_day := DayNightPalette.celestial_alpha(50.0, false)
	if sun_at_day < 0.7:
		print("FAIL: sun should be visible during day, alpha=", sun_at_day)
		return false

	print("OK: sun/moon arc above mountains")
	return true


func _check_decor_visibility() -> bool:
	if DayNightPalette.DECOR_FADE_SEC != 8.0:
		print("FAIL: DECOR_FADE_SEC expected 8")
		return false

	if DayNightPalette.cloud_visibility(40.0) < 0.8:
		print("FAIL: clouds should be visible mid-day")
		return false
	if DayNightPalette.cloud_visibility(0.0) > 0.05:
		print("FAIL: clouds should be hidden at midnight")
		return false

	if DayNightPalette.star_visibility(0.0) < 0.8:
		print("FAIL: stars should be visible at midnight")
		return false
	if DayNightPalette.star_visibility(40.0) > 0.05:
		print("FAIL: stars should be hidden mid-day")
		return false

	var cloud_fade := DayNightPalette.cloud_visibility(20.0)
	if cloud_fade <= 0.05 or cloud_fade >= 0.95:
		print("FAIL: clouds should be partially faded during dawn fade window")
		return false

	var star_fade := DayNightPalette.star_visibility(17.0)
	if star_fade <= 0.05 or star_fade >= 0.95:
		print("FAIL: stars should be partially faded during dawn fade-out window")
		return false

	print("OK: cloud and star fade windows")
	return true


func _check_atmosphere_application() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn")
		return false

	var range_view: Node2D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	if not range_view.has_method(&"apply_atmosphere"):
		print("FAIL: range_view missing apply_atmosphere")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(40.0)
	var sky: Polygon2D = range_view.get_node("ParallaxSky/Sky")
	var canvas: CanvasModulate = range_view.get_node("CanvasModulate")
	if not sky.color.is_equal_approx(DayNightPalette.SKY_DAY):
		print("FAIL: sky not day-colored at t=40")
		range_view.queue_free()
		return false
	if not canvas.color.is_equal_approx(DayNightPalette.CANVAS_MODULATE_DAY):
		print("FAIL: canvas modulate not day at t=40")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(0.0)
	if sky.color.g > 0.2:
		print("FAIL: sky not dark at midnight")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: apply_atmosphere uses cycle time")
	return true


func _check_celestial_scene() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	var range_view: Node2D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var sun: Node2D = range_view.get_node("ParallaxSky/Sun")
	var moon: Node2D = range_view.get_node("ParallaxSky/Moon")

	range_view.apply_atmosphere(16.0)
	var sun_morning := sun.position
	range_view.apply_atmosphere(45.0)
	var sun_afternoon := sun.position
	if sun_afternoon.x <= sun_morning.x:
		print("FAIL: sun should travel right across the sky over time")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(50.0)
	if sun.modulate.a <= moon.modulate.a:
		print("FAIL: sun should dominate during day")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(0.0)
	if moon.modulate.a <= sun.modulate.a:
		print("FAIL: moon should dominate at midnight")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: celestial nodes follow arc in scene")
	return true


func _check_sky_decor_scene() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	var range_view: Node2D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var stars: Node2D = range_view.get_node_or_null("ParallaxSky/Stars")
	var clouds: Node2D = range_view.get_node_or_null("ParallaxSky/Clouds")
	var cycle: Node = range_view.get_node_or_null("DayNightCycle")
	if stars == null or clouds == null:
		print("FAIL: Stars or Clouds node missing from ParallaxSky")
		range_view.queue_free()
		return false

	if cycle != null and cycle.has_method(&"set_cycle_elapsed"):
		cycle.set_cycle_elapsed(40.0)
	range_view.apply_atmosphere(40.0)
	await process_frame
	if clouds.modulate.a < 0.8:
		print("FAIL: clouds node not visible mid-day")
		range_view.queue_free()
		return false
	if stars.modulate.a > 0.05:
		print("FAIL: stars node should be hidden mid-day")
		range_view.queue_free()
		return false

	if cycle != null and cycle.has_method(&"set_cycle_elapsed"):
		cycle.set_cycle_elapsed(0.0)
	range_view.apply_atmosphere(0.0)
	await process_frame
	if stars.modulate.a < 0.8:
		print("FAIL: stars node not visible at midnight")
		range_view.queue_free()
		return false
	if clouds.modulate.a > 0.05:
		print("FAIL: clouds node should be hidden at midnight")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: sky decor nodes fade with cycle")
	return true
