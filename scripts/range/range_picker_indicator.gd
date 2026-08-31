class_name RangePickerIndicator
extends Node3D
## Dashed ground circle for pickable harvest fairway; tiny projected X when
## the cursor is over fog-of-war or off the grass.

const GROUND_LIFT := 0.02
const SEGMENTS := 48
const DASH_ON := 2
const DASH_OFF := 2
## Half-extent of the blocked-cursor X (yards).
const BLOCKED_X_HALF := 0.14

var _ring_mesh: MeshInstance3D
var _x_mesh: MeshInstance3D
var _camera_getter: Callable
var _visible_getter: Callable
var _fog_getter: Callable
var _last_radius := -1.0


func setup(
	camera_getter: Callable,
	visible_getter: Callable,
	fog_getter: Callable = Callable()
) -> void:
	_camera_getter = camera_getter
	_visible_getter = visible_getter
	_fog_getter = fog_getter
	_ring_mesh = _make_line_mesh_instance(&"RingMesh")
	_x_mesh = _make_line_mesh_instance(&"BlockedXMesh")
	_x_mesh.mesh = _build_blocked_x()
	_ring_mesh.visible = false
	_x_mesh.visible = false
	visible = false


func _make_line_mesh_instance(node_name: StringName) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	add_child(mesh_instance)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.98, 1.0, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_receive_shadows = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	return mesh_instance


func _process(_delta: float) -> void:
	if _visible_getter == null or not _visible_getter.is_valid() or not _visible_getter.call():
		_hide_glyphs()
		return
	var camera: Camera3D = _camera_getter.call() if _camera_getter.is_valid() else null
	if camera == null:
		_hide_glyphs()
		return
	var mouse := get_viewport().get_mouse_position()
	var tip_hit: Variant = RangeGroundRay.hit(camera, mouse)
	if tip_hit == null:
		_hide_glyphs()
		return
	var tip_ground: Vector3 = tip_hit
	# Blocked glyph follows the cursor tip only — never the ring-center offset,
	# which sits further down-range and would paint an X on still-clear grass.
	if is_blocked_ground(tip_ground, _fog_state()):
		visible = true
		_show_blocked(tip_ground)
		return
	var radius := Balance.range_picker_radius_yards(_player_stats())
	var hit: Variant = picker_ground_at_cursor(camera, mouse, radius)
	if hit == null:
		_hide_glyphs()
		return
	visible = true
	_show_ring(hit as Vector3, radius)


func _player_stats() -> PlayerStats:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return Balance.default_stats()
	return gs.stats


func _fog_state() -> Dictionary:
	if _fog_getter.is_valid():
		var state: Variant = _fog_getter.call()
		if typeof(state) == TYPE_DICTIONARY:
			return state
	return {"active": false, "tee_z": 0.0, "reveal_yards": 0.0}


func _hide_glyphs() -> void:
	visible = false
	if _ring_mesh:
		_ring_mesh.visible = false
	if _x_mesh:
		_x_mesh.visible = false


func _show_ring(ground: Vector3, radius: float) -> void:
	global_position = Vector3(ground.x, GROUND_LIFT, ground.z)
	if _x_mesh:
		_x_mesh.visible = false
	if _ring_mesh:
		_ring_mesh.visible = true
		if absf(radius - _last_radius) > 0.001:
			_last_radius = radius
			_ring_mesh.mesh = _build_dashed_ring(radius)


func _show_blocked(ground: Vector3) -> void:
	global_position = Vector3(ground.x, GROUND_LIFT, ground.z)
	if _ring_mesh:
		_ring_mesh.visible = false
	if _x_mesh:
		_x_mesh.visible = true


## Fairway grass rectangle (RangeGrid). Infinite ground plane hits outside still count as off-map.
static func is_on_fairway(ground: Vector3) -> bool:
	return (
		absf(ground.x) <= RangeGrid.HALF_WIDTH_YARDS
		and ground.z <= 0.0
		and ground.z >= -RangeGrid.DEPTH_YARDS
	)


static func is_in_harvest_fog(ground: Vector3, tee_z: float, reveal_yards: float) -> bool:
	var yards_from_tee := -(ground.z - tee_z)
	return yards_from_tee >= reveal_yards


static func is_blocked_ground(ground: Vector3, fog_state: Dictionary) -> bool:
	if not is_on_fairway(ground):
		return true
	if bool(fog_state.get("active", false)):
		return is_in_harvest_fog(
			ground,
			float(fog_state.get("tee_z", 0.0)),
			float(fog_state.get("reveal_yards", 0.0))
		)
	return false


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
	return _lines_mesh(verts, indices)


static func _build_blocked_x() -> ArrayMesh:
	var h := BLOCKED_X_HALF
	var verts := PackedVector3Array([
		Vector3(-h, 0.0, -h),
		Vector3(h, 0.0, h),
		Vector3(-h, 0.0, h),
		Vector3(h, 0.0, -h),
	])
	var indices := PackedInt32Array([0, 1, 2, 3])
	return _lines_mesh(verts, indices)


static func _lines_mesh(verts: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
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
