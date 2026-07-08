class_name Rattling
extends Node3D
## One forest-edge ball collector — walks out from the treeline to a claimed
## litter ball, picks it up, and carries it back for cash. Owned and driven
## per-frame by RattlingController.

signal finished(agent: Rattling)

enum State { WALKING_OUT, PICKING_UP, WALKING_BACK }

const RattlingSpriteFramesScript := preload("res://scripts/range/rattling_sprite_frames.gd")
const ARRIVE_EPSILON := 0.05
## Walking animation plays at 2x so the little feet look busy — this only
## scales the AnimatedSprite3D playback, not `_walk_speed` (actual movement).
const WALK_ANIM_SPEED_SCALE := 2.0

var _sprite: AnimatedSprite3D
var _state: State = State.WALKING_OUT
var _litter: Sprite3D = null
var _edge_x: float = 0.0
var _target_x: float = 0.0
var _z: float = 0.0
var _walk_speed: float = 3.2
var _fade_distance: float = 1.0
var _faded_out := false
var _ball_quality: int = 1
var _ball_yardage: float = 0.0
var _ball_golden: bool = false
var _ball_source: String = "player"
var _carrying_ball := false
var _retiring := false


func _ready() -> void:
	_sprite = AnimatedSprite3D.new()
	_sprite.sprite_frames = RattlingSpriteFramesScript.get_shared_frames()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = Balance.RATTLING_PIXEL_SIZE
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = false
	## Center-anchored (no foot offset) to match the calibrated
	## RattlingPlaceholder in range_view.tscn — Balance.RATTLING_GROUND_Y is
	## tuned for a centered sprite, not a feet-at-origin one.
	_sprite.offset = Vector2.ZERO
	_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	add_child(_sprite)


## Begin working a claimed litter ball. `walk_speed` in yards/sec (from
## GameState.rattling_stats). Caller owns claim bookkeeping.
func start(litter: Sprite3D, walk_speed: float, atmosphere_tint: Color) -> void:
	_litter = litter
	_walk_speed = maxf(walk_speed, 0.1)
	_fade_distance = maxf(_walk_speed * Balance.RATTLING_FADE_SEC, 0.2)
	_ball_quality = litter.get_meta("ball_quality", 1)
	_ball_yardage = litter.get_meta("ball_yardage", GameState.stats.base_yards)
	_ball_golden = litter.get_meta("ball_golden", false)
	_ball_source = litter.get_meta("ball_source", "player")

	var target := litter.global_position
	_z = target.z
	_target_x = target.x
	_edge_x = -Balance.FAIRWAY_HALF_WIDTH_YARDS if target.x < 0.0 else Balance.FAIRWAY_HALF_WIDTH_YARDS

	global_position = Vector3(_edge_x, Balance.RATTLING_GROUND_Y, _z)
	_sprite.modulate = Color(atmosphere_tint.r, atmosphere_tint.g, atmosphere_tint.b, 0.0)
	_state = State.WALKING_OUT
	_carrying_ball = false
	_faded_out = false
	_retiring = false
	_apply_facing(_target_x - _edge_x)
	_sprite.speed_scale = WALK_ANIM_SPEED_SCALE
	_sprite.play(&"walk")
	_fade_alpha_to(1.0, atmosphere_tint)


func apply_atmosphere_tint(tint: Color) -> void:
	if _faded_out:
		return
	_sprite.modulate = Color(tint.r, tint.g, tint.b, _sprite.modulate.a)


## Instance id of the litter ball this agent still has claimed, or -1 if it
## has already been picked up (freed) or there was none.
func claimed_litter_instance_id() -> int:
	return _litter.get_instance_id() if is_instance_valid(_litter) else -1


## True when toggling off should release the litter claim so another agent
## can fetch it later — outbound or mid-pickup before the ball is in hand.
func should_release_claim() -> bool:
	match _state:
		State.WALKING_OUT:
			return is_instance_valid(_litter)
		State.PICKING_UP:
			return is_instance_valid(_litter) and not _carrying_ball
		_:
			return false


## Toggled off — finish any in-hand return trek (credit the ball), otherwise
## walk back to the forest empty and leave unclaimed litter on the fairway.
func retire() -> void:
	if _retiring or _faded_out:
		return
	_retiring = true
	match _state:
		State.WALKING_BACK:
			pass
		State.WALKING_OUT:
			_litter = null
			_begin_walk_back(false)
		State.PICKING_UP:
			if _carrying_ball:
				_begin_walk_back(true)
			else:
				_litter = null
				_begin_walk_back(false)


func _process(delta: float) -> void:
	match _state:
		State.WALKING_OUT:
			_process_walking_out(delta)
		State.WALKING_BACK:
			_process_walking_back(delta)
		_:
			pass


func _process_walking_out(delta: float) -> void:
	if not is_instance_valid(_litter):
		_begin_walk_back(false)
		return
	var pos := global_position
	pos.x = move_toward(pos.x, _target_x, _walk_speed * delta)
	global_position = pos
	if absf(pos.x - _target_x) <= ARRIVE_EPSILON:
		_begin_pickup()


func _process_walking_back(delta: float) -> void:
	var pos := global_position
	pos.x = move_toward(pos.x, _edge_x, _walk_speed * delta)
	global_position = pos
	var remaining := absf(_edge_x - pos.x)
	if not _faded_out and remaining <= _fade_distance:
		_faded_out = true
		_fade_alpha_to(0.0, Color(_sprite.modulate.r, _sprite.modulate.g, _sprite.modulate.b))
	if remaining <= ARRIVE_EPSILON:
		_complete()


func _begin_pickup() -> void:
	if not is_instance_valid(_litter):
		_begin_walk_back(false)
		return
	_state = State.PICKING_UP
	_sprite.speed_scale = maxf(GameState.rattling_stats.rattling_pickup_speed_multiplier, 0.1)
	_sprite.play(&"pickup")


func _on_frame_changed() -> void:
	if _state != State.PICKING_UP or _sprite.animation != &"pickup":
		return
	if _sprite.frame >= RattlingSpriteFramesScript.PICKUP_BALL_FRAME and is_instance_valid(_litter):
		_litter.queue_free()
		_litter = null
		_carrying_ball = true


func _on_animation_finished() -> void:
	if _state == State.PICKING_UP and _sprite.animation == &"pickup":
		_begin_walk_back(_carrying_ball)


func _begin_walk_back(carrying: bool) -> void:
	_carrying_ball = carrying
	_state = State.WALKING_BACK
	_sprite.speed_scale = WALK_ANIM_SPEED_SCALE
	_apply_facing(_edge_x - global_position.x)
	_sprite.play(&"walk_ball" if carrying else &"walk")


func _complete() -> void:
	if _carrying_ball:
		GameState.credit_rattling_ball(_ball_quality, _ball_yardage, _ball_golden, _ball_source)
	finished.emit(self)


func _apply_facing(direction_x: float) -> void:
	if absf(direction_x) < 0.001:
		return
	_sprite.flip_h = direction_x < 0.0


func _fade_alpha_to(target_alpha: float, tint: Color) -> Tween:
	var tween := create_tween()
	tween.tween_method(
		func(a: float): _sprite.modulate = Color(tint.r, tint.g, tint.b, a),
		_sprite.modulate.a,
		target_alpha,
		Balance.RATTLING_FADE_SEC
	)
	return tween
