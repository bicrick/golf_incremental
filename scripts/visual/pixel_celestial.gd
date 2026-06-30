extends Node2D
## Procedural 8-bit sun or moon disc for the sky layer.

enum Kind { SUN, MOON }

@export var kind: Kind = Kind.SUN

const SUN_RADIUS := 10.0
const MOON_RADIUS := 9.0
const PIXEL := 2.0

var _moon_sky_cutout: Color = DayNightPalette.SKY_NIGHT


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.SUN:
			_draw_sun()
		Kind.MOON:
			_draw_moon()


func _draw_sun() -> void:
	var r := SUN_RADIUS
	draw_circle(Vector2.ZERO, r + PIXEL, Color(1.0, 0.82, 0.35, 0.45))
	draw_circle(Vector2.ZERO, r, DayNightPalette.SUN_COLOR)
	draw_circle(Vector2(-3.0, -3.0), r * 0.35, Color(1.0, 0.98, 0.75, 0.55))


func _draw_moon() -> void:
	var r := MOON_RADIUS
	draw_circle(Vector2.ZERO, r + PIXEL * 0.5, Color(0.65, 0.72, 0.88, 0.35))
	draw_circle(Vector2.ZERO, r, DayNightPalette.MOON_COLOR)
	draw_circle(Vector2(4.0, -2.0), r * 0.82, _moon_sky_cutout)


func apply_celestial(
	sky_position: Vector2,
	alpha: float,
	moon_sky_cutout: Color = DayNightPalette.SKY_NIGHT
) -> void:
	position = sky_position
	modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	if kind == Kind.MOON and not _moon_sky_cutout.is_equal_approx(moon_sky_cutout):
		_moon_sky_cutout = moon_sky_cutout
		queue_redraw()
