class_name RangeRatSpriteFrames
extends RefCounted
## Builds Range Rat golfer SpriteFrames from 52x52 atlas sheets.

const BASE := "res://assets/sprites/range_rat"
const IDLE_SHEET := BASE + "/range-rat-idle-sheet.png"
const IDLE_OUT_OF_BALLS_SHEET := BASE + "/range-rat-idle-out-of-balls-sheet.png"
const SWING_SHEET := BASE + "/range-rat-swing-sheet.png"
const RETURN_SHEET := BASE + "/return-to-address.png"

const FRAME_SIZE := 52
const IDLE_COLS := 5
const IDLE_FRAME_COUNT := 17
const IDLE_FPS := 6.0
const IDLE_OUT_OF_BALLS_COLS := 5
const IDLE_OUT_OF_BALLS_FRAME_COUNT := 17
const IDLE_OUT_OF_BALLS_FPS := 6.0
const SWING_COLS := 5
const SWING_FRAME_COUNT := 17
const WINDUP_LAST := 7
const CONTACT_FRAME := 8
const FOLLOW_START := 9
const FOLLOW_END := 16
const FOLLOW_FPS := 12.0
const RETURN_COLS := 3
const RETURN_FRAME_COUNT := 7
const RETURN_FPS := 10.0
const FOOT_OFFSET := Vector2(0.0, -float(FRAME_SIZE) * 0.5)


static func frame_region(cols: int, index: int) -> Rect2i:
	var col := index % cols
	var row := index / cols
	return Rect2i(col * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)


static func make_atlas_frame(sheet: Texture2D, cols: int, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = frame_region(cols, index)
	return atlas


static func make_golfer_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var idle_sheet: Texture2D = load(IDLE_SHEET)
	var idle_out_sheet: Texture2D = load(IDLE_OUT_OF_BALLS_SHEET)
	var swing_sheet: Texture2D = load(SWING_SHEET)
	var return_sheet: Texture2D = load(RETURN_SHEET)

	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.set_animation_speed(&"idle", IDLE_FPS)
	for i in IDLE_FRAME_COUNT:
		frames.add_frame(&"idle", make_atlas_frame(idle_sheet, IDLE_COLS, i))

	frames.add_animation(&"idle_out_of_balls")
	frames.set_animation_loop(&"idle_out_of_balls", true)
	frames.set_animation_speed(&"idle_out_of_balls", IDLE_OUT_OF_BALLS_FPS)
	for i in IDLE_OUT_OF_BALLS_FRAME_COUNT:
		frames.add_frame(
			&"idle_out_of_balls",
			make_atlas_frame(idle_out_sheet, IDLE_OUT_OF_BALLS_COLS, i)
		)

	frames.add_animation(&"swing")
	frames.set_animation_loop(&"swing", false)
	for i in SWING_FRAME_COUNT:
		frames.add_frame(&"swing", make_atlas_frame(swing_sheet, SWING_COLS, i))

	frames.add_animation(&"follow")
	frames.set_animation_loop(&"follow", false)
	frames.set_animation_speed(&"follow", FOLLOW_FPS)
	for i in range(FOLLOW_START, FOLLOW_END + 1):
		frames.add_frame(&"follow", make_atlas_frame(swing_sheet, SWING_COLS, i))

	frames.add_animation(&"joy")
	frames.set_animation_loop(&"joy", false)
	frames.set_animation_speed(&"joy", 6.0)
	frames.add_frame(&"joy", make_atlas_frame(swing_sheet, SWING_COLS, FOLLOW_END))
	frames.add_frame(&"joy", make_atlas_frame(swing_sheet, SWING_COLS, FOLLOW_END - 1))

	frames.add_animation(&"return_to_address")
	frames.set_animation_loop(&"return_to_address", false)
	frames.set_animation_speed(&"return_to_address", RETURN_FPS)
	for i in RETURN_FRAME_COUNT:
		frames.add_frame(
			&"return_to_address",
			make_atlas_frame(return_sheet, RETURN_COLS, i)
		)

	return frames
