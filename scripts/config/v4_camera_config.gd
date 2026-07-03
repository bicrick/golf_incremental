class_name V4CameraConfig
extends RefCounted
## v4 orthographic camera — rotation is locked project-wide; position and ortho size may vary per scene.

## Locked rotation from `hitting_cell.tscn` (Align Transform With View, 2026-03-06).
## Do not change without re-authoring ground/prop art against the reference rig.
## Euler (approx, YXZ): (13.36°, -18.58°, -4.44°) — use LOCKED_BASIS as source of truth.
const LOCKED_BASIS := Basis(
	Vector3(0.9507437, -0.07534615, 0.30068162),
	Vector3(0.0, 0.97000897, 0.24306919),
	Vector3(-0.3099782, -0.23109649, 0.9222299)
)

## Default ortho size for the atomic cell reference rig (`hitting_cell.tscn`).
const HITTING_CELL_DEFAULT_SIZE := 8.0

## Default camera position for the atomic cell reference rig (tunable; rotation is not).
const HITTING_CELL_DEFAULT_POSITION := Vector3(1.0608382, 1.3295639, 1.8959681)

## Starting ortho size for the full range scene — tune to frame 50×300 yd grid.
const RANGE_VIEW_DEFAULT_SIZE := 18.0

## Starting camera position for the full range scene — tune for framing only.
const RANGE_VIEW_DEFAULT_POSITION := Vector3(0.0, 12.0, 12.0)


static func locked_transform(position: Vector3) -> Transform3D:
	return Transform3D(LOCKED_BASIS, position)


static func apply_locked_rotation(camera: Camera3D, position: Vector3, ortho_size: float) -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.transform = locked_transform(position)
	camera.size = ortho_size
