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


class BounceSegment:
	var start: Vector3 = Vector3.ZERO
	var velocity0: Vector3 = Vector3.ZERO
	var duration: float = 0.0
	var apex_height: float = 0.0
	var landing: Vector3 = Vector3.ZERO


class FlightPath:
	var origin: Vector3 = Vector3.ZERO
	var velocity0: Vector3 = Vector3.ZERO
	var gravity: float = Balance.FLIGHT_GRAVITY
	var flight_time: float = 0.6
	var landing: Vector3 = Vector3.ZERO
	var yards: float = 0.0
	var visual_yards: float = 0.0
	var apex_height: float = 0.0
	## Post-carry bounce arcs (may be empty for tiny dribbles).
	var bounces: Array[BounceSegment] = []
	## Carry flight_time plus all bounce durations.
	var total_time: float = 0.6
	## Where the ball finally comes to rest (== landing when no bounces).
	var rest_position: Vector3 = Vector3.ZERO


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
	_build_bounces(path)
	return path


## After carry touchdown the ball skips forward through a few decaying
## mini-arcs (same projectile math, smaller apex each hop) before resting.
## Bounce direction continues the carry's horizontal velocity, so side
## scatter carries through the runout naturally.
static func _build_bounces(path: FlightPath) -> void:
	path.bounces = []
	path.total_time = path.flight_time
	path.rest_position = path.landing

	var horizontal := Vector3(path.velocity0.x, 0.0, path.velocity0.z)
	if horizontal.length_squared() < 0.000001:
		return
	var direction := horizontal.normalized()

	var apex := minf(
		path.apex_height * Balance.FLIGHT_BOUNCE_APEX_RATIO,
		Balance.FLIGHT_BOUNCE_MAX_APEX_YARDS
	)
	var forward := minf(
		path.visual_yards * Balance.FLIGHT_BOUNCE_DISTANCE_RATIO,
		Balance.FLIGHT_BOUNCE_MAX_FORWARD_YARDS
	)
	var start := path.landing
	var ground_y := path.landing.y

	for i in Balance.FLIGHT_BOUNCE_MAX_COUNT:
		if apex < Balance.FLIGHT_BOUNCE_MIN_APEX_YARDS or forward <= 0.001:
			break
		# Never bounce past the far edge of the fairway grass.
		var remaining_depth := Balance.FLIGHT_MAX_REST_DEPTH_YARDS - (-start.z)
		if remaining_depth <= 0.0:
			break
		var travel := forward
		if direction.z < -0.000001:
			travel = minf(travel, remaining_depth / -direction.z)

		var segment := BounceSegment.new()
		segment.start = start
		segment.apex_height = apex
		var v_y := sqrt(2.0 * path.gravity * apex)
		segment.duration = (2.0 * v_y) / path.gravity
		var h_speed := travel / segment.duration
		segment.velocity0 = Vector3(
			direction.x * h_speed, v_y, direction.z * h_speed
		)
		# Keep the carry's ground height (tee Y), not world y=0 — litter sprites
		# are centered billboards, so dropping to 0 buries them in the fairway.
		segment.landing = start + direction * travel
		segment.landing.y = ground_y
		path.bounces.append(segment)

		path.total_time += segment.duration
		start = segment.landing
		apex *= Balance.FLIGHT_BOUNCE_APEX_DECAY
		forward *= Balance.FLIGHT_BOUNCE_DISTANCE_DECAY

	path.rest_position = start
	path.rest_position.y = ground_y


## Sample world position at elapsed time `t` (seconds) into the flight.
static func sample_position(t: float, path: FlightPath) -> Vector3:
	var tt := clampf(t, 0.0, path.flight_time)
	return path.origin + path.velocity0 * tt + Vector3(0.0, -0.5 * path.gravity * tt * tt, 0.0)


## 0..1 normalized progress helper — mirrors the old tween_method(progress) API.
static func sample(progress: float, path: FlightPath) -> Vector3:
	return sample_position(clampf(progress, 0.0, 1.0) * path.flight_time, path)


## Sample world position at elapsed time `t` across carry AND bounces.
## Past total_time the ball holds its rest position.
static func sample_total_position(t: float, path: FlightPath) -> Vector3:
	if t <= path.flight_time:
		return sample_position(t, path)
	var remaining := t - path.flight_time
	for segment in path.bounces:
		if remaining <= segment.duration:
			return (
				segment.start
				+ segment.velocity0 * remaining
				+ Vector3(0.0, -0.5 * path.gravity * remaining * remaining, 0.0)
			)
		remaining -= segment.duration
	return path.rest_position


## 0..1 normalized progress over the full carry + bounce timeline.
static func sample_total(progress: float, path: FlightPath) -> Vector3:
	return sample_total_position(clampf(progress, 0.0, 1.0) * path.total_time, path)
