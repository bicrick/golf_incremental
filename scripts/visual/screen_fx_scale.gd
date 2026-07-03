class_name ScreenFxScale
extends RefCounted
## Orthographic zoom compensation for world-anchored screen FX.


static func compensation(camera: Camera3D, reference_ortho_size: float) -> float:
	if camera == null:
		return 1.0
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		return 1.0
	if reference_ortho_size <= 0.0:
		return 1.0
	return reference_ortho_size / camera.size
