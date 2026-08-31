class_name RangeBird
extends AnimatedSprite3D
## One ambient bird: high approach, perch / peck, hop, climb-out takeoff.

signal cycle_finished
signal leave_requested
signal hop_requested

enum State { POOLED, APPROACH, PERCH, HOP, TAKEOFF, FLYOVER }

const PIXEL_SIZE := 0.022
## Feet sit on the fairway (y≈0). Sprite is foot-anchored via offset.
const PERCH_Y := 0.02
const FLY_SPEED := 9.0
const HOP_SPEED := 6.5
const TAKEOFF_SPEED := 11.0
const FLYOVER_SPEED := 12.0
## Approach uses a settle curve (not a mid-arc lift) so the path never dips under grass.
const HOP_LIFT := 1.4
const TAKEOFF_LIFT := 2.4
## Half of the 16px sheet — with centered sprites, +FOOT_OFFSET_PX puts feet at the node.
const FOOT_OFFSET_PX := 8.0

var perch: Vector3 = Vector3.ZERO
var species: int = SkyBirdFrames.Species.BLUE
var is_golden: bool = false

var _state: State = State.POOLED
var _frames_normal: SpriteFrames
var _frames_flipped: SpriteFrames
var _using_flipped := false
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _fly_t := 0.0
var _fly_duration := 1.0
var _fly_lift := 0.0
var _perch_left := 0.0
var _action_left := 0.0
var _atmosphere_tint := Color.WHITE
var _harvest_fog_t := 0.0
var _harvest_fog_color := Color(0.78, 0.82, 0.74, 1.0)
var _leave_emitted := false
var _reward_claimed := false
var _shimmer_t := 0.0
var _sparkles: Array[MeshInstance3D] = []

## Past this fog depth the bird is inside the mist bank — not clickable.
const FOG_CLICK_BLOCK_T := 0.22
const SPARKLE_COUNT := 3


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pixel_size = PIXEL_SIZE
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	double_sided = true
	transparent = true
	alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	## centered default − size/2 + this offset → bottom of the sheet at the node origin.
	offset = Vector2(0.0, FOOT_OFFSET_PX)
	visible = false
	set_process(false)
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	_ensure_sparkles()


func is_busy() -> bool:
	return _state != State.POOLED


func is_perched() -> bool:
	return _state == State.PERCH


func is_flyover() -> bool:
	return _state == State.FLYOVER


## Approach / perch / hop / takeoff — not sky pack crossings.
func is_perch_lifecycle() -> bool:
	return is_busy() and not is_flyover()


func is_in_harvest_fog() -> bool:
	return _harvest_fog_t >= FOG_CLICK_BLOCK_T


## Harvest click only when perched and clear of the mist bank.
func is_clickable() -> bool:
	return is_perched() and visible and not is_in_harvest_fog()


func apply_atmosphere_tint(tint: Color) -> void:
	_atmosphere_tint = tint
	_refresh_modulate()


## 0 = clear, 1 = fully inside harvest mist bank. `fog_color` matches the fairway wash.
func apply_harvest_fog(t: float, fog_color: Color = Color(0.78, 0.82, 0.74, 1.0)) -> void:
	_harvest_fog_t = clampf(t, 0.0, 1.0)
	_harvest_fog_color = fog_color
	_refresh_modulate()


func clear_harvest_fog() -> void:
	if _harvest_fog_t <= 0.0:
		return
	_harvest_fog_t = 0.0
	_refresh_modulate()


func _refresh_modulate() -> void:
	var base := _atmosphere_tint
	if is_golden:
		## Gold frames already carry the palette; pulse warmth for a soft shimmer.
		var pulse := 0.5 + 0.5 * sin(_shimmer_t * Balance.GOLDEN_BIRD_SHIMMER_HZ * TAU)
		var shimmer := Balance.GOLDEN_BIRD_TINT.lerp(Balance.GOLDEN_BIRD_SHIMMER_HI, pulse)
		base = shimmer * _atmosphere_tint
	if _harvest_fog_t <= 0.001:
		## Crisp pixel cut when clear of mist.
		alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		modulate = Color(base.r, base.g, base.b, 1.0)
		return

	## Soft blend needs real alpha — opaque prepass would only darken the sprite.
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	var grey := (base.r + base.g + base.b) * (1.0 / 3.0)
	var flat := Color(grey, grey, grey).lerp(base, 0.22)
	## Match fairway mist: wash hard toward fog_color so the bird sits *in* the bank.
	var misted := flat.lerp(_harvest_fog_color, 0.78)
	## Ease alpha down quickly so deep fog dissolves into haze, not a dark silhouette.
	var fog_ease := _harvest_fog_t * _harvest_fog_t
	var alpha := lerpf(1.0, 0.06, fog_ease)
	modulate = Color(misted.r, misted.g, misted.b, alpha)


func start_cycle(
	from: Vector3,
	perch_pos: Vector3,
	next_species: int,
	perch_sec: float,
	golden: bool = false
) -> void:
	is_golden = golden
	## Rare gold birds always use the gold palette, not a multiply tint on blue/rust.
	species = SkyBirdFrames.Species.GOLDEN if golden else next_species
	_reward_claimed = false
	_shimmer_t = randf() * TAU
	perch = perch_pos
	perch.y = PERCH_Y
	_frames_normal = SkyBirdFrames.make_frames(species, false)
	_frames_flipped = SkyBirdFrames.make_frames(species, true)
	## Invalidate facing cache so the new species textures actually bind
	## (pooled birds often reuse the same facing and would keep the old color).
	_using_flipped = not _using_flipped
	_from = from
	_to = perch
	_begin_flight(State.APPROACH, from, perch, FLY_SPEED, 0.0)
	_perch_left = perch_sec
	_leave_emitted = false
	visible = true
	_set_sparkles_active(golden)
	_refresh_modulate()


## High sky crossing — never perches, never golden, never harvest-clickable.
func start_flyover(from: Vector3, to: Vector3, next_species: int) -> void:
	is_golden = false
	species = next_species
	_reward_claimed = false
	perch = Vector3.ZERO
	_frames_normal = SkyBirdFrames.make_frames(species, false)
	_frames_flipped = SkyBirdFrames.make_frames(species, true)
	_using_flipped = not _using_flipped
	_leave_emitted = false
	_set_sparkles_active(false)
	visible = true
	_refresh_modulate()
	_begin_flight(State.FLYOVER, from, to, FLYOVER_SPEED, 0.0)


## Returns cash awarded (0 if not golden / already claimed).
func claim_golden_reward() -> float:
	if not is_golden or _reward_claimed:
		return 0.0
	_reward_claimed = true
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.stats != null:
		return Economy.resolve_golden_bird_payout(gs.stats)
	return Balance.GOLDEN_BIRD_BASE_REWARD


func hop_to(next_perch: Vector3) -> void:
	if _state != State.PERCH:
		return
	perch = next_perch
	perch.y = PERCH_Y
	_begin_flight(State.HOP, position, perch, HOP_SPEED, HOP_LIFT)


func takeoff_to(exit_pos: Vector3) -> void:
	if _state == State.POOLED or _state == State.TAKEOFF or _state == State.FLYOVER:
		return
	_begin_flight(State.TAKEOFF, position, exit_pos, TAKEOFF_SPEED, TAKEOFF_LIFT)


func flush_to(exit_pos: Vector3) -> void:
	if _state == State.POOLED or _state == State.TAKEOFF or _state == State.FLYOVER:
		return
	_perch_left = 0.0
	_begin_flight(State.TAKEOFF, position, exit_pos, TAKEOFF_SPEED * 1.15, TAKEOFF_LIFT + 0.8)


## True when the sprite is mirrored (beak toward screen-right / +camera.right).
func faces_screen_right() -> bool:
	return _using_flipped


func _begin_flight(next: State, from: Vector3, to: Vector3, speed: float, lift: float) -> void:
	_state = next
	_from = from
	_to = to
	if next == State.FLYOVER:
		## Keep full sky altitude — do not pull endpoints down to grass.
		pass
	else:
		_to.y = maxf(_to.y, PERCH_Y)
		if next == State.APPROACH or next == State.HOP:
			_from.y = maxf(_from.y, PERCH_Y)
	_fly_lift = lift
	var dist := from.distance_to(to)
	_fly_duration = maxf(dist / maxf(speed, 0.1), 0.45)
	_fly_t = 0.0
	position = _from
	## Always face the whole leg up front so the beak leads the path.
	_face_toward(_to - _from, true)
	_play_anim(&"fly")
	set_process(true)


func _process(delta: float) -> void:
	if is_golden:
		_tick_golden_fx(delta)
	match _state:
		State.APPROACH, State.HOP, State.TAKEOFF, State.FLYOVER:
			_tick_flight(delta)
		State.PERCH:
			_tick_perch(delta)
		_:
			set_process(false)


func _tick_golden_fx(delta: float) -> void:
	_shimmer_t += delta
	_refresh_modulate()
	if _sparkles.is_empty() or _harvest_fog_t > FOG_CLICK_BLOCK_T:
		_hide_sparkles()
		return
	for i in _sparkles.size():
		var spark: MeshInstance3D = _sparkles[i]
		var phase := _shimmer_t * (2.4 + float(i) * 0.85) + float(i) * 1.9
		var on := sin(phase) > 0.42
		spark.visible = on
		if not on:
			continue
		## Tiny glints around the body — billboard quads, foot-anchored bird.
		spark.position = Vector3(
			sin(phase * 0.55 + float(i)) * 0.14,
			0.22 + cos(phase * 0.35 + float(i) * 0.7) * 0.1,
			0.04
		)
		var mat := spark.material_override as StandardMaterial3D
		if mat != null:
			var flash := 0.55 + 0.45 * sin(phase * 1.6)
			mat.albedo_color = Color(
				Balance.GOLDEN_SPARKLE_COLOR.r,
				Balance.GOLDEN_SPARKLE_COLOR.g,
				Balance.GOLDEN_SPARKLE_COLOR.b,
				flash
			)


func _ensure_sparkles() -> void:
	if not _sparkles.is_empty():
		return
	for i in SPARKLE_COUNT:
		var spark := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		spark.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Balance.GOLDEN_SPARKLE_COLOR
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		spark.material_override = mat
		spark.visible = false
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		_sparkles.append(spark)


func _set_sparkles_active(active: bool) -> void:
	_ensure_sparkles()
	if not active:
		_hide_sparkles()


func _hide_sparkles() -> void:
	for spark in _sparkles:
		spark.visible = false


func _tick_flight(delta: float) -> void:
	_fly_t += delta / _fly_duration
	var t := clampf(_fly_t, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var pos := _from.lerp(_to, eased)
	if _state == State.APPROACH:
		## Ease altitude down onto the grass — stay above PERCH_Y the whole way.
		pos.y = lerpf(_from.y, _to.y, eased * eased)
	elif _state == State.FLYOVER:
		## Straight sky path with a tiny breathe so the pack doesn’t look locked.
		pos.y += sin(t * PI) * 0.35
	else:
		pos.y += sin(t * PI) * _fly_lift
	if _state != State.TAKEOFF and _state != State.FLYOVER:
		pos.y = maxf(pos.y, PERCH_Y)
	var vel := pos - position
	position = pos
	if vel.length_squared() > 0.0001:
		_face_toward(vel)
	if t < 1.0:
		return
	if _state == State.TAKEOFF or _state == State.FLYOVER:
		_pool()
		cycle_finished.emit()
		return
	_enter_perch()


func _enter_perch() -> void:
	_state = State.PERCH
	position = perch
	_play_anim(&"idle")
	_action_left = randf_range(1.4, 3.2)


func _tick_perch(delta: float) -> void:
	_perch_left -= delta
	if _perch_left <= 0.0:
		if not _leave_emitted:
			_leave_emitted = true
			leave_requested.emit()
		return
	_action_left -= delta
	if _action_left > 0.0:
		return
	if animation == &"eat":
		return
	if randf() < 0.18:
		hop_requested.emit()
		_action_left = 2.0
		return
	if randf() < 0.45:
		_play_anim(&"eat")
		_action_left = 1.2
	else:
		_play_anim(&"idle")
		_action_left = randf_range(1.8, 4.0)


func _on_animation_finished() -> void:
	if _state == State.PERCH and animation == &"eat":
		_play_anim(&"idle")


func _face_toward(dir: Vector3, force := false) -> void:
	## Face along camera-right so the beak matches on-screen travel (not raw world X).
	## Atlas faces left (= screen-left / -camera.right) when unflipped.
	var lateral := dir.dot(_view_right())
	if not force and absf(lateral) < 0.02:
		return
	_apply_facing(lateral > 0.0, force)


func _view_right() -> Vector3:
	var parent := get_parent()
	if parent != null and parent.has_method("get_view_camera"):
		var cam: Camera3D = parent.get_view_camera()
		if cam != null and cam.is_inside_tree():
			return cam.global_transform.basis.x.normalized()
	return Vector3.RIGHT


func _apply_facing(want_flipped: bool, force := false) -> void:
	if not force and want_flipped == _using_flipped and sprite_frames != null:
		return
	var wing_phase := frame
	var anim := animation if sprite_frames != null else &"fly"
	_using_flipped = want_flipped
	sprite_frames = _frames_flipped if want_flipped else _frames_normal
	if sprite_frames == null:
		return
	if not sprite_frames.has_animation(anim):
		anim = &"fly"
	var count := sprite_frames.get_frame_count(anim)
	animation = anim
	if count > 0:
		frame = wing_phase % count
	if not Engine.is_editor_hint() and anim == &"fly":
		play(anim)


func _play_anim(anim: StringName) -> void:
	if sprite_frames == null:
		return
	animation = anim
	frame = 0
	if not Engine.is_editor_hint():
		play(anim)


func _pool() -> void:
	_state = State.POOLED
	is_golden = false
	_reward_claimed = false
	_hide_sparkles()
	visible = false
	set_process(false)
	stop()
