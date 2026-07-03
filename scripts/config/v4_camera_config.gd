class_name V4CameraConfig
extends RefCounted
## v4 orthographic camera — rotation locked project-wide; position and ortho size may vary per scene.
##
## Source of truth: `ratina_bay_cell.tscn` → `EditorOnly/Camera3D`.
## Re-sync LOCKED_BASIS + HITTING_CELL_DEFAULT_POSITION from that node's transform.
##
## IMPORTANT: `.tscn` Transform3D layout is (xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz).
## Basis columns are (xx,yx,zx), (xy,yy,zy), (xz,yz,zz) — NOT the three row triples.

## Locked rotation from ratina `EditorOnly/Camera3D`.
const LOCKED_BASIS := Basis(
	Vector3(0.9608136, 0.0, -0.27719548),
	Vector3(-0.06625118, 0.97101825, -0.2296395),
	Vector3(0.26916188, 0.23900528, 0.93296754)
)

const HITTING_CELL_DEFAULT_SIZE := 8.0
const HITTING_CELL_DEFAULT_POSITION := Vector3(1.470001, 1.5166433, 2.1563973)

const RANGE_HOME_SIZE := HITTING_CELL_DEFAULT_SIZE
const RANGE_HOME_POSITION := HITTING_CELL_DEFAULT_POSITION


static func locked_transform(position: Vector3) -> Transform3D:
	return Transform3D(LOCKED_BASIS, position)


static func apply_home_rig(camera: Camera3D) -> void:
	apply_locked_rotation(camera, HITTING_CELL_DEFAULT_POSITION, HITTING_CELL_DEFAULT_SIZE)


static func apply_locked_rotation(camera: Camera3D, position: Vector3, ortho_size: float) -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.transform = locked_transform(position)
	camera.size = ortho_size
