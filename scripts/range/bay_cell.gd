@tool
extends "res://scripts/range/cell_rig.gd"
## 2×2 yd hitting bay — full cell rig plus golfer and ball sprites.

const BALL_PIXEL_SIZE := 0.021
const GOLFER_PIXEL_SIZE := 0.024

@onready var _golfer: AnimatedSprite3D = $Golfer
@onready var _ball: AnimatedSprite3D = $Ball


func _ready() -> void:
	super._ready()
	_setup_sprites()
	if not Engine.is_editor_hint():
		_play_idle()


func _setup_sprites() -> void:
	pass


func get_golfer() -> AnimatedSprite3D:
	return _golfer


func get_ball() -> AnimatedSprite3D:
	return _ball


func strike_home() -> Vector3:
	return _golfer.position if _golfer else Vector3.ZERO


func ball_strike_home() -> Vector3:
	return _ball.position if _ball else Vector3.ZERO


func get_base_golfer_scale() -> Vector3:
	return _golfer.scale if _golfer else Vector3.ONE


func get_base_ball_scale() -> Vector3:
	return _ball.scale if _ball else Vector3.ONE


func apply_sprite_tint(tint: Color) -> void:
	if _golfer:
		_golfer.modulate = tint
	if _ball:
		_ball.modulate = tint


func _configure_billboard(sprite: SpriteBase3D, pixel_size: float) -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false


func _strip_empty_default_animation(frames: SpriteFrames) -> void:
	if frames == null:
		return
	if frames.has_animation(&"default") and frames.get_frame_count(&"default") == 0:
		frames.remove_animation(&"default")


func _play_idle() -> void:
	if _golfer:
		_golfer.animation = &"idle"
		_golfer.frame = 0
		_golfer.play(&"idle")
	if _ball:
		_ball.animation = &"idle"
		_ball.frame = 0
		_ball.play(&"idle")
