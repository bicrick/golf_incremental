class_name PerspectiveGround
extends RefCounted
## Shared fake-3D ground plane math aligned with fairway stripe perspective.


static func y_at_p(
	p: float,
	tee_y: float,
	far_ground_y: float,
	vanishing_point: Vector2
) -> float:
	if p <= 1.0:
		return lerpf(tee_y, far_ground_y, maxf(p, 0.0))
	var extrap := 1.0 - exp(-(p - 1.0) * 2.0)
	return lerpf(far_ground_y, vanishing_point.y + 0.5, extrap)


static func p_at_y_segment(y: float, tee_y: float, far_ground_y: float) -> float:
	var span := tee_y - far_ground_y
	if absf(span) < 0.001:
		return 0.0
	return clampf((tee_y - y) / span, 0.0, 1.0)


static func scale_at_y(y: float, vanishing_point: Vector2, tee_y: float) -> float:
	var near_dist := tee_y - vanishing_point.y
	if absf(near_dist) < 0.001:
		return 1.0
	return maxf((y - vanishing_point.y) / near_dist, 0.0)


static func centerline_x_at_y(
	y: float,
	vanishing_point: Vector2,
	tee_x: float,
	ground_bottom_y: float
) -> float:
	return FairwayStripes.perspective_x_at_y(
		vanishing_point, tee_x, ground_bottom_y, y
	)


## Legacy helpers — prefer y_at_p / scale_at_y for flight.
static func ground_y_at_depth(t: float, tee_y: float, horizon_y: float) -> float:
	return lerpf(tee_y, horizon_y, clampf(t, 0.0, 1.0))


static func depth_at_ground_y(y: float, tee_y: float, horizon_y: float) -> float:
	return p_at_y_segment(y, tee_y, horizon_y)
