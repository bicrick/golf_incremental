class_name RattlingSpriteFrames
extends RefCounted
## Builds Rattling SpriteFrames from 76x76 atlas sheets (4 cols x 13 frames).
## Art faces right; agents flip_h to face left.

const BASE := "res://assets/sprites/rattling"
const WALK_SHEET := BASE + "/rattling-walking.png"
const WALK_BALL_SHEET := BASE + "/rattling-walking-with-ball.png"
const PICKUP_SHEET := BASE + "/rattling-picking-up-ball.png"
const IDLE_TEXTURE := BASE + "/rattling.png"
const IDLE_BALL_TEXTURE := BASE + "/rattling-with-ball.png"

const FRAME_SIZE := 76
const SHEET_COLS := 4
const FRAME_COUNT := 13
const WALK_FPS := 10.0
const PICKUP_FPS := 10.0
## 0-indexed frame where the ball first appears in the Rattling's hands
## (the "3rd frame" of the pickup sheet) — ground litter is removed here.
const PICKUP_BALL_FRAME := 2
const FOOT_OFFSET := Vector2(0.0, -float(FRAME_SIZE) * 0.5)


static func frame_region(index: int) -> Rect2i:
	var col := index % SHEET_COLS
	var row := index / SHEET_COLS
	return Rect2i(col * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)


static func make_atlas_frame(sheet: Texture2D, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = frame_region(index)
	return atlas


static var _cached_frames: SpriteFrames = null


## Shared, stateless SpriteFrames resource — safe to reuse across every
## Rattling instance (up to 25-50 concurrent agents) without rebuilding atlases.
static func get_shared_frames() -> SpriteFrames:
	if _cached_frames == null:
		_cached_frames = make_frames()
	return _cached_frames


static func make_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var walk_sheet: Texture2D = load(WALK_SHEET)
	var walk_ball_sheet: Texture2D = load(WALK_BALL_SHEET)
	var pickup_sheet: Texture2D = load(PICKUP_SHEET)

	frames.add_animation(&"walk")
	frames.set_animation_loop(&"walk", true)
	frames.set_animation_speed(&"walk", WALK_FPS)
	for i in FRAME_COUNT:
		frames.add_frame(&"walk", make_atlas_frame(walk_sheet, i))

	frames.add_animation(&"walk_ball")
	frames.set_animation_loop(&"walk_ball", true)
	frames.set_animation_speed(&"walk_ball", WALK_FPS)
	for i in FRAME_COUNT:
		frames.add_frame(&"walk_ball", make_atlas_frame(walk_ball_sheet, i))

	frames.add_animation(&"pickup")
	frames.set_animation_loop(&"pickup", false)
	frames.set_animation_speed(&"pickup", PICKUP_FPS)
	for i in FRAME_COUNT:
		frames.add_frame(&"pickup", make_atlas_frame(pickup_sheet, i))

	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.add_frame(&"idle", load(IDLE_TEXTURE))

	frames.add_animation(&"idle_ball")
	frames.set_animation_loop(&"idle_ball", true)
	frames.add_frame(&"idle_ball", load(IDLE_BALL_TEXTURE))

	return frames
