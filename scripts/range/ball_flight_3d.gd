class_name BallFlight3D
extends RefCounted
## Real projectile-motion ball flight for the 3D range. Replaces the old
## fake-perspective BallFlightRenderer/PerspectiveGround stack — depth,
## scale, and vanishing-point convergence now come free from Camera3D
## projection, so this class only has to solve real physics.
##
## World convention: 1 world unit = 1 yard. Ball starts at `origin`
## (tee position) and flies toward -Z, with side scatter on X and
## arc height on Y.


class FlightPath:
	var origin: Vector3 = Vector3.ZERO
	var velocity0: Vector3 = Vector3.ZERO
	var gravity: float = Balance.FLIGHT_GRAVITY
	var flight_time: float = 0.6
	var landing: Vector3 = Vector3.ZERO
	var yards: float = 0.0
	var visual_yards: float = 0.0
	var apex_height: float = 0.0


## Visual flight distance always equals gameplay yards exactly — no floor or
## cap. Every tier's rendered carry is proportional to its actual yardage.
static func resolve_visual_yards(yards: float, _timing_tier: int) -> float:
	return maxf(yards, 0.0)


## Apex ratio comes from contact flavor, with a small bonus at the top of the
## ladder (Great/Perfect) so the cleanest hits arc a little higher than a
## plain Good even when they share the PURE flavor.
static func apex_ratio_for(contact_flavor: int, timing_tier: int = -1) -> float:
	var ratio: float = Balance.FLIGHT_APEX_RATIO.get(contact_flavor, Balance.FLIGHT_APEX_RATIO[0])
	if timing_tier == Balance.TimingTier.PERFECT:
		ratio *= 1.15
	elif timing_tier == Balance.TimingTier.GREAT:
		ratio *= 1.08
	return ratio


static func build_path(
	yards: float,
	timing_tier: int,
	_stats: PlayerStats,
	contact_flavor: int = Balance.ContactFlavor.PURE,
	origin: Vector3 = Vector3.ZERO,
	rng: RandomNumberGenerator = null
) -> FlightPath:
	var path := FlightPath.new()
	path.origin = origin
	path.yards = yards
	path.visual_yards = resolve_visual_yards(yards, timing_tier)

	var apex_ratio := apex_ratio_for(contact_flavor, timing_tier)
	path.apex_height = maxf(path.visual_yards * apex_ratio, Balance.FLIGHT_MIN_APEX_YARDS)

	var g := Balance.FLIGHT_GRAVITY
	var v_y0 := sqrt(2.0 * g * path.apex_height)
	var raw_time := (2.0 * v_y0) / g
	path.flight_time = clampf(
		raw_time, Balance.FLIGHT_TIME_MIN_SEC, Balance.FLIGHT_TIME_MAX_SEC
	)
	# Re-derive v_y0 from the clamped time so the ball still returns to y=0
	# exactly at flight_time even when the raw physics time got clamped.
	v_y0 = 0.5 * g * path.flight_time

	var depth_frac := clampf(path.visual_yards / maxf(Balance.VISUAL_MAX_YARDS, 1.0), 0.0, 1.0)
	var scatter_range := Balance.LANDING_SCATTER_YARDS * lerpf(0.5, 1.0, depth_frac)
	var side_yards := 0.0
	if rng:
		side_yards = rng.randf_range(-scatter_range, scatter_range)
	else:
		side_yards = randf_range(-scatter_range, scatter_range)

	var v_z0 := path.visual_yards / path.flight_time
	var v_x0 := side_yards / path.flight_time
	path.velocity0 = Vector3(v_x0, v_y0, -v_z0)
	path.gravity = g
	path.landing = origin + Vector3(side_yards, 0.0, -path.visual_yards)
	return path


## Sample world position at elapsed time `t` (seconds) into the flight.
static func sample_position(t: float, path: FlightPath) -> Vector3:
	var tt := clampf(t, 0.0, path.flight_time)
	return path.origin + path.velocity0 * tt + Vector3(0.0, -0.5 * path.gravity * tt * tt, 0.0)


## 0..1 normalized progress helper — mirrors the old tween_method(progress) API.
static func sample(progress: float, path: FlightPath) -> Vector3:
	return sample_position(clampf(progress, 0.0, 1.0) * path.flight_time, path)
