class_name V4CameraConfig
extends RefCounted
## v4 orthographic camera — rotation locked project-wide; position and ortho size are scene-authored.
##
## Source of truth for rotation: this file (`LOCKED_BASIS`).
## True 2:1 dimetric — `rotation_degrees = Vector3(-26.565, 45.0, 0.0)` (Godot YXZ).
## Matches PixelLab `tile_type=isometric` / Godot TileSet `tile_size = Vector2i(32, 16)` diamonds.
##
## Position and ortho `size` live in each scene's Camera3D node (or bay `@export` fields).
##
## IMPORTANT: `.tscn` Transform3D layout is (xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz).
## Basis columns are (xx,yx,zx), (xy,yy,zy), (xz,yz,zz) — NOT the three row triples.

## Locked 2:1 dimetric: pitch -26.565°, yaw 45°, roll 0°.
const LOCKED_BASIS := Basis(
	Vector3(0.70710678, 0.0, -0.70710678),
	Vector3(-0.31622720, 0.89442759, -0.31622720),
	Vector3(0.63245581, 0.44721280, 0.63245581)
)


static func locked_transform(position: Vector3) -> Transform3D:
	return Transform3D(LOCKED_BASIS, position)


static func apply_locked_rotation_only(camera: Camera3D) -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var origin := camera.transform.origin
	camera.transform = Transform3D(LOCKED_BASIS, origin)


static func apply_locked_rotation(camera: Camera3D, position: Vector3, ortho_size: float) -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.transform = locked_transform(position)
	camera.size = ortho_size
