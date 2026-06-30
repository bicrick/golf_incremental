extends SceneTree
## Headless day/night cycle tests — run:
## godot --headless --script res://tools/verify_day_night.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_phase_durations() and ok
	ok = _check_night_blend_curve() and ok
	ok = await _check_atmosphere_application() and ok
	ok = await _check_celestial_crossfade() and ok
	print("day_night_ok=", ok)
	quit(0 if ok else 1)


func _check_phase_durations() -> bool:
	if DayNightPalette.DAY_SEC != 60.0:
		print("FAIL: DAY_SEC expected 60, got ", DayNightPalette.DAY_SEC)
		return false
	if DayNightPalette.NIGHT_SEC != 30.0:
		print("FAIL: NIGHT_SEC expected 30, got ", DayNightPalette.NIGHT_SEC)
		return false
	print("OK: phase durations 60s day / 30s night")
	return true


func _check_night_blend_curve() -> bool:
	var day_steady := DayNightPalette.compute_night_blend(true, 10.0)
	if absf(day_steady) > 0.001:
		print("FAIL: mid-day night_blend expected 0, got ", day_steady)
		return false

	var night_steady := DayNightPalette.compute_night_blend(false, 10.0)
	if absf(night_steady - 1.0) > 0.001:
		print("FAIL: mid-night night_blend expected 1, got ", night_steady)
		return false

	var dusk := DayNightPalette.compute_night_blend(true, DayNightPalette.DAY_SEC - 1.5)
	if dusk <= 0.2 or dusk >= 0.9:
		print("FAIL: dusk night_blend out of range, got ", dusk)
		return false

	var dawn := DayNightPalette.compute_night_blend(false, DayNightPalette.NIGHT_SEC - 1.5)
	if dawn <= 0.1 or dawn >= 0.8:
		print("FAIL: dawn night_blend out of range, got ", dawn)
		return false

	print("OK: night_blend curve at day/night/dusk/dawn")
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

	range_view.apply_atmosphere(0.0)
	var sky_day: Polygon2D = range_view.get_node("ParallaxSky/Sky")
	var canvas: CanvasModulate = range_view.get_node("CanvasModulate")
	if sky_day.color.is_equal_approx(DayNightPalette.SKY_NIGHT):
		print("FAIL: sky still night-colored at day blend")
		range_view.queue_free()
		return false
	if not canvas.color.is_equal_approx(DayNightPalette.CANVAS_MODULATE_DAY):
		print("FAIL: canvas modulate not day at blend 0")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(1.0)
	if not sky_day.color.is_equal_approx(DayNightPalette.SKY_NIGHT):
		print("FAIL: sky not night-colored at blend 1")
		range_view.queue_free()
		return false
	if canvas.color.g > 0.7:
		print("FAIL: canvas modulate not dimmed at night")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: apply_atmosphere tints sky and canvas modulate")
	return true


func _check_celestial_crossfade() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	var range_view: Node2D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var sun: Node2D = range_view.get_node("ParallaxSky/Sun")
	var moon: Node2D = range_view.get_node("ParallaxSky/Moon")

	range_view.apply_atmosphere(0.0)
	if sun.modulate.a <= moon.modulate.a:
		print("FAIL: sun should dominate at day (sun=", sun.modulate.a, " moon=", moon.modulate.a, ")")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(1.0)
	if moon.modulate.a <= sun.modulate.a:
		print("FAIL: moon should dominate at night (sun=", sun.modulate.a, " moon=", moon.modulate.a, ")")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: sun/moon alpha crossfade")
	return true
