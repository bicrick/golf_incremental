extends Node2D
## Procedural night stars for the range sky — fade with day/night cycle.

const STAR_COUNT := 42
const TWINKLE_FREQ := 0.35
const TWINKLE_AMP := 0.08

var _stars: Array[Dictionary] = []
var _base_alpha := 0.0
var _twinkle_time := 0.0


func _ready() -> void:
	_build_stars()
	modulate.a = 0.0
	set_process(true)


func _build_stars() -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 918273
	for _i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(rng.randf_range(18.0, 462.0), rng.randf_range(8.0, 68.0)),
			"radius": rng.randf_range(0.6, 1.4),
			"phase": rng.randf_range(0.0, TAU),
			"brightness": rng.randf_range(0.55, 1.0),
		})
	queue_redraw()


func apply_visibility(cycle_alpha: float) -> void:
	_base_alpha = clampf(cycle_alpha, 0.0, 1.0)
	if _base_alpha <= 0.001:
		modulate.a = 0.0


func _process(delta: float) -> void:
	if _base_alpha <= 0.001:
		if modulate.a > 0.001:
			modulate.a = 0.0
		return
	_twinkle_time += delta
	var twinkle := 1.0
	if _stars.size() > 0:
		twinkle = 1.0 + TWINKLE_AMP * sin(_twinkle_time * TWINKLE_FREQ * TAU)
	modulate.a = clampf(_base_alpha * twinkle, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if modulate.a <= 0.001:
		return
	for star in _stars:
		var flicker := 0.88 + 0.12 * sin(_twinkle_time * 2.1 + float(star["phase"]))
		var color := Color(0.92, 0.95, 1.0, float(star["brightness"]) * flicker)
		draw_circle(star["pos"], float(star["radius"]), color)
