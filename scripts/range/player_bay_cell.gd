extends "res://scripts/range/bay_cell.gd"


func _setup_sprites() -> void:
	if _golfer:
		_golfer.sprite_frames = RangeRatSpriteFrames.make_golfer_frames()
		_strip_empty_default_animation(_golfer.sprite_frames)
		_configure_billboard(_golfer, GOLFER_PIXEL_SIZE)
		_golfer.offset = RangeRatSpriteFrames.FOOT_OFFSET
		if Engine.is_editor_hint():
			_golfer.animation = &"idle"
			_golfer.frame = 0
	if _ball:
		_ball.sprite_frames = DinkySpriteFrames.make_ball_frames()
		_strip_empty_default_animation(_ball.sprite_frames)
		_configure_billboard(_ball, BALL_PIXEL_SIZE)
		if Engine.is_editor_hint():
			_ball.animation = &"idle"
			_ball.frame = 0
