class_name BallFlightRenderer
extends RefCounted
## Hit-driven ball flight samples for parallax 2.5D range view.


class FlightConfig:
	var tee_x: float = 248.0
	var tee_y: float = 206.0
	var horizon_ground_y: float = 113.0
	var mat_back_y: float = 195.0
	var vanishing_point: Vector2 = Vector2(240.0, 100.0)
	var near_scale: float = 1.0
	var far_scale: float = 0.30
	var arc_min_px: float = 12.0
	var arc_max_px: float = 40.0
	var landing_scatter_x: float = 28.0
	var range_x_min: float = 24.0
	var range_x_max: float = 456.0
	var flight_time_min_sec: float = 0.65
	var flight_time_range_sec: float = 0.95
	var base_ball_scale: Vector2 = Vector2.ONE
	var flight_depth_exponent: float = 0.34
	var flight_depth_stretch: float = 1.20
	var min_landing_y: float = 176.0
	var vanish_fade_start: float = 0.78
	var vanish_extra_time_sec: float = 0.25


class FlightPath:
	var depth_t: float = 0.0
	var arc_height: float = 0.0
	var flight_time: float = 0.65
	var landing_ground: Vector2 = Vector2.ZERO
	var yards: float = 0.0
	var vanishes_into_distance: bool = false


static func build_path(
	yards: float,
	timing_tier: int,
	stats: PlayerStats,
	config: FlightConfig
) -> FlightPath:
	var path := FlightPath.new()
	path.yards = yards
	path.vanishes_into_distance = yards > Balance.VISUAL_MAX_YARDS
	path.depth_t = flight_depth_t(yards, stats, config)
	path.arc_height = arc_height_for_hit(yards, timing_tier, stats, config)
	path.flight_time = config.flight_time_min_sec + path.depth_t * config.flight_time_range_sec
	if path.vanishes_into_distance:
		path.flight_time += config.vanish_extra_time_sec

	var base_y := PerspectiveGround.ground_y_at_depth(
		path.depth_t, config.tee_y, config.horizon_ground_y
	)
	var base_x := PerspectiveGround.centerline_x_at_y(
		base_y, config.vanishing_point, config.tee_x, config.tee_y
	)
	var scatter_x := randf_range(-config.landing_scatter_x, config.landing_scatter_x) \
		* lerpf(0.65, 1.0, path.depth_t)
	var landing := Vector2(base_x + scatter_x, base_y)
	landing.x = clampf(landing.x, config.range_x_min, config.range_x_max)
	landing.y = clampf(
		landing.y,
		config.horizon_ground_y,
		config.tee_y + 4.0
	)
	path.landing_ground = landing
	return path


## Maps gameplay yards to screen depth for flight rendering only.
## Economy.visual_depth_t compresses near shots onto the mat; this expands them up the fairway.
static func flight_depth_t(yards: float, stats: PlayerStats, config: FlightConfig) -> float:
	if yards <= 0.0:
		return 0.0
	var raw := Economy.visual_depth_t(yards, stats)
	var remapped := pow(raw, config.flight_depth_exponent) * config.flight_depth_stretch
	var min_t := PerspectiveGround.depth_at_ground_y(
		config.min_landing_y, config.tee_y, config.horizon_ground_y
	)
	return clampf(maxf(remapped, min_t), 0.0, 1.0)


static func arc_height_for_hit(
	yards: float,
	timing_tier: int,
	stats: PlayerStats,
	config: FlightConfig
) -> float:
	var depth_t := flight_depth_t(yards, stats, config)
	var yard_frac := clampf(yards / maxf(stats.max_yards, 1.0), 0.0, 1.0)
	var tier_norm := 1.0 - clampf(
		float(timing_tier) / float(Balance.TimingTier.MISS), 0.0, 1.0
	)
	var hit_strength := lerpf(yard_frac * 0.4 + depth_t * 0.6, depth_t, tier_norm)
	var base_arc := lerpf(config.arc_min_px, config.arc_max_px, hit_strength)
	return base_arc * lerpf(0.88, 1.0, tier_norm)


static func sample(
	progress: float,
	path: FlightPath,
	config: FlightConfig
) -> Dictionary:
	var start := Vector2(config.tee_x, config.tee_y)
	var ground := start.lerp(path.landing_ground, clampf(progress, 0.0, 1.0))
	var ground_t := PerspectiveGround.depth_at_ground_y(
		ground.y, config.tee_y, config.horizon_ground_y
	)
	var scale_factor := PerspectiveGround.scale_at_depth(
		ground_t, config.near_scale, config.far_scale
	)
	var lift := 4.0 * path.arc_height * progress * (1.0 - progress)
	var visual_pos := Vector2(ground.x, ground.y - lift)
	var ball_alpha := 1.0
	if path.vanishes_into_distance and progress >= config.vanish_fade_start:
		var fade_t := (progress - config.vanish_fade_start) \
			/ maxf(1.0 - config.vanish_fade_start, 0.001)
		fade_t = clampf(fade_t, 0.0, 1.0)
		ball_alpha = 1.0 - fade_t
		scale_factor *= lerpf(1.0, 0.12, fade_t)
	return {
		"ground_pos": ground,
		"visual_pos": visual_pos,
		"scale": config.base_ball_scale * scale_factor,
		"scale_factor": scale_factor,
		"arc_height": path.arc_height,
		"ground_t": ground_t,
		"ball_alpha": ball_alpha,
		"vanishes": path.vanishes_into_distance,
	}
