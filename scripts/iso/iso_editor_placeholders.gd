class_name IsoEditorPlaceholders
extends RefCounted
## Player golfer / tee-ball placeholders for IsoView editor tuning.
## Position + scale on these nodes are authored in iso_view.tscn and consumed at runtime.

const GOLFER_NAME := "PlayerGolferPlaceholder"
const BALL_NAME := "PlayerBallPlaceholder"
const GOLFER_EDITOR_ANIM := &"idle_out_of_balls"


static func golfer_node(actor_layer: Node) -> AnimatedSprite2D:
	if actor_layer == null:
		return null
	return actor_layer.get_node_or_null(GOLFER_NAME) as AnimatedSprite2D


static func ball_node(actor_layer: Node) -> AnimatedSprite2D:
	if actor_layer == null:
		return null
	return actor_layer.get_node_or_null(BALL_NAME) as AnimatedSprite2D


## Editor-authored ball scale, or projected litter fallback.
static func ball_scale(actor_layer: Node) -> float:
	var ball := ball_node(actor_layer)
	if ball != null and is_instance_valid(ball):
		return ball.scale.x
	return IsoView.litter_sprite_scale()


## Rest pose at view origin (player address) — placeholders default here.
static func rest_anchor_px() -> Vector2:
	return IsoGrid.iso_px_from_yards(IsoGrid.view_origin_yards())


static func default_golfer_px() -> Vector2:
	return rest_anchor_px()


static func default_ball_px() -> Vector2:
	return rest_anchor_px()


static func setup_for_editor(actor_layer: Node2D) -> void:
	if actor_layer == null:
		return
	var root := actor_layer.get_tree().edited_scene_root if actor_layer.get_tree() else null
	var golfer := _ensure_animated(
		actor_layer,
		GOLFER_NAME,
		1,
		default_golfer_px(),
		Vector2(IsoActorMirror.ACTOR_PIXEL_SCALE, IsoActorMirror.ACTOR_PIXEL_SCALE),
		root
	)
	golfer.sprite_frames = RangeRatSpriteFrames.make_golfer_frames()
	golfer.offset = RangeRatSpriteFrames.FOOT_OFFSET
	golfer.centered = true
	if golfer.sprite_frames.has_animation(GOLFER_EDITOR_ANIM):
		golfer.animation = GOLFER_EDITOR_ANIM
		golfer.play(GOLFER_EDITOR_ANIM)
	else:
		golfer.animation = &"idle"
		golfer.play(&"idle")
	golfer.visible = true

	var ball := _ensure_animated(
		actor_layer,
		BALL_NAME,
		2,
		default_ball_px(),
		Vector2(IsoView.litter_sprite_scale(), IsoView.litter_sprite_scale()),
		root
	)
	ball.sprite_frames = DinkySpriteFrames.make_ball_frames()
	ball.offset = Vector2.ZERO
	ball.centered = true
	ball.animation = &"idle"
	ball.play(&"idle")
	ball.visible = true


static func set_runtime_visible(actor_layer: Node, visible: bool) -> void:
	var golfer := golfer_node(actor_layer)
	if golfer:
		golfer.visible = visible
		if visible:
			if golfer.sprite_frames != null and golfer.sprite_frames.has_animation(GOLFER_EDITOR_ANIM):
				golfer.play(GOLFER_EDITOR_ANIM)
			else:
				golfer.play(&"idle")
		else:
			golfer.pause()
	var ball := ball_node(actor_layer)
	if ball:
		ball.visible = visible
		if visible:
			ball.play(&"idle")
		else:
			ball.pause()


static func _ensure_animated(
	parent: Node2D,
	node_name: String,
	z: int,
	default_pos: Vector2,
	default_scale: Vector2,
	edited_root: Node
) -> AnimatedSprite2D:
	var node := parent.get_node_or_null(node_name) as AnimatedSprite2D
	if node == null:
		node = AnimatedSprite2D.new()
		node.name = node_name
		node.position = default_pos
		node.scale = default_scale
		node.z_index = z
		parent.add_child(node)
		if edited_root:
			node.owner = edited_root
	elif node.position.length() > 500.0:
		## Migrate pre-view-origin scenes that stored absolute map coords.
		node.position = default_pos
	return node
