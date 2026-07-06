class_name SkyBirdFrames
extends RefCounted
## Fly-cycle frames from bird_sprite.png row 2. Call with flip_h to mirror for the other direction.

const SHEET_PATH := "res://assets/sprites/ambient/bird_sprite.png"
const FRAME_SIZE := 16
const FLY_ROW := 1
const FLY_FRAME_COUNT := 8


static func make_fly_frames(flip_h: bool = false) -> SpriteFrames:
	var sheet := load(SHEET_PATH) as Texture2D
	if sheet == null:
		push_error("SkyBirdFrames: missing texture at %s" % SHEET_PATH)
		return SpriteFrames.new()

	var frames := SpriteFrames.new()
	frames.add_animation(&"fly")
	frames.set_animation_loop(&"fly", true)
	frames.set_animation_speed(&"fly", 10.0)

	for index in FLY_FRAME_COUNT:
		frames.add_frame(&"fly", _make_frame_texture(sheet, index, flip_h))

	return frames


static func _make_frame_texture(sheet: Texture2D, index: int, flip_h: bool) -> Texture2D:
	var img := sheet.get_image()
	var region := Rect2i(index * FRAME_SIZE, FLY_ROW * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
	var frame_img := img.get_region(region).duplicate()
	if flip_h:
		frame_img.flip_x()
	return ImageTexture.create_from_image(frame_img)
