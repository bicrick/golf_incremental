class_name IsoActorLayer
extends Node
## Owns IsoActorMirror instances for bay golfers and tee balls.
## Lazily resolves Ratina sprites (bay is spawned at runtime on RangeView).

const IsoActorMirrorScript := preload("res://scripts/iso/iso_actor_mirror.gd")

var _objects: Node2D
var _range_view: Node3D
var _player_golfer: IsoActorMirror
var _player_ball: IsoActorMirror
var _ratina_golfer: IsoActorMirror
var _ratina_ball: IsoActorMirror
var _enabled := false


func setup(objects: Node2D, range_view: Node3D) -> void:
	_objects = objects
	_range_view = range_view
	_ensure_player_mirrors()
	_try_bind_ratina()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process(enabled)
	_set_mirrors_process(enabled)
	if enabled:
		_ensure_player_mirrors()
		_try_bind_ratina()


func get_player_golfer_mirror() -> IsoActorMirror:
	return _player_golfer


func get_ratina_golfer_mirror() -> IsoActorMirror:
	return _ratina_golfer


func _process(_delta: float) -> void:
	if not _enabled:
		return
	## Ratina bay may appear after hire / first unlock mid-session.
	if _ratina_golfer == null or not is_instance_valid(_ratina_golfer.source):
		_try_bind_ratina()


func _ensure_player_mirrors() -> void:
	if _range_view == null or _objects == null:
		return
	if _player_golfer == null or not is_instance_valid(_player_golfer):
		var golfer: AnimatedSprite3D = null
		if _range_view.has_method(&"get_golfer"):
			golfer = _range_view.get_golfer()
		if golfer != null:
			_player_golfer = _make_mirror(golfer, true, false, "PlayerGolferMirror")
	if _player_ball == null or not is_instance_valid(_player_ball):
		var ball: AnimatedSprite3D = null
		if _range_view.has_method(&"get_ball"):
			ball = _range_view.get_ball()
		if ball != null:
			_player_ball = _make_mirror(ball, true, true, "PlayerBallMirror")


func _try_bind_ratina() -> void:
	if _range_view == null or _objects == null:
		return
	var ratina_sprite: AnimatedSprite3D = _range_view.get("ratina_sprite") as AnimatedSprite3D
	var ratina_ball: AnimatedSprite3D = _range_view.get("ratina_ball_sprite") as AnimatedSprite3D
	if ratina_sprite != null and (_ratina_golfer == null or not is_instance_valid(_ratina_golfer)):
		_ratina_golfer = _make_mirror(ratina_sprite, true, false, "RatinaGolferMirror")
	elif _ratina_golfer != null and is_instance_valid(_ratina_golfer) and ratina_sprite != null:
		_ratina_golfer.source = ratina_sprite
	if ratina_ball != null and (_ratina_ball == null or not is_instance_valid(_ratina_ball)):
		_ratina_ball = _make_mirror(ratina_ball, true, true, "RatinaBallMirror")
	elif _ratina_ball != null and is_instance_valid(_ratina_ball) and ratina_ball != null:
		_ratina_ball.source = ratina_ball


func _make_mirror(
	src: SpriteBase3D,
	ground_anchored: bool,
	as_ball: bool,
	node_name: String
) -> IsoActorMirror:
	var mirror: IsoActorMirror = IsoActorMirrorScript.new()
	mirror.name = node_name
	mirror.z_index = 2 if as_ball else 1
	_objects.add_child(mirror)
	mirror.setup(src, ground_anchored, as_ball)
	mirror.set_process(_enabled)
	return mirror


func _set_mirrors_process(enabled: bool) -> void:
	for m in [_player_golfer, _player_ball, _ratina_golfer, _ratina_ball]:
		if m != null and is_instance_valid(m):
			m.set_process(enabled)
			if not enabled:
				m.visible = false
