class_name StrikeFeedbackBillboard
extends Node3D
## World-space billboard for player strike feedback (tier name + counting
## yardage). Wraps the existing screen-space `YardageStack` UI inside a
## SubViewport rendered onto a `Sprite3D` quad, so all of its stacking /
## bump / fade juice is reused unmodified — only where it renders changes.
##
## Orientation is locked to whichever camera is bound via `setup()` — the
## perspective "strike" camera — and never re-faces another camera, even
## while that other camera (harvest ortho) is the one currently rendering
## the scene. Callers should bind the strike camera once and leave it bound
## across view-mode switches.

const YardageStackScript := preload("res://scripts/visual/yardage_stack.gd")

## Render target for the wrapped 2D stack. Tall enough to hold two bumped
## stack entries (see YardageStack.BUMP_STEP_Y) above the anchor point.
## Sized 2x the prior RT so PressStart2P glyphs stay sharp when nearest-sampled
## onto the world quad.
const VIEWPORT_SIZE := Vector2i(480, 336)
## Anchor point inside the viewport that stack entries grow upward from.
const STACK_ANCHOR := Vector2(240.0, 300.0)
## World units per texture pixel — below the 0.016 "same size as old" value so
## the 2x-font stack reads smaller on screen while staying sharp.
const DEFAULT_PIXEL_SIZE := 0.012
## Direction-to-camera vs. world-up must not be near-parallel or look_at()
## errors; skip the (rare) reorientation that frame instead of crashing.
const MAX_UP_ALIGNMENT := 0.999

var _viewport: SubViewport
var _sprite: Sprite3D
var _stack: YardageStack
var _face_camera: Camera3D


func _ready() -> void:
	_build()
	_face_camera_now()


## Binds the camera this billboard always faces. Pass the strike/perspective
## camera only — never the harvest ortho camera, and never a "currently
## active camera" getter that changes across view-mode switches.
func setup(face_camera: Camera3D) -> void:
	_face_camera = face_camera
	_face_camera_now()


func begin(tier: int, final_yards: float) -> int:
	return _stack.begin(tier, final_yards)


func set_progress(id: int, progress: float) -> void:
	_stack.set_progress(id, progress)


func finish(id: int) -> void:
	_stack.finish(id)


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_stack = YardageStackScript.new()
	_stack.position = STACK_ANCHOR
	_viewport.add_child(_stack)

	_sprite = Sprite3D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.pixel_size = DEFAULT_PIXEL_SIZE
	# Orientation is driven manually in _face_camera_now(); the built-in
	# billboard flag would instead face whichever camera is rendering.
	_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_sprite.shaded = false
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.centered = true
	add_child(_sprite)


func _process(_delta: float) -> void:
	_face_camera_now()


func _face_camera_now() -> void:
	if _face_camera == null or not is_instance_valid(_face_camera):
		return
	var to_camera := _face_camera.global_position - global_position
	if to_camera.length_squared() < 0.0001:
		return
	if absf(to_camera.normalized().dot(Vector3.UP)) > MAX_UP_ALIGNMENT:
		return
	# look_at() points -Z at the target; aim -Z away from the camera so the
	# sprite's front face (+Z) ends up pointing back at it, matching the
	# usual "faces the camera" billboard convention.
	look_at(global_position - to_camera, Vector3.UP)
