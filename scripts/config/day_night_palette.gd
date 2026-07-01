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
const CLOUD_WINDOW_START := 24.0
const CLOUD_WINDOW_END := 91.0
const NIGHT_WINDOW_START := 104.0
const NIGHT_WINDOW_END := 13.0


class AtmosphereSnapshot:
	var sky: Color
	var hills: Color
	var fairway_base: Color
	var fairway_light: Color
	var fairway_dark: Color
	var canvas_modulate: Color
	var moon_sky_cutout: Color


const CELESTIAL_ARC_CENTER := Vector2(240.0, 98.0)
const CELESTIAL_ARC_RADIUS_X := 210.0
const CELESTIAL_ARC_RADIUS_Y := 74.0
const CELESTIAL_HORIZON_FADE := 0.08
const MOON_ORBIT_OFFSET := 0.25


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
		Color(0.12, 0.18, 0.16),
		Color(0.30, 0.42, 0.34),
		Color(0.38, 0.52, 0.42),
		Color(0.28, 0.40, 0.32),
		Color(0.48, 0.50, 0.66)
	)


static func _dawn() -> AtmosphereSnapshot:
	return _snap(
		Color(0.58, 0.66, 0.82),
		Color(0.30, 0.46, 0.36),
		Color(0.36, 0.52, 0.30),
		Color(0.48, 0.68, 0.40),
		Color(0.32, 0.46, 0.27),
		Color(0.88, 0.86, 0.92)
	)


static func _day() -> AtmosphereSnapshot:
	return _snap(
		Color(0.55, 0.75, 0.92),
		Color(0.35, 0.55, 0.38),
		Color(0.40, 0.58, 0.32),
		Color(0.54, 0.76, 0.44),
		Color(0.36, 0.52, 0.28),
		Color(1.0, 1.0, 1.0)
	)


static func _dusk() -> AtmosphereSnapshot:
	return _snap(
		Color(0.70, 0.56, 0.48),
		Color(0.36, 0.46, 0.32),
		Color(0.38, 0.54, 0.30),
		Color(0.50, 0.68, 0.38),
		Color(0.34, 0.48, 0.27),
		Color(0.94, 0.90, 0.84)
	)


static func _night() -> AtmosphereSnapshot:
	return _snap(
		Color(0.10, 0.14, 0.32),
		Color(0.18, 0.28, 0.22),
		Color(0.34, 0.48, 0.36),
		Color(0.44, 0.62, 0.48),
		Color(0.32, 0.46, 0.36),
		Color(0.58, 0.62, 0.78)
	)


## Timeline (seconds): midnight → dawn → day → dusk → night → midnight.
static func _keyframes() -> Array[Dictionary]:
	return [
		{"time": 0.0, "snap": _midnight()},
		{"time": 13.0, "snap": _dawn()},
		{"time": 24.0, "snap": _day()},
		{"time": 77.0, "snap": _day()},
		{"time": 91.0, "snap": _dusk()},
		{"time": 104.0, "snap": _night()},
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


## Orbit progress 0→1; moon follows the same path offset by a quarter cycle.
static func _orbit_progress(cycle_time: float, is_moon: bool) -> float:
	var t := fposmod(cycle_time, CYCLE_SEC)
	if is_moon:
		t = fposmod(t + CYCLE_SEC * MOON_ORBIT_OFFSET, CYCLE_SEC)
	return t / CYCLE_SEC


static func celestial_angle(cycle_time: float, is_moon: bool) -> float:
	var orbit := _orbit_progress(cycle_time, is_moon)
	if orbit <= 0.5:
		# Visible upper arc: east horizon (PI) → zenith → west horizon (0).
		return lerpf(PI, 0.0, orbit * 2.0)
	# Lower arc: below hills, not rendered.
	return lerpf(0.0, -PI, (orbit - 0.5) * 2.0)


static func celestial_position(cycle_time: float, is_moon: bool) -> Vector2:
	var angle := celestial_angle(cycle_time, is_moon)
	return Vector2(
		CELESTIAL_ARC_CENTER.x + cos(angle) * CELESTIAL_ARC_RADIUS_X,
		CELESTIAL_ARC_CENTER.y - sin(angle) * CELESTIAL_ARC_RADIUS_Y
	)


static func celestial_alpha(cycle_time: float, is_moon: bool) -> float:
	if _orbit_progress(cycle_time, is_moon) > 0.5:
		return 0.0
	var elevation := sin(celestial_angle(cycle_time, is_moon))
	if elevation <= CELESTIAL_HORIZON_FADE:
		return 0.0
	return clampf((elevation - CELESTIAL_HORIZON_FADE) / 0.42, 0.0, 1.0)


static func phase_name_at(cycle_time: float) -> String:
	var t := fposmod(cycle_time, CYCLE_SEC)
	if t < 13.0:
		return "midnight_dawn"
	if t < 24.0:
		return "dawn"
	if t < 77.0:
		return "day"
	if t < 91.0:
		return "dusk"
	if t < 104.0:
		return "night"
	return "midnight"


static func cloud_visibility(cycle_time: float) -> float:
	var t := fposmod(cycle_time, CYCLE_SEC)
	return _window_visibility(
		t,
		CLOUD_WINDOW_START - DECOR_FADE_SEC,
		CLOUD_WINDOW_END + DECOR_FADE_SEC,
		CLOUD_WINDOW_START,
		CLOUD_WINDOW_END
	)


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
