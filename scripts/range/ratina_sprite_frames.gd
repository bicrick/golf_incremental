class_name RatinaSpriteFrames
extends RefCounted
## Builds Ratina golfer SpriteFrames from 52x52 atlas sheets.

const BASE := "res://assets/sprites/ratina"
const IDLE_SHEET := BASE + "/ratina-idle-sheet.png"
const WAITING_SHEET := BASE + "/ratina-waiting-sheet.png"
const SWING_SHEET := BASE + "/ratina-swing-sheet.png"

const FRAME_SIZE := 52
const IDLE_COLS := 4
const IDLE_FRAME_COUNT := 11
const IDLE_FPS := 2.5
const WAITING_COLS := 5
const WAITING_FRAME_COUNT := 17
const WAITING_FPS := 6.0
const SWING_COLS := 5
# 17-frame swing sheet (5 cols x 4 rows) — same layout and count as Range Rat.
const SWING_FRAME_COUNT := 17
const WINDUP_LAST := 11       # wind-up frames 0-11
const CONTACT_FRAME := 12     # ball launch / strike frame
const FOLLOW_START := 13      # follow-through frames 13-16
const FOLLOW_END := 16
const FOLLOW_HOLD_FRAMES := 2 # follow pose frames shown after contact before cooldown
const FOLLOW_FPS := 12.0
const SWING_FPS := float(CONTACT_FRAME) / Balance.CONTACT_WINDUP_SEC
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
	var waiting_sheet: Texture2D = load(WAITING_SHEET)
	var swing_sheet: Texture2D = load(SWING_SHEET)

	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.set_animation_speed(&"idle", IDLE_FPS)
	for i in IDLE_FRAME_COUNT:
		frames.add_frame(&"idle", make_atlas_frame(idle_sheet, IDLE_COLS, i))

	frames.add_animation(&"waiting")
	frames.set_animation_loop(&"waiting", true)
	frames.set_animation_speed(&"waiting", WAITING_FPS)
	for i in WAITING_FRAME_COUNT:
		frames.add_frame(&"waiting", make_atlas_frame(waiting_sheet, WAITING_COLS, i))

	frames.add_animation(&"swing")
	frames.set_animation_loop(&"swing", false)
	frames.set_animation_speed(&"swing", SWING_FPS)
	for i in SWING_FRAME_COUNT:
		frames.add_frame(&"swing", make_atlas_frame(swing_sheet, SWING_COLS, i))

	frames.add_animation(&"follow")
	frames.set_animation_loop(&"follow", false)
	frames.set_animation_speed(&"follow", FOLLOW_FPS)
	for i in range(FOLLOW_START, FOLLOW_END + 1):
		frames.add_frame(&"follow", make_atlas_frame(swing_sheet, SWING_COLS, i))

	return frames
