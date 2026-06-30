class_name DinkySpriteFrames
extends RefCounted
## Builds SpriteFrames from Dinky Tiny Golf imported singles.

const BASE := "res://assets/imported/dinky_tiny_golf/Dinky_Tiny_Golf_Free/Singles"
const BALL_ROLL_FRAME_COUNT := 11


static func ball_lay_texture() -> Texture2D:
	return load(BASE + "/Ball/Ball-Lay_0002_Fairway.png")


static func make_ball_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.add_frame(&"idle", load(BASE + "/Ball/Ball-Lay_0002_Fairway.png"))

	frames.add_animation(&"roll")
	frames.set_animation_loop(&"roll", true)
	for i in BALL_ROLL_FRAME_COUNT:
		frames.add_frame(&"roll", load(BASE + "/Ball/Ball-Sprites_%04d.png" % i))
	return frames


static func make_golfer_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.add_frame(&"idle", load(BASE + "/Player/Swing01.png"))

	frames.add_animation(&"swing")
	frames.set_animation_loop(&"swing", false)
	for i in range(1, 6):
		frames.add_frame(&"swing", load(BASE + "/Player/Swing%02d.png" % i))

	frames.add_animation(&"joy")
	frames.set_animation_loop(&"joy", false)
	frames.add_frame(&"joy", load(BASE + "/Player/Joy01.png"))
	frames.add_frame(&"joy", load(BASE + "/Player/Joy02.png"))
	return frames
