extends MeshInstance3D
## Soft oval blob under a bay golfer — fake contact shadow (lights stay shadow-off).

const NODE_NAME := "GolferBlobShadow"
const TEXTURE_SIZE := 64
## Slightly above the mat top (BayMatGround.MAT_Y) so the quad does not z-fight.
const SHADOW_Y := 0.034
const RADIUS_X := 0.26
const RADIUS_Z := 0.13
## Warm dark, not pure black — see docs/design/07-art-and-atmosphere.md
const SHADOW_COLOR := Color(0.14, 0.11, 0.08, 0.36)
const RENDER_PRIORITY := 7

static var _soft_texture: ImageTexture

var _golfer: Node3D


static func ensure_on(bay: Node3D, golfer: Node3D) -> MeshInstance3D:
	if bay == null or golfer == null:
		return null
	var existing := bay.get_node_or_null(NODE_NAME)
	if existing == null:
		var script: GDScript = load("res://scripts/visual/golfer_blob_shadow.gd") as GDScript
		existing = script.new()
		existing.name = NODE_NAME
		bay.add_child(existing)
	if existing.has_method(&"bind_golfer"):
		existing.call(&"bind_golfer", golfer)
	return existing as MeshInstance3D


func _ready() -> void:
	_build_mesh_if_needed()
	set_process(true)
	_sync_to_golfer()


func bind_golfer(golfer: Node3D) -> void:
	_golfer = golfer
	_build_mesh_if_needed()
	_sync_to_golfer()


func _process(_delta: float) -> void:
	_sync_to_golfer()


func _sync_to_golfer() -> void:
	if _golfer == null or not is_instance_valid(_golfer):
		return
	var p := _golfer.position
	position = Vector3(p.x, SHADOW_Y, p.z)


func _build_mesh_if_needed() -> void:
	if mesh != null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(RADIUS_X * 2.0, RADIUS_Z * 2.0)
	mesh = quad
	rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = SHADOW_COLOR
	mat.albedo_texture = _get_soft_texture()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = RENDER_PRIORITY
	mat.disable_receive_shadows = true
	set_surface_override_material(0, mat)


static func _get_soft_texture() -> ImageTexture:
	if _soft_texture != null:
		return _soft_texture
	var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := (TEXTURE_SIZE - 1) * 0.5
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var nx := (float(x) - center) / center
			var ny := (float(y) - center) / center
			var dist_sq := nx * nx + ny * ny
			var alpha := clampf(1.0 - dist_sq, 0.0, 1.0)
			alpha *= alpha
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_soft_texture = ImageTexture.create_from_image(img)
	return _soft_texture
