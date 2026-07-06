class_name RangeGroundRay
extends RefCounted
## Screen raycast to the fairway ground plane (y = 0).

const GROUND_Y := 0.0


static func hit(camera: Camera3D, screen_pos: Vector2, ground_y: float = GROUND_Y) -> Variant:
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := (ground_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t
