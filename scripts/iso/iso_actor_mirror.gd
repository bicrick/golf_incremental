class_name IsoActorMirror
extends AnimatedSprite2D
## Mirrors an AnimatedSprite3D / SpriteBase3D into iso pixel space.
## Player pose: when pose_placeholder is set, idle sits exactly at placeholder.position
## (editor WYSIWYG); motion is iso delta from pose_rest_yards.
## Without a placeholder: GROUND_DISPLAY_BIAS + ACTOR_PIXEL_SCALE / litter scale.

## Fallback when no PlayerGolferPlaceholder is authored.
const ACTOR_PIXEL_SCALE := 2.0 / 3.0
## Fallback ground nudge (iso screen up-left) when no pose placeholder.
## Keep in sync with IsoGrid.VIEW_ORIGIN_BIAS_YARDS.
const GROUND_DISPLAY_BIAS := Vector3(-0.35, 0.0, -0.85)


var source: SpriteBase3D
## When true, project ground (y=0) and keep sprite offset for foot placement.
## When false (in-flight ball), keep altitude so IsoGrid.height_px lifts the sprite.
var ground_anchored := true
var _ball_scale := 1.0
var _is_ball := false
## Optional Node2D authored in iso_view.tscn (position + scale drive this mirror).
var pose_placeholder: Node2D
## Ground yards for the 3D idle/home pose that the placeholder was authored against.
## When source is here, mirror.position == pose_placeholder.position.
var pose_rest_yards := Vector3.ZERO
var _has_pose_rest := false


func setup(
	src: SpriteBase3D,
	anchored: bool = true,
	as_ball: bool = false,
	placeholder: Node2D = null,
	rest_yards: Vector3 = Vector3.ZERO,
	has_rest: bool = false
) -> void:
	source = src
	ground_anchored = anchored
	_is_ball = as_ball
	pose_placeholder = placeholder
	pose_rest_yards = rest_yards
	_has_pose_rest = has_rest
	_ball_scale = _resolve_ball_scale()
	centered = true
	if as_ball:
		scale = Vector2(_ball_scale, _ball_scale)
	else:
		var s := _resolve_golfer_scale()
		scale = Vector2(s, s)
	## Pure mirror — never advance our own animation clock.
	if self is AnimatedSprite2D:
		pause()
	set_process(true)
	_sync()


func set_pose_rest_yards(rest_yards: Vector3) -> void:
	pose_rest_yards = Vector3(rest_yards.x, 0.0, rest_yards.z)
	_has_pose_rest = true


func _resolve_golfer_scale() -> float:
	if pose_placeholder != null and is_instance_valid(pose_placeholder):
		return pose_placeholder.scale.x
	return ACTOR_PIXEL_SCALE


func _resolve_ball_scale() -> float:
	if pose_placeholder != null and is_instance_valid(pose_placeholder):
		return pose_placeholder.scale.x
	## Fall back to IsoView's authored placeholder when flight/litter omit a direct ref.
	var iso := _find_iso_view()
	if iso != null:
		return iso.authored_ball_scale()
	return IsoView.litter_sprite_scale()


func _find_iso_view() -> IsoView:
	var n: Node = self
	while n != null:
		if n is IsoView:
			return n as IsoView
		n = n.get_parent()
	return null


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	if source == null or not is_instance_valid(source):
		visible = false
		return
	## Ratina reuses her tee ball for flight — flight layer owns that mirror.
	if (
		ground_anchored
		and _is_ball
		and source.is_in_group(&"range_flight_ball")
	):
		visible = false
		return
	visible = source.visible
	if not visible:
		return

	var world := source.global_position
	if ground_anchored:
		world.y = 0.0
		if pose_placeholder != null and is_instance_valid(pose_placeholder):
			## WYSIWYG: at 3D home, sit on the authored placeholder pixel.
			var live_px := IsoGrid.iso_px_from_yards(world)
			var rest_px := live_px
			if _has_pose_rest:
				rest_px = IsoGrid.iso_px_from_yards(pose_rest_yards)
			position = pose_placeholder.position + (live_px - rest_px)
			scale = pose_placeholder.scale
		else:
			position = IsoGrid.iso_px_from_yards(world + GROUND_DISPLAY_BIAS)
			if _is_ball:
				scale = Vector2(_ball_scale, _ball_scale)
	else:
		position = IsoGrid.iso_px_from_yards(world)
		if _is_ball:
			_ball_scale = _resolve_ball_scale()
			scale = Vector2(_ball_scale, _ball_scale)

	modulate = source.modulate
	if not source is AnimatedSprite3D:
		return
	var anim := source as AnimatedSprite3D
	if anim.sprite_frames != sprite_frames:
		sprite_frames = anim.sprite_frames
	if _is_ball:
		## Lock lay/idle — roll frames paint a growing ball silhouette.
		if sprite_frames != null and sprite_frames.has_animation(&"idle"):
			if animation != &"idle":
				animation = &"idle"
			frame = 0
			frame_progress = 0.0
		offset = Vector2.ZERO
		pause()
		return
	if anim.animation != animation:
		animation = anim.animation
	frame = anim.frame
	frame_progress = anim.frame_progress
	flip_h = anim.flip_h
	if (
		pose_placeholder is AnimatedSprite2D
		and is_instance_valid(pose_placeholder)
	):
		offset = (pose_placeholder as AnimatedSprite2D).offset
	else:
		offset = anim.offset
	pause()
