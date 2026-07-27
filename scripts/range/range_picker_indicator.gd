class_name RangePickerIndicator
extends Node3D
## Dashed ground circle showing range-picker collection radius during harvest.

const GROUND_LIFT := 0.02
const SEGMENTS := 48
const DASH_ON := 2
const DASH_OFF := 2

var _mesh_instance: MeshInstance3D
var _camera_getter: Callable
var _visible_getter: Callable
var _last_radius := -1.0


func setup(camera_getter: Callable, visible_getter: Callable) -> void:
	_camera_getter = camera_getter
	_visible_getter = visible_getter
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "RingMesh"
	add_child(_mesh_instance)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.98, 1.0, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_receive_shadows = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_instance.material_override = mat
	visible = false


func _process(_delta: float) -> void:
	if _visible_getter == null or not _visible_getter.is_valid() or not _visible_getter.call():
		visible = false
		return
	var camera: Camera3D = _camera_getter.call() if _camera_getter.is_valid() else null
	if camera == null:
		visible = false
		return
	var mouse := get_viewport().get_mouse_position()
	var radius := Balance.range_picker_radius_yards(GameState.stats)
	var hit: Variant = picker_ground_at_cursor(camera, mouse, radius)
	if hit == null:
		visible = false
		return
	visible = true
	var ground: Vector3 = hit
	global_position = Vector3(ground.x, GROUND_LIFT, ground.z)
	if absf(radius - _last_radius) > 0.001:
		_last_radius = radius
		_mesh_instance.mesh = _build_dashed_ring(radius)


static func _build_dashed_ring(radius: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var cycle := DASH_ON + DASH_OFF
	for i in SEGMENTS:
		if i % cycle >= DASH_ON:
			continue
		var a0 := TAU * float(i) / float(SEGMENTS)
		var a1 := TAU * float(i + 1) / float(SEGMENTS)
		var base := verts.size()
		verts.append(Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
		verts.append(Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
		indices.append_array(PackedInt32Array([base, base + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


static func litter_ground_xz(sprite: Sprite3D) -> Vector2:
	var pos := sprite.global_position
	return Vector2(pos.x, pos.z)


static func screen_radius_px(camera: Camera3D, ground: Vector3, world_radius: float) -> float:
	var center := camera.unproject_position(ground)
	var edge := camera.unproject_position(ground + Vector3(world_radius, 0.0, 0.0))
	return maxf(4.0, center.distance_to(edge))


## Ground point for the pick circle center. Offset so the cursor tip sits on the
## bottom rim of the ring (screen-up by projected radius), not the circle center.
static func picker_ground_at_cursor(
	camera: Camera3D, mouse_pos: Vector2, world_radius: float
) -> Variant:
	var tip_hit: Variant = RangeGroundRay.hit(camera, mouse_pos)
	if tip_hit == null:
		return null
	var tip_ground: Vector3 = tip_hit
	var screen_r := screen_radius_px(camera, tip_ground, world_radius)
	var center_hit: Variant = RangeGroundRay.hit(camera, mouse_pos + Vector2(0.0, -screen_r))
	return tip_hit if center_hit == null else center_hit
