class_name BallFlightRenderer
extends RefCounted
## Hit-driven ball flight samples for parallax 2.5D range view.


class FlightConfig:
	var tee_x: float = 248.0
	var tee_y: float = 206.0
	var far_ground_y: float = 105.0
	var ground_bottom_y: float = 270.0
	var mat_back_y: float = 195.0
	var vanishing_point: Vector2 = Vector2(240.0, 100.0)
	var arc_min_px: float = 12.0
	var arc_max_px: float = 40.0
	var landing_scatter_x: float = 28.0
	var range_x_min: float = 24.0
	var range_x_max: float = 456.0
	var flight_time_min_sec: float = 0.65
	var flight_time_range_sec: float = 0.95
	var base_ball_scale: Vector2 = Vector2.ONE
	var flight_depth_exponent: float = 0.34
	var flight_depth_stretch: float = 1.02
	var yard_depth_scale: float = 180.0
	var min_landing_y: float = 176.0
	var ball_texture_px: float = 8.0
	var min_visible_px: float = 1.0
	var fade_scale_threshold: float = 0.08


class FlightPath:
	var persp_p: float = 0.0
	var arc_height: float = 0.0
	var flight_time: float = 0.65
	var landing_ground: Vector2 = Vector2.ZERO
	var yards: float = 0.0


static func build_path(
	yards: float,
	timing_tier: int,
	stats: PlayerStats,
	config: FlightConfig
) -> FlightPath:
	var path := FlightPath.new()
	path.yards = yards
	path.persp_p = yards_to_p(yards, config)
	path.arc_height = arc_height_for_hit(yards, timing_tier, stats, config)
	var time_depth := clampf(path.persp_p, 0.0, 2.0)
	path.flight_time = config.flight_time_min_sec + time_depth * config.flight_time_range_sec

	var base_y := PerspectiveGround.y_at_p(
		path.persp_p, config.tee_y, config.far_ground_y, config.vanishing_point
	)
	var base_x := PerspectiveGround.centerline_x_at_y(
		base_y, config.vanishing_point, config.tee_x, config.ground_bottom_y
	)
	var scatter_depth := clampf(path.persp_p, 0.0, 1.0)
	var scatter_x := randf_range(-config.landing_scatter_x, config.landing_scatter_x) \
		* lerpf(0.65, 1.0, scatter_depth)
	var landing := Vector2(base_x + scatter_x, base_y)
	landing.x = clampf(landing.x, config.range_x_min, config.range_x_max)
	landing.y = clampf(
		landing.y,
		config.vanishing_point.y + 0.5,
		config.tee_y + 4.0
	)
	path.landing_ground = landing
	return path


static func yards_to_p(yards: float, config: FlightConfig) -> float:
	if yards <= 0.0:
		return 0.0
	var raw := 1.0 - exp(-yards / config.yard_depth_scale)
	var remapped := pow(raw, config.flight_depth_exponent) * config.flight_depth_stretch
	var min_p := PerspectiveGround.p_at_y_segment(
		config.min_landing_y, config.tee_y, config.far_ground_y
	)
	return maxf(remapped, min_p)


static func arc_height_for_hit(
	yards: float,
	timing_tier: int,
	stats: PlayerStats,
	config: FlightConfig
) -> float:
	var persp_p := yards_to_p(yards, config)
	var yard_frac := clampf(yards / maxf(stats.max_yards, 1.0), 0.0, 1.0)
	var tier_norm := 1.0 - clampf(
		float(timing_tier) / float(Balance.TimingTier.MISS), 0.0, 1.0
	)
	var hit_strength := lerpf(yard_frac * 0.4 + persp_p * 0.6, persp_p, tier_norm)
	var base_arc := lerpf(config.arc_min_px, config.arc_max_px, clampf(hit_strength, 0.0, 1.0))
	return base_arc * lerpf(0.88, 1.0, tier_norm)


static func is_visible_scale(scale_factor: float, config: FlightConfig) -> bool:
	var px := scale_factor * config.base_ball_scale.x * config.ball_texture_px
	return px >= config.min_visible_px


static func sample(
	progress: float,
	path: FlightPath,
	config: FlightConfig
) -> Dictionary:
	var start := Vector2(config.tee_x, config.tee_y)
	var ground := start.lerp(path.landing_ground, clampf(progress, 0.0, 1.0))
	var scale_factor := PerspectiveGround.scale_at_y(
		ground.y, config.vanishing_point, config.tee_y
	)
	var lift := 4.0 * path.arc_height * progress * (1.0 - progress)
	var visual_pos := Vector2(ground.x, ground.y - lift)
	var visible := is_visible_scale(scale_factor, config)
	var ball_alpha := 1.0 if visible else 0.0
	if visible and scale_factor < config.fade_scale_threshold and progress >= 0.9:
		var fade_t := (progress - 0.9) / 0.1
		ball_alpha = 1.0 - clampf(fade_t, 0.0, 1.0)
	return {
		"ground_pos": ground,
		"visual_pos": visual_pos,
		"scale": config.base_ball_scale * scale_factor,
		"scale_factor": scale_factor,
		"arc_height": path.arc_height,
		"persp_p": path.persp_p,
		"ball_alpha": ball_alpha,
		"visible": visible and ball_alpha > 0.01,
	}

