class_name PerspectiveGround
extends RefCounted
## Shared fake-3D ground plane math for fairway, mat, and ball flight.


static func ground_y_at_depth(t: float, tee_y: float, horizon_y: float) -> float:
	return lerpf(tee_y, horizon_y, clampf(t, 0.0, 1.0))


static func depth_at_ground_y(y: float, tee_y: float, horizon_y: float) -> float:
	var span := tee_y - horizon_y
	if absf(span) < 0.001:
		return 0.0
	return clampf((tee_y - y) / span, 0.0, 1.0)


static func centerline_x_at_y(
	y: float,
	vanishing_point: Vector2,
	tee_x: float,
	tee_y: float
) -> float:
	return FairwayStripes.perspective_x_at_y(vanishing_point, tee_x, tee_y, y)


static func scale_at_depth(t: float, near_scale: float, far_scale: float) -> float:
	return lerpf(near_scale, far_scale, clampf(t, 0.0, 1.0))
