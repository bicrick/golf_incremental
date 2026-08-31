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
## Scales how far day keys blend toward night keys (fairway + backdrop).
const FAIRWAY_NIGHT_DARKEN_STRENGTH := 0.55
## Cool moonlight multiply applied to world tints at night (fairway, backdrop, etc.).
const MOONLIGHT_COLOR := Color(0.72, 0.78, 0.92)
## How hard moonlight mixes in at full night (0–1).
const MOONLIGHT_BLEND := 0.48
## Mild luminance drop under moonlight — keeps greens readable.
const MOONLIGHT_DARKEN := 0.24
## Legacy alias used by backdrop helpers / tests.
const BACKDROP_NIGHT_DARKEN := MOONLIGHT_DARKEN


class AtmosphereSnapshot:
	var sky: Color
	var hills: Color
	var fairway_base: Color
	var fairway_light: Color
	var fairway_dark: Color
	var canvas_modulate: Color
	var moon_sky_cutout: Color


## Sun and moon bob up/down on the same fairway bearing (-Z): rise at the far
## horizon, peak at MAX_CELESTIAL_ELEVATION_DEG, then fall back in place.
## They take turns (day vs night); they do not traverse left/right across the sky.
const MOON_ORBIT_OFFSET := PI
const MAX_CELESTIAL_ELEVATION_DEG := 30.0
const BELOW_HORIZON_ELEVATION_DEG := -12.0
## Sprites stay fully visible until they sink to this elevation (mountain ridge),
## then fade out over MOUNTAIN_SPRITE_FADE_DEG — lights still use the smooth curve.
const MOUNTAIN_OCCLUSION_ELEVATION_DEG := 5.0
const MOUNTAIN_SPRITE_FADE_DEG := 3.0


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
		Color(0.40, 0.42, 0.52),
		Color(0.18, 0.36, 0.12),
		Color(0.22, 0.42, 0.14),
		Color(0.12, 0.28, 0.10),
		Color(0.55, 0.60, 0.78)
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
	# Fairway stripes: light #6db505, dark #3f9d02 (matched to backdrop trees).
	# Iso TileMap terrain PNGs use a separate authored palette — do not change this
	# for iso-only color work.
	return _snap(
		Color(0.55, 0.75, 0.92),
		Color(1.0, 1.0, 1.0),
		Color(0.34, 0.66, 0.01),
		Color(0.427, 0.710, 0.020),
		Color(0.247, 0.616, 0.008),
		Color(1.0, 1.0, 1.0)
	)


static func _dusk() -> AtmosphereSnapshot:
	return _snap(
		Color(0.70, 0.56, 0.48),
		Color(0.95, 0.82, 0.78),
		Color(0.32, 0.52, 0.10),
		Color(0.36, 0.58, 0.12),
		Color(0.22, 0.42, 0.08),
		Color(0.94, 0.90, 0.84)
	)


static func _night() -> AtmosphereSnapshot:
	return _snap(
		Color(0.10, 0.14, 0.32),
		Color(0.45, 0.48, 0.58),
		Color(0.20, 0.38, 0.12),
		Color(0.24, 0.44, 0.14),
		Color(0.14, 0.30, 0.10),
		Color(0.58, 0.64, 0.82)
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
	return _body_orbit_progress(cycle_time, is_moon) >= 0.0


static func _sun_orbit_progress(cycle_time: float) -> float:
	var t := fposmod(cycle_time, CYCLE_SEC)
	if t < SUN_WINDOW_START or t >= SUN_WINDOW_END:
		return -1.0
	return (t - SUN_WINDOW_START) / (SUN_WINDOW_END - SUN_WINDOW_START)


## Night wraps across midnight: t∈[90,120) then [0,30). Returns -1 when sun is up.
static func _night_orbit_progress(cycle_time: float) -> float:
	var t := fposmod(cycle_time, CYCLE_SEC)
	var night_len := PHASE_SEC * 2.0
	if t >= NIGHT_WINDOW_START:
		return (t - NIGHT_WINDOW_START) / night_len
	if t < SUN_WINDOW_START:
		return (PHASE_SEC + t) / night_len
	return -1.0


static func _body_orbit_progress(cycle_time: float, is_moon: bool) -> float:
	if is_moon:
		return _night_orbit_progress(cycle_time)
	return _sun_orbit_progress(cycle_time)


static func celestial_view_direction(
	cycle_time: float,
	is_moon: bool,
	_viewer_position: Vector3
) -> Vector3:
	var progress := _body_orbit_progress(cycle_time, is_moon)
	var elev_deg := BELOW_HORIZON_ELEVATION_DEG
	if progress >= 0.0:
		elev_deg = sin(progress * PI) * MAX_CELESTIAL_ELEVATION_DEG
	var elev := deg_to_rad(elev_deg)
	# Always on the fairway -Z bearing; only elevation changes.
	return Vector3(0.0, sin(elev), -cos(elev)).normalized()


static func celestial_alpha(cycle_time: float, is_moon: bool) -> float:
	## Smooth 0→1→0 with elevation for light energy handoff.
	if not _body_is_active(cycle_time, is_moon):
		return 0.0
	return celestial_elevation(cycle_time, is_moon)


static func celestial_sprite_alpha(cycle_time: float, is_moon: bool) -> float:
	## Stay opaque until the body reaches the mountain ridge, then fade behind it.
	if not _body_is_active(cycle_time, is_moon):
		return 0.0
	var elev_deg := celestial_elevation(cycle_time, is_moon) * MAX_CELESTIAL_ELEVATION_DEG
	var fade_start := MOUNTAIN_OCCLUSION_ELEVATION_DEG - MOUNTAIN_SPRITE_FADE_DEG
	return _smoothstep((elev_deg - fade_start) / maxf(MOUNTAIN_SPRITE_FADE_DEG, 0.001))


static func _body_is_active(cycle_time: float, is_moon: bool) -> bool:
	if _body_orbit_progress(cycle_time, is_moon) < 0.0:
		return false
	if is_moon:
		return not _is_daytime(cycle_time)
	return _is_daytime(cycle_time)


static func celestial_elevation(cycle_time: float, is_moon: bool) -> float:
	var progress := _body_orbit_progress(cycle_time, is_moon)
	if progress < 0.0:
		return 0.0
	return sin(progress * PI)


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


## Subtle cool moonlight over a color — shared by fairway, backdrop, and related tints.
static func apply_moonlight(color: Color, day_factor: float) -> Color:
	var night := 1.0 - clampf(day_factor, 0.0, 1.0)
	if night <= 0.001:
		return color
	var moonlit := color * MOONLIGHT_COLOR
	var cast := color.lerp(moonlit, night * MOONLIGHT_BLEND)
	return cast.darkened(night * MOONLIGHT_DARKEN)


## Fairway mower-stripe tints with shared moonlight cast.
static func fairway_stripe_colors(snap: AtmosphereSnapshot, day_factor: float) -> Array:
	var day := _day()
	return [
		apply_moonlight(_phase_tint(day.fairway_light, snap.fairway_light, day_factor), day_factor),
		apply_moonlight(_phase_tint(day.fairway_dark, snap.fairway_dark, day_factor), day_factor),
	]


## Painted backdrop tint — same moonlight cast as the fairway.
static func backdrop_tint(snap: AtmosphereSnapshot, day_factor: float) -> Color:
	var day := _day()
	return apply_moonlight(_phase_tint(day.hills, snap.hills, day_factor), day_factor)


## Harvest mist bank — warm pearl by day, cool blue-grey at night (no purple).
static func harvest_fog_color(day_factor: float) -> Color:
	const DAY_FOG := Color(0.78, 0.82, 0.74, 1.0)
	const NIGHT_FOG := Color(0.42, 0.48, 0.52, 1.0)
	return DAY_FOG.lerp(NIGHT_FOG, 1.0 - clampf(day_factor, 0.0, 1.0))


static func backdrop_night_darken(day_factor: float) -> float:
	return (1.0 - clampf(day_factor, 0.0, 1.0)) * BACKDROP_NIGHT_DARKEN
