class_name IsoActorLayer
extends Node2D
## Owns IsoActorMirror instances for bay golfers and tee balls.
## Lazily resolves Ratina sprites (bay is spawned at runtime on RangeView).
## Parent stays untinted — mirrors copy SpriteBase3D.modulate 1:1 (no double night wash).
## PlayerGolferPlaceholder / PlayerBallPlaceholder: editor pose; hidden at runtime.
## Player mirrors inherit placeholder position + scale (WYSIWYG vs 3D strike home).

const IsoActorMirrorScript := preload("res://scripts/iso/iso_actor_mirror.gd")

var _range_view: Node3D
var _player_golfer: IsoActorMirror
var _player_ball: IsoActorMirror
var _ratina_golfer: IsoActorMirror
var _ratina_ball: IsoActorMirror
var _enabled := false


func setup(range_view: Node3D) -> void:
	_range_view = range_view
	IsoEditorPlaceholders.set_runtime_visible(self, false)
	_ensure_player_mirrors()
	_try_bind_ratina()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process(enabled)
	_set_mirrors_process(enabled)
	## Placeholders are editor-only; never show beside live mirrors.
	IsoEditorPlaceholders.set_runtime_visible(self, false)
	if enabled:
		_ensure_player_mirrors()
		_try_bind_ratina()


func get_player_golfer_mirror() -> IsoActorMirror:
	return _player_golfer


func get_ratina_golfer_mirror() -> IsoActorMirror:
	return _ratina_golfer


func get_player_golfer_placeholder() -> AnimatedSprite2D:
	return IsoEditorPlaceholders.golfer_node(self)


func get_player_ball_placeholder() -> AnimatedSprite2D:
	return IsoEditorPlaceholders.ball_node(self)


func _process(_delta: float) -> void:
	if not _enabled:
		return
	## Player refs / Ratina bay may not exist at first setup (ready order).
	if _player_golfer == null or not is_instance_valid(_player_golfer):
		_ensure_player_mirrors()
	if _ratina_golfer == null or not is_instance_valid(_ratina_golfer) or not is_instance_valid(_ratina_golfer.source):
		_try_bind_ratina()
	_refresh_player_pose_rests()


func _ensure_player_mirrors() -> void:
	if _range_view == null:
		return
	if _player_golfer == null or not is_instance_valid(_player_golfer):
		var golfer: AnimatedSprite3D = null
		if _range_view.has_method(&"get_golfer"):
			golfer = _range_view.get_golfer()
		if golfer != null:
			_player_golfer = _make_mirror(
				golfer,
				true,
				false,
				"PlayerGolferMirror",
				IsoEditorPlaceholders.golfer_node(self),
				_player_golfer_rest_yards(golfer)
			)
	if _player_ball == null or not is_instance_valid(_player_ball):
		var ball: AnimatedSprite3D = null
		if _range_view.has_method(&"get_ball"):
			ball = _range_view.get_ball()
		if ball != null:
			_player_ball = _make_mirror(
				ball,
				true,
				true,
				"PlayerBallMirror",
				IsoEditorPlaceholders.ball_node(self),
				_player_ball_rest_yards(ball)
			)
	_refresh_player_pose_rests()


func _player_golfer_rest_yards(golfer: SpriteBase3D) -> Vector3:
	if _range_view != null and _range_view.has_method(&"golfer_strike_home"):
		var bay: Node3D = _range_view.get("player_bay") as Node3D
		var home_local: Vector3 = _range_view.call(&"golfer_strike_home") as Vector3
		if bay != null:
			var g := bay.to_global(home_local)
			return Vector3(g.x, 0.0, g.z)
	if golfer != null:
		return Vector3(golfer.global_position.x, 0.0, golfer.global_position.z)
	return Vector3.ZERO


func _player_ball_rest_yards(ball: SpriteBase3D) -> Vector3:
	## Prefer live tee ball when at address; fall back to bay ball home if exposed.
	if _range_view != null and _range_view.get("player_bay") != null:
		var bay: Node3D = _range_view.get("player_bay") as Node3D
		if bay != null and bay.has_method(&"ball_strike_home"):
			var home_local: Vector3 = bay.call(&"ball_strike_home") as Vector3
			var g := bay.to_global(home_local)
			return Vector3(g.x, 0.0, g.z)
	if ball != null:
		return Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	return Vector3.ZERO


func _refresh_player_pose_rests() -> void:
	if _player_golfer != null and is_instance_valid(_player_golfer) and _player_golfer.source != null:
		_player_golfer.set_pose_rest_yards(_player_golfer_rest_yards(_player_golfer.source))
	if _player_ball != null and is_instance_valid(_player_ball) and _player_ball.source != null:
		_player_ball.set_pose_rest_yards(_player_ball_rest_yards(_player_ball.source))


func _try_bind_ratina() -> void:
	if _range_view == null:
		return
	var ratina_sprite: AnimatedSprite3D = _range_view.get("ratina_sprite") as AnimatedSprite3D
	var ratina_ball: AnimatedSprite3D = _range_view.get("ratina_ball_sprite") as AnimatedSprite3D
	if ratina_sprite != null and (_ratina_golfer == null or not is_instance_valid(_ratina_golfer)):
		_ratina_golfer = _make_mirror(ratina_sprite, true, false, "RatinaGolferMirror", null, Vector3.ZERO, false)
	elif _ratina_golfer != null and is_instance_valid(_ratina_golfer) and ratina_sprite != null:
		_ratina_golfer.source = ratina_sprite
	if ratina_ball != null and (_ratina_ball == null or not is_instance_valid(_ratina_ball)):
		_ratina_ball = _make_mirror(ratina_ball, true, true, "RatinaBallMirror", null, Vector3.ZERO, false)
	elif _ratina_ball != null and is_instance_valid(_ratina_ball) and ratina_ball != null:
		_ratina_ball.source = ratina_ball


func _make_mirror(
	src: SpriteBase3D,
	ground_anchored: bool,
	as_ball: bool,
	node_name: String,
	placeholder: Node2D,
	rest_yards: Vector3 = Vector3.ZERO,
	has_rest: bool = true
) -> IsoActorMirror:
	var mirror: IsoActorMirror = IsoActorMirrorScript.new()
	mirror.name = node_name
	mirror.z_index = 2 if as_ball else 1
	add_child(mirror)
	var use_rest := has_rest and placeholder != null
	mirror.setup(src, ground_anchored, as_ball, placeholder, rest_yards, use_rest)
	mirror.set_process(_enabled)
	return mirror


func _set_mirrors_process(enabled: bool) -> void:
	for m in [_player_golfer, _player_ball, _ratina_golfer, _ratina_ball]:
		if m != null and is_instance_valid(m):
			m.set_process(enabled)
			if not enabled:
				m.visible = false
