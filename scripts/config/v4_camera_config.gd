class_name V4CameraConfig
extends RefCounted
## v4 orthographic cameras — two locked rotations; position and ortho size are scene-authored.
##
## Bay / PixelLab lock: `LOCKED_BASIS` — 2:1 dimetric `Vector3(-26.565, 45.0, 0.0)` (Godot YXZ).
## Harvest lock: `HARVEST_LOCKED_BASIS` — pre-IsoView 3D pose `Vector3(-13.828, 16.093, 0.0)`.
## Strike still uses `PerspectiveCamera` — do not apply either lock to it.
##
## Position and ortho `size` live in each scene's Camera3D node (or bay `@export` fields).
##
## IMPORTANT: `.tscn` Transform3D layout is (xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz).
## Basis columns are (xx,yx,zx), (xy,yy,zy), (xz,yz,zz) — NOT the three row triples.

## Locked 2:1 dimetric: pitch -26.565°, yaw 45°, roll 0°.
## Bay editor cameras / PixelLab tile alignment only — not the live harvest rig.
const LOCKED_BASIS := Basis(
	Vector3(0.70710678, 0.0, -0.70710678),
	Vector3(-0.31622720, 0.89442759, -0.31622720),
	Vector3(0.63245581, 0.44721280, 0.63245581)
)

## Last 3D harvest lock before IsoView (ratina `EditorOnly/Camera3D`, Jul 2–26).
## Euler YXZ: pitch ≈ -13.828°, yaw ≈ 16.093°, roll 0°. Look ≈ (-0.27, -0.24, -0.93).
const HARVEST_LOCKED_BASIS := Basis(
	Vector3(0.9608136, 0.0, -0.27719548),
	Vector3(-0.06625118, 0.97101825, -0.2296395),
	Vector3(0.26916188, 0.23900528, 0.93296754)
)


static func locked_transform(position: Vector3) -> Transform3D:
	return Transform3D(LOCKED_BASIS, position)


static func harvest_locked_transform(position: Vector3) -> Transform3D:
	return Transform3D(HARVEST_LOCKED_BASIS, position)


static func apply_locked_rotation_only(camera: Camera3D) -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var origin := camera.transform.origin
	camera.transform = Transform3D(LOCKED_BASIS, origin)


static func apply_harvest_locked_rotation_only(camera: Camera3D) -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var origin := camera.transform.origin
	camera.transform = Transform3D(HARVEST_LOCKED_BASIS, origin)


static func apply_locked_rotation(camera: Camera3D, position: Vector3, ortho_size: float) -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.transform = locked_transform(position)
	camera.size = ortho_size
