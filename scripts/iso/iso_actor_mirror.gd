class_name IsoActorMirror
extends AnimatedSprite2D
## Mirrors an AnimatedSprite3D / SpriteBase3D into iso pixel space.
## Actors draw at native art resolution (no downscale); balls use litter scale.
## Playback is paused — frame state is copied from the source each process.

## Native pixel art for golfers / props. Do not shrink higher-res sheets.
const ACTOR_PIXEL_SCALE := 1.0


var source: SpriteBase3D
## When true, project ground (y=0) and keep sprite offset for foot placement.
## When false (in-flight ball), keep altitude so IsoGrid.height_px lifts the sprite.
var ground_anchored := true
var _ball_scale := 1.0
var _is_ball := false


func setup(
	src: SpriteBase3D,
	anchored: bool = true,
	as_ball: bool = false
) -> void:
	source = src
	ground_anchored = anchored
	_is_ball = as_ball
	_ball_scale = IsoView.litter_sprite_scale()
	centered = true
	if as_ball:
		scale = Vector2(_ball_scale, _ball_scale)
	else:
		scale = Vector2(ACTOR_PIXEL_SCALE, ACTOR_PIXEL_SCALE)
	## Pure mirror — never advance our own animation clock.
	if self is AnimatedSprite2D:
		pause()
	set_process(true)
	_sync()


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	if source == null or not is_instance_valid(source):
		visible = false
		return
	visible = source.visible
	if not visible:
		return

	var world := source.global_position
	if ground_anchored:
		world.y = 0.0
	position = IsoGrid.iso_px_from_yards(world)

	modulate = source.modulate
	if source is Sprite3D:
		var spr := source as Sprite3D
		texture = spr.texture
		flip_h = spr.flip_h
		offset = spr.offset
		return

	if source is AnimatedSprite3D:
		var anim := source as AnimatedSprite3D
		if anim.sprite_frames != sprite_frames:
			sprite_frames = anim.sprite_frames
		if anim.animation != animation:
			animation = anim.animation
		frame = anim.frame
		frame_progress = anim.frame_progress
		flip_h = anim.flip_h
		offset = anim.offset
		pause()
