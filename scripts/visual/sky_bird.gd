@tool
extends AnimatedSprite3D
## Single ambient bird translating across X, ~50 yd down the fairway.
## Swaps between two runtime SpriteFrames sets (normal vs flip_x) when turning around.

const TRAVEL_HALF_X := 60.0
const SPEED := 5.0
const EDITOR_FLY_FPS := 10.0

var _direction := -1.0
var _editor_time := 0.0
var _frames_normal: SpriteFrames
var _frames_flipped: SpriteFrames
var _using_flipped := false


func _ready() -> void:
	_frames_normal = SkyBirdFrames.make_fly_frames(false)
	_frames_flipped = SkyBirdFrames.make_fly_frames(true)
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	position.x = TRAVEL_HALF_X
	_apply_facing(true)


func _apply_facing(force := false) -> void:
	# Atlas faces left; Y-billboard mirrors screen left/right vs world X, so
	# world -X (moving left) needs the flipped texture set to read correctly.
	var want_flipped := _direction < 0.0
	if not force and want_flipped == _using_flipped:
		return

	_using_flipped = want_flipped
	var wing_phase := frame
	sprite_frames = _frames_flipped if want_flipped else _frames_normal
	animation = &"fly"
	frame = wing_phase % SkyBirdFrames.FLY_FRAME_COUNT
	if not Engine.is_editor_hint():
		play(&"fly")


func _process(delta: float) -> void:
	position.x += _direction * SPEED * delta
	if position.x <= -TRAVEL_HALF_X:
		position.x = -TRAVEL_HALF_X
		_direction = 1.0
		_apply_facing()
	elif position.x >= TRAVEL_HALF_X:
		position.x = TRAVEL_HALF_X
		_direction = -1.0
		_apply_facing()

	if Engine.is_editor_hint():
		_editor_time += delta
		frame = int(_editor_time * EDITOR_FLY_FPS) % SkyBirdFrames.FLY_FRAME_COUNT
