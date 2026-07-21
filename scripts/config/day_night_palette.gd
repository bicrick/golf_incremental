class_name DayNightPalette
extends RefCounted
## Multi-phase day/night palettes for the driving range — smooth keyframe interpolation.

const CYCLE_SEC := 120.0

const SUN_COLOR := Color(1.0, 0.92, 0.55, 1.0)
const MOON_COLOR := Color(0.85, 0.88, 0.95, 1.0)

# Legacy aliases used by tests.
const SKY_DAY := Color(0.55, 0.75, 0.92, 1.0)
const SKY_NIGHT := Color(0.10, 0.14, 0.32, 1.0)
const CANVAS_MODULATE_DAY := Color(1.0, 1.0, 1.0, 1.0)
const CANVAS_MODULATE_NIGHT := Color(0.58, 0.62, 0.78, 1.0)

const DECOR_FADE_SEC := 8.0
## Even 120s cycle — four 30s phases: night → dawn → day → dusk → night.
const PHASE_SEC := 30.0
const SUN_WINDOW_START := PHASE_SEC
const SUN_WINDOW_END := PHASE_SEC * 3.0
const NIGHT_WINDOW_START := SUN_WINDOW_END
const NIGHT_WINDOW_END := SUN_WINDOW_START
## Scales how far fairway stripe tints move from day keys toward sampled night keys.
const FAIRWAY_NIGHT_DARKEN_STRENGTH := 0.5
## Extra backdrop darkening at night — same timing as (1 - day_factor).
const BACKDROP_NIGHT_DARKEN := 0.42


class AtmosphereSnapshot:
	var sky: Color
	var hills: Color
	var fairway_base: Color
	var fairway_light: Color
	var fairway_dark: Color
	var canvas_modulate: Color
	var moon_sky_cutout: Color


## Sun/moon share one vertical orbit in the fairway YZ plane (rise on -Z horizon →
## zenith → set on +Z). Moon is 180° opposite. X stays 0 so discs stay on the
## player's forward view axis down the range.
const MOON_ORBIT_OFFSET := PI


static func _snap(
	sky: Color,
	hills: Color,
	f_base: Color,
	f_light: Color,
	f_dark: Color,
	canvas: Color
) -> AtmosphereSnapshot:
	var s := AtmosphereSnapshot.new()
	s.sky = sky
	s.hills = hills
	s.fairway_base = f_base
	s.fairway_light = f_light
	s.fairway_dark = f_dark
	s.canvas_modulate = canvas
	s.moon_sky_cutout = sky
	return s


static func _midnight() -> AtmosphereSnapshot:
	return _snap(
		Color(0.06, 0.08, 0.22),
		Color(0.34, 0.33, 0.42),
		Color(0.68, 0.72, 0.13),
		Color(0.75, 0.70, 0.11),
		Color(0.49, 0.65, 0.12),
		Color(0.48, 0.50, 0.66)
	)


static func _dawn() -> AtmosphereSnapshot:
	return _snap(
		Color(0.58, 0.66, 0.82),
		Color(0.86, 0.84, 0.95),
		Color(0.81, 0.89, 0.11),
		Color(0.95, 0.92, 0.11),
		Color(0.56, 0.74, 0.10),
		Color(0.88, 0.86, 0.92)
	)


static func _day() -> AtmosphereSnapshot:
	return _snap(
		Color(0.55, 0.75, 0.92),
		Color(1.0, 1.0, 1.0),
		Color(0.90, 0.99, 0.12),
		Color(1.07, 1.03, 0.12),
		Color(0.63, 0.84, 0.10),
		Color(1.0, 1.0, 1.0)
	)


static func _dusk() -> AtmosphereSnapshot:
	return _snap(
		Color(0.70, 0.56, 0.48),
		Color(1.03, 0.84, 0.84),
		Color(0.86, 0.92, 0.11),
		Color(0.99, 0.92, 0.10),
		Color(0.59, 0.78, 0.10),
		Color(0.94, 0.90, 0.84)
	)


static func _night() -> AtmosphereSnapshot:
	return _snap(
		Color(0.10, 0.14, 0.32),
		Color(0.51, 0.51, 0.58),
		Color(0.77, 0.82, 0.14),
		Color(0.87, 0.84, 0.13),
		Color(0.56, 0.74, 0.12),
		Color(0.58, 0.62, 0.78)
	)


## Timeline (seconds): midnight → dawn → day → dusk → night → midnight.
static func _keyframes() -> Array[Dictionary]:
	return [
		{"time": 0.0, "snap": _midnight()},
		{"time": PHASE_SEC, "snap": _dawn()},
		{"time": PHASE_SEC * 2.0, "snap": _day()},
		{"time": PHASE_SEC * 3.0, "snap": _dusk()},
		{"time": CYCLE_SEC, "snap": _midnight()},
	]


static func sample_at(cycle_time: float) -> AtmosphereSnapshot:
	var t := fposmod(cycle_time, CYCLE_SEC)
	var keys := _keyframes()
	for index in keys.size() - 1:
		var start: Dictionary = keys[index]
		var end: Dictionary = keys[index + 1]
		if t >= float(start["time"]) and t <= float(end["time"]):
			var span := float(end["time"]) - float(start["time"])
			var local := 0.0 if span <= 0.001 else (t - float(start["time"])) / span
			return lerp_snapshots(start["snap"], end["snap"], _smoothstep(local))
	return _midnight()


static func lerp_snapshots(a: AtmosphereSnapshot, b: AtmosphereSnapshot, weight: float) -> AtmosphereSnapshot:
	var w := clampf(weight, 0.0, 1.0)
	var s := AtmosphereSnapshot.new()
	s.sky = a.sky.lerp(b.sky, w)
	s.hills = a.hills.lerp(b.hills, w)
	s.fairway_base = a.fairway_base.lerp(b.fairway_base, w)
	s.fairway_light = a.fairway_light.lerp(b.fairway_light, w)
	s.fairway_dark = a.fairway_dark.lerp(b.fairway_dark, w)
	s.canvas_modulate = a.canvas_modulate.lerp(b.canvas_modulate, w)
	s.moon_sky_cutout = s.sky
	return s


static func _orbit_phase(cycle_time: float) -> float:
	return fposmod(cycle_time, CYCLE_SEC) / CYCLE_SEC


## Midnight = nadir, dawn/dusk = horizon, noon = zenith.
static func _sun_orbit_angle(cycle_time: float) -> float:
	return _orbit_phase(cycle_time) * TAU - PI / 2.0


static func _body_orbit_angle(cycle_time: float, is_moon: bool) -> float:
	var angle := _sun_orbit_angle(cycle_time)
	if is_moon:
		angle += MOON_ORBIT_OFFSET
	return angle


static func _is_daytime(cycle_time: float) -> bool:
	var t := fposmod(cycle_time, CYCLE_SEC)
	return t >= SUN_WINDOW_START and t < SUN_WINDOW_END


static func _is_above_horizon(cycle_time: float, is_moon: bool) -> bool:
	return sin(_body_orbit_angle(cycle_time, is_moon)) > 0.0


static func _sun_orbit_progress(cycle_time: float) -> float:
	var t := fposmod(cycle_time, CYCLE_SEC)
	if t < SUN_WINDOW_START or t >= SUN_WINDOW_END:
		return -1.0
	return (t - SUN_WINDOW_START) / (SUN_WINDOW_END - SUN_WINDOW_START)


static func celestial_view_direction(
	cycle_time: float,
	is_moon: bool,
	_viewer_position: Vector3
) -> Vector3:
	var angle := _body_orbit_angle(cycle_time, is_moon)
	# YZ-plane arc: dawn at far fairway horizon (-Z), noon at zenith, dusk behind.
	var y := sin(angle)
	var z := -cos(angle)
	return Vector3(0.0, y, z).normalized()


static func celestial_alpha(cycle_time: float, is_moon: bool) -> float:
	if not _is_above_horizon(cycle_time, is_moon):
		return 0.0
	if is_moon:
		return 1.0 if not _is_daytime(cycle_time) else 0.0
	return 1.0 if _is_daytime(cycle_time) else 0.0


static func celestial_elevation(cycle_time: float, is_moon: bool) -> float:
	return maxf(sin(_body_orbit_angle(cycle_time, is_moon)), 0.0)


static func celestial_angle(cycle_time: float, is_moon: bool) -> float:
	return _body_orbit_angle(cycle_time, is_moon)


static func celestial_direction_3d(cycle_time: float, is_moon: bool) -> Vector3:
	return celestial_view_direction(cycle_time, is_moon, Vector3.ZERO)


static func celestial_position(cycle_time: float, is_moon: bool) -> Vector2:
	var direction := celestial_view_direction(cycle_time, is_moon, Vector3.ZERO)
	return Vector2(direction.x, direction.y)


static func day_light_factor(cycle_time: float) -> float:
	var progress := _sun_orbit_progress(cycle_time)
	if progress < 0.0:
		return 0.0
	return sin(progress * PI)


static func celestial_view_offset(
	cycle_time: float,
	is_moon: bool,
	camera: Camera3D
) -> Vector2:
	if camera == null:
		return Vector2.ZERO
	var direction := celestial_view_direction(cycle_time, is_moon, camera.global_position)
	var right := camera.global_transform.basis.x.normalized()
	var cam_up := camera.global_transform.basis.y.normalized()
	return Vector2(direction.dot(right), direction.dot(cam_up))


static func phase_name_at(cycle_time: float) -> String:
	var t := fposmod(cycle_time, CYCLE_SEC)
	if t < PHASE_SEC:
		return "night"
	if t < PHASE_SEC * 2.0:
		return "dawn"
	if t < PHASE_SEC * 3.0:
		return "day"
	return "night"


static func star_visibility(cycle_time: float) -> float:
	var t := fposmod(cycle_time, CYCLE_SEC)
	var evening := _window_visibility(
		t,
		NIGHT_WINDOW_START - DECOR_FADE_SEC,
		CYCLE_SEC,
		NIGHT_WINDOW_START,
		CYCLE_SEC
	)
	var morning := _window_visibility(
		t,
		0.0,
		NIGHT_WINDOW_END + DECOR_FADE_SEC,
		0.0,
		NIGHT_WINDOW_END
	)
	return maxf(evening, morning)


static func _window_visibility(
	time: float,
	fade_in_start: float,
	fade_out_end: float,
	full_start: float,
	full_end: float
) -> float:
	if time < fade_in_start or time > fade_out_end:
		return 0.0
	if time >= full_start and time <= full_end:
		return 1.0
	if time < full_start:
		return _smoothstep((time - fade_in_start) / maxf(full_start - fade_in_start, 0.001))
	return 1.0 - _smoothstep((time - full_end) / maxf(fade_out_end - full_end, 0.001))


static func _smoothstep(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func lerp_color(day: Color, night: Color, night_blend: float) -> Color:
	return day.lerp(night, clampf(night_blend, 0.0, 1.0))


static func _phase_tint(day_color: Color, snap_color: Color, day_factor: float) -> Color:
	var night_blend := (1.0 - day_factor) * FAIRWAY_NIGHT_DARKEN_STRENGTH
	return day_color.lerp(snap_color, night_blend)


## Fairway mower-stripe tints with night darkening scaled by FAIRWAY_NIGHT_DARKEN_STRENGTH.
static func fairway_stripe_colors(snap: AtmosphereSnapshot, day_factor: float) -> Array:
	var day := _day()
	return [
		_phase_tint(day.fairway_light, snap.fairway_light, day_factor),
		_phase_tint(day.fairway_dark, snap.fairway_dark, day_factor),
	]


## Painted backdrop tint — one color for the whole image, darkens with (1 - day_factor).
static func backdrop_tint(snap: AtmosphereSnapshot, day_factor: float) -> Color:
	var day := _day()
	return _phase_tint(day.hills, snap.hills, day_factor).darkened(backdrop_night_darken(day_factor))


static func backdrop_night_darken(day_factor: float) -> float:
	return (1.0 - clampf(day_factor, 0.0, 1.0)) * BACKDROP_NIGHT_DARKEN
