extends Control
## GPU freeze-frame dissolve for strike/harvest camera switches.
## Renders the outgoing camera once into a shared-world SubViewport and fades
## that ViewportTexture out — no CPU get_image() readback.

const FALLBACK_SIZE := Vector2i(480, 270)

@onready var _snapshot: TextureRect = $Snapshot
@onready var _freeze_viewport: SubViewport = $FreezeViewport
@onready var _freeze_camera: Camera3D = $FreezeViewport/FreezeCamera


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0
	_snapshot.visible = false
	_snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snapshot.stretch_mode = TextureRect.STRETCH_SCALE
	_freeze_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_freeze_viewport.handle_input_locally = false
	_freeze_viewport.transparent_bg = true
	_freeze_camera.current = true


## Freeze the outgoing 3D camera into a GPU ViewportTexture and show the overlay.
func capture_from_camera(from_camera: Camera3D) -> void:
	if from_camera == null or _freeze_viewport == null or _freeze_camera == null:
		return
	_sync_freeze_size()
	_copy_camera(from_camera, _freeze_camera)
	var world := from_camera.get_world_3d()
	if world != null:
		_freeze_viewport.world_3d = world
	_freeze_camera.current = true
	_freeze_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var tex := _freeze_viewport.get_texture()
	if tex == null:
		_freeze_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_snapshot.texture = tex
	_snapshot.visible = true
	visible = true
	modulate.a = 1.0
	_freeze_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func dissolve_out(duration: float) -> void:
	if duration <= 0.0:
		_clear_snapshot()
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_clear_snapshot()


func _clear_snapshot() -> void:
	modulate.a = 0.0
	visible = false
	_snapshot.visible = false
	_snapshot.texture = null
	if _freeze_viewport != null:
		_freeze_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _sync_freeze_size() -> void:
	var root := get_viewport()
	var size := FALLBACK_SIZE
	if root != null:
		var visible_size := root.get_visible_rect().size
		if visible_size.x >= 1.0 and visible_size.y >= 1.0:
			size = Vector2i(maxi(1, int(round(visible_size.x))), maxi(1, int(round(visible_size.y))))
	_freeze_viewport.size = size


func _copy_camera(from_cam: Camera3D, to_cam: Camera3D) -> void:
	to_cam.global_transform = from_cam.global_transform
	to_cam.projection = from_cam.projection
	to_cam.fov = from_cam.fov
	to_cam.size = from_cam.size
	to_cam.near = from_cam.near
	to_cam.far = from_cam.far
	to_cam.keep_aspect = from_cam.keep_aspect
	to_cam.cull_mask = from_cam.cull_mask
	to_cam.h_offset = from_cam.h_offset
	to_cam.v_offset = from_cam.v_offset
	to_cam.environment = from_cam.environment
	to_cam.attributes = from_cam.attributes
	to_cam.compositor = from_cam.compositor
