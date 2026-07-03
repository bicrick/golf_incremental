@tool
extends "res://scripts/range/bay_cell.gd"


func _setup_sprites() -> void:
	var golfer := get_node_or_null("Golfer") as AnimatedSprite3D
	if golfer:
		golfer.sprite_frames = RatinaSpriteFrames.make_golfer_frames()
		_strip_empty_default_animation(golfer.sprite_frames)
		_configure_billboard(golfer, GOLFER_PIXEL_SIZE)
		golfer.offset = RatinaSpriteFrames.FOOT_OFFSET
		if Engine.is_editor_hint():
			golfer.animation = &"idle"
			golfer.frame = 0
	var ball := get_node_or_null("Ball") as AnimatedSprite3D
	if ball:
		ball.sprite_frames = DinkySpriteFrames.make_ball_frames()
		_strip_empty_default_animation(ball.sprite_frames)
		_configure_billboard(ball, BALL_PIXEL_SIZE)
		if Engine.is_editor_hint():
			ball.animation = &"idle"
			ball.frame = 0
