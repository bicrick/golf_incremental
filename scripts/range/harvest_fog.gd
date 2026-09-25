class_name HarvestFog
extends RefCounted
## Harvest-only mist bank past lifetime max carry. Drives Ground shader uniforms,
## soft-fades yardage markers, and a right-edge max-carry distance label.

const MARKER_MIN_ALPHA := 0.12
## Just outside the right fairway edge / yardage signs — reads against the sky void.
const MAX_CARRY_LABEL_X := 19.35
const MAX_CARRY_LABEL_Y := 0.22
## Small world glyphs — whisper next to the 50–300 signs, not a HUD stamp.
const MAX_CARRY_LABEL_PIXEL_SIZE := 0.012
const MAX_CARRY_LABEL_FONT_SIZE := 14
const MAX_CARRY_LABEL_OUTLINE := 2
const MAX_CARRY_LABEL_FILL := Color(0.92, 0.90, 0.82, 0.72)
const MAX_CARRY_LABEL_OUTLINE_COLOR := Color(0.18, 0.28, 0.16, 0.45)

var _ground: MeshInstance3D
var _yardage_markers: Node3D
var _view_mode: ViewModeController
var _tee_z: float = 0.0
var _fog_color: Color = Color(0.78, 0.82, 0.74, 1.0)
var _atmosphere_tint: Color = Color.WHITE
var _max_carry_label: Label3D
var _bird_director: RangeBirdDirector

var _want_fog: bool = false
var _fog_amount: float = 0.0
var _displayed_reveal: float = Balance.HARVEST_FOG_MIN_REVEAL_YARDS
var _target_reveal: float = Balance.HARVEST_FOG_MIN_REVEAL_YARDS
var _displayed_carry: float = 0.0


func setup(
	ground: MeshInstance3D,
	yardage_markers: Node3D,
	view_mode: ViewModeController,
	tee_z: float,
	label_parent: Node3D = null,
	bird_director: RangeBirdDirector = null
) -> void:
	_ground = ground
	_yardage_markers = yardage_markers
	_view_mode = view_mode
	_tee_z = tee_z
	_bird_director = bird_director
	_target_reveal = GameState.revealed_yards()
	_displayed_reveal = _target_reveal
	_displayed_carry = GameState.max_carry_yards()
	if not EventBus.max_carry_changed.is_connected(_on_max_carry_changed):
		EventBus.max_carry_changed.connect(_on_max_carry_changed)
	_ensure_max_carry_label(label_parent if label_parent else yardage_markers)
	_push_uniforms()
	_apply_marker_modulates()
	_apply_bird_modulates()
	_update_max_carry_label()


func set_tee_z(tee_z: float) -> void:
	_tee_z = tee_z
	_push_uniforms()
	_update_max_carry_label()


func set_fog_color(color: Color) -> void:
	_fog_color = color
	_push_uniforms()


func set_atmosphere_tint(tint: Color) -> void:
	_atmosphere_tint = tint
	_apply_marker_modulates()
	_apply_bird_modulates()
	_update_max_carry_label()


func on_view_mode_changed(mode: ViewModeController.Mode) -> void:
	# Fog is already on the fairway for harvest — never fade green→mist on enter.
	# Arm as soon as we leave strike while the phase is harvest (covers dissolve).
	var show_fog := (
		GameState.is_harvest_phase()
		and mode != ViewModeController.Mode.STRIKE
	)
	_want_fog = show_fog
	if show_fog:
		_fog_amount = 1.0
		_target_reveal = GameState.revealed_yards()
	_push_uniforms()
	_apply_marker_modulates()
	_apply_bird_modulates()
	_update_max_carry_label()


func update(delta: float) -> void:
	# Enter: snapped on. Exit: soft fade under the strike dissolve.
	if _want_fog:
		_fog_amount = 1.0
	else:
		var fade_sec := maxf(Balance.HARVEST_FOG_FADE_SEC, 0.001)
		_fog_amount = maxf(_fog_amount - delta / fade_sec, 0.0)

	_target_reveal = GameState.revealed_yards()
	var target_carry := GameState.max_carry_yards()
	# Recede only while fog is visible — personal-best reward on harvest enter.
	if _fog_amount > 0.01:
		var lerp_sec := maxf(Balance.HARVEST_FOG_REVEAL_LERP_SEC, 0.001)
		var t := clampf(delta / lerp_sec, 0.0, 1.0)
		_displayed_reveal = lerpf(_displayed_reveal, _target_reveal, t)
		_displayed_carry = lerpf(_displayed_carry, target_carry, t)
	elif not _want_fog and _fog_amount <= 0.001:
		_displayed_reveal = _target_reveal
		_displayed_carry = target_carry

	_push_uniforms()
	_apply_marker_modulates()
	_apply_bird_modulates()
	_update_max_carry_label()


func fog_amount() -> float:
	return _fog_amount


func displayed_reveal_yards() -> float:
	return _displayed_reveal


func tee_z() -> float:
	return _tee_z


func fog_color() -> Color:
	return _fog_color


func atmosphere_tint() -> Color:
	return _atmosphere_tint


## 0 = clear, 1 = deep in the mist bank, for a point this many yards down range.
func fog_depth_t(yards_from_tee: float) -> float:
	return _fog_depth_t(yards_from_tee)


func max_carry_label() -> Label3D:
	return _max_carry_label


func _on_max_carry_changed(_yards: float) -> void:
	_target_reveal = GameState.revealed_yards()
	_update_max_carry_label()


func _ensure_max_carry_label(parent: Node3D) -> void:
	if parent == null:
		return
	if _max_carry_label != null and is_instance_valid(_max_carry_label):
		return
	var existing := parent.get_node_or_null("MaxCarryLabel") as Label3D
	if existing:
		_max_carry_label = existing
		return
	var label := Label3D.new()
	label.name = &"MaxCarryLabel"
	# Y-billboard keeps it planted on the fairway edge instead of screen-facing HUD.
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.shaded = false
	label.double_sided = true
	label.no_depth_test = false
	label.pixel_size = MAX_CARRY_LABEL_PIXEL_SIZE
	label.font_size = MAX_CARRY_LABEL_FONT_SIZE
	label.font = PixelFont.font_for_size(MAX_CARRY_LABEL_FONT_SIZE)
	label.outline_size = MAX_CARRY_LABEL_OUTLINE
	label.outline_modulate = MAX_CARRY_LABEL_OUTLINE_COLOR
	label.modulate = MAX_CARRY_LABEL_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	parent.add_child(label)
	_max_carry_label = label


func _update_max_carry_label() -> void:
	if _max_carry_label == null or not is_instance_valid(_max_carry_label):
		return
	var carry := GameState.max_carry_yards()
	var show := _want_fog and carry > 0.5
	_max_carry_label.visible = show
	if not show:
		return
	var yards_i := maxi(1, int(round(_displayed_carry if _displayed_carry > 0.5 else carry)))
	_max_carry_label.text = "%d yd" % yards_i
	# Soft atmosphere wash — keep fill quiet, never full cream punch.
	var wash := _atmosphere_tint
	wash.a = MAX_CARRY_LABEL_FILL.a
	_max_carry_label.modulate = MAX_CARRY_LABEL_FILL.lerp(wash, 0.35)
	_max_carry_label.outline_modulate = MAX_CARRY_LABEL_OUTLINE_COLOR
	_max_carry_label.position = Vector3(
		MAX_CARRY_LABEL_X,
		MAX_CARRY_LABEL_Y,
		_tee_z - _displayed_carry
	)


func _push_uniforms() -> void:
	if _ground == null:
		return
	FairwayGrassTiles3D.apply_fog_uniforms(
		_ground,
		_fog_amount,
		_tee_z,
		_displayed_reveal,
		Balance.HARVEST_FOG_FALLOFF_YARDS,
		_fog_color
	)


func _apply_marker_modulates() -> void:
	if _yardage_markers == null:
		return
	var falloff := maxf(Balance.HARVEST_FOG_FALLOFF_YARDS, 0.001)
	for child in _yardage_markers.get_children():
		if not (child is SpriteBase3D):
			continue
		var sprite := child as SpriteBase3D
		var yards_from_tee := -(sprite.global_position.z - _tee_z)
		var t := _fog_depth_t(yards_from_tee)
		var fog_alpha := lerpf(1.0, MARKER_MIN_ALPHA, t)
		var tint := _atmosphere_tint
		tint.a = fog_alpha
		# Soft cool cast into the bank without hiding the sign entirely.
		if t > 0.01:
			var cool := Color(0.72, 0.78, 0.82, fog_alpha)
			tint = tint.lerp(cool, t * 0.45)
			tint.a = fog_alpha
		sprite.modulate = tint


func _apply_bird_modulates() -> void:
	if _bird_director == null:
		return
	for bird in _bird_director.birds():
		if bird == null or not is_instance_valid(bird):
			continue
		if not bird.is_busy() or _fog_amount <= 0.001:
			bird.clear_harvest_fog()
			continue
		var yards_from_tee := -(bird.global_position.z - _tee_z)
		bird.apply_harvest_fog(_fog_depth_t(yards_from_tee), _fog_color)


func _fog_depth_t(yards_from_tee: float) -> float:
	var falloff := maxf(Balance.HARVEST_FOG_FALLOFF_YARDS, 0.001)
	return smoothstep(
		_displayed_reveal,
		_displayed_reveal + falloff,
		yards_from_tee
	) * _fog_amount
