extends Control
## Fullscreen prestige ritual: celebrate cheese → Prestige tree shop → return to range.

signal ritual_finished

const CHEESE_ICON := preload("res://assets/ui/cheese-currency-icon.png")
const CurrencyReelScript := preload("res://scripts/ui/currency_reel.gd")
const ParallaxSkyScript := preload("res://scripts/ui/parallax_sky_background.gd")

const PANEL_BG := Color(0.06, 0.09, 0.05, 0.82)

const SPAWN_STAGGER_SEC := 0.028
const FLY_DURATION_SEC := 0.55
const SFX_EVERY_N := 3
const CHEESE_SPRITE_SIZE := Vector2(18, 18)

enum Phase { IDLE, CELEBRATE, SHOP }

var _phase: Phase = Phase.IDLE
var _cheese_before: int = 0
var _gained: int = 0
var _arrived: int = 0
var _spawn_index: int = 0
var _spawn_timer: float = 0.0
var _spawning := false
var _sfx_hits: int = 0

var _sky: Control
var _dim: ColorRect
var _celebrate_root: Control
var _title_label: Label
var _gained_label: Label
var _prestige_num_label: Label
var _counter_row: HBoxContainer
var _cheese_icon: TextureRect
var _counter_label: Label
var _advance_button: Button
var _sprite_layer: Control
var _reel: RefCounted
var _counter_anchor: Control


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	set_process(false)


func is_active() -> bool:
	return _phase != Phase.IDLE


func is_celebrating() -> bool:
	return _phase == Phase.CELEBRATE


func begin_ritual(cheese_before: int, gained: int) -> void:
	_cheese_before = cheese_before
	_gained = maxi(gained, 0)
	_arrived = 0
	_spawn_index = 0
	_spawn_timer = 0.0
	_spawning = _gained > 0
	_sfx_hits = 0
	_phase = Phase.CELEBRATE
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()
	_celebrate_root.visible = true
	_title_label.text = "PRESTIGE!"
	_prestige_num_label.text = "Prestige #%d" % GameState.prestige_count
	_gained_label.text = "+%d cheese" % _gained
	_advance_button.text = "Advance"
	_advance_button.visible = true
	_advance_button.disabled = false
	if _reel != null:
		_reel.snap(float(_cheese_before))
	_clear_sprites()
	SfxManager.play_prestige_fanfare()
	set_process(_spawning)
	EventBus.ui_panel_toggled.emit("prestige_flow", true)


func _build_ui() -> void:
	if _celebrate_root != null:
		return

	_sky = ParallaxSkyScript.new()
	_sky.name = "Sky"
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.02, 0.03, 0.02, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_sprite_layer = Control.new()
	_sprite_layer.name = "SpriteLayer"
	_sprite_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite_layer)

	_celebrate_root = Control.new()
	_celebrate_root.name = "Celebrate"
	_celebrate_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_celebrate_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_celebrate_root)

	var top_bar := PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 28.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_header_bar(top_bar)
	_celebrate_root.add_child(top_bar)

	_counter_row = HBoxContainer.new()
	_counter_row.alignment = BoxContainer.ALIGNMENT_END
	_counter_row.add_theme_constant_override(&"separation", 6)
	_counter_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override(&"margin_left", 8)
	top_margin.add_theme_constant_override(&"margin_right", 10)
	top_margin.add_theme_constant_override(&"margin_top", 4)
	top_margin.add_theme_constant_override(&"margin_bottom", 4)
	top_bar.add_child(top_margin)
	top_margin.add_child(_counter_row)

	_prestige_num_label = Label.new()
	_prestige_num_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prestige_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_prestige_num_label.add_theme_color_override(&"font_color", UiTheme.COLOR_TITLE_ON_DARK)
	PixelFont.apply_label(_prestige_num_label, 8)
	_counter_row.add_child(_prestige_num_label)

	_cheese_icon = TextureRect.new()
	_cheese_icon.texture = CHEESE_ICON
	_cheese_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cheese_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cheese_icon.custom_minimum_size = Vector2(16, 16)
	_cheese_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_counter_row.add_child(_cheese_icon)

	_counter_anchor = Control.new()
	_counter_anchor.custom_minimum_size = Vector2(48, 16)
	_counter_row.add_child(_counter_anchor)

	_counter_label = Label.new()
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter_label.add_theme_color_override(&"font_color", UiTheme.COLOR_TITLE_ON_DARK)
	PixelFont.apply_label(_counter_label, 10)
	_counter_anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_counter_anchor.add_child(_counter_label)
	_counter_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_reel = CurrencyReelScript.new()
	_reel.setup(self, _counter_label, func(v: float) -> String: return str(int(round(v))), 0.0, "")

	var center := VBoxContainer.new()
	center.name = "CenterCopy"
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override(&"separation", 10)
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.5
	center.anchor_top = 0.42
	center.anchor_right = 0.5
	center.anchor_bottom = 0.42
	center.offset_left = -140.0
	center.offset_right = 140.0
	center.offset_top = -40.0
	center.offset_bottom = 40.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_celebrate_root.add_child(center)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override(&"font_color", UiTheme.COLOR_TITLE_ON_DARK)
	PixelFont.apply_label(_title_label, 16)
	center.add_child(_title_label)

	_gained_label = Label.new()
	_gained_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gained_label.add_theme_color_override(&"font_color", UiTheme.COLOR_LABEL_ON_DARK)
	PixelFont.apply_label(_gained_label, 10)
	center.add_child(_gained_label)

	_advance_button = Button.new()
	_advance_button.name = "AdvanceButton"
	_advance_button.text = "Advance"
	_advance_button.focus_mode = Control.FOCUS_NONE
	_advance_button.custom_minimum_size = Vector2(88, 22)
	_advance_button.anchor_left = 1.0
	_advance_button.anchor_top = 1.0
	_advance_button.anchor_right = 1.0
	_advance_button.anchor_bottom = 1.0
	_advance_button.offset_left = -100.0
	_advance_button.offset_top = -32.0
	_advance_button.offset_right = -12.0
	_advance_button.offset_bottom = -10.0
	_advance_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_advance_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_style_advance_button()
	_advance_button.pressed.connect(_on_advance_pressed)
	add_child(_advance_button)


func _style_advance_button() -> void:
	UiTheme.apply_primary_button(
		_advance_button, UiTheme.MARGIN_BUTTON_COMPACT_H + 2, UiTheme.MARGIN_BUTTON_COMPACT_V + 2
	)
	_advance_button.add_theme_color_override(&"font_color", UiTheme.COLOR_TITLE_ON_DARK)
	_advance_button.add_theme_color_override(&"font_hover_color", UiTheme.COLOR_TITLE_ON_DARK)
	_advance_button.add_theme_color_override(&"font_pressed_color", UiTheme.COLOR_TITLE_ON_DARK)


func _process(delta: float) -> void:
	if _phase != Phase.CELEBRATE or not _spawning:
		set_process(false)
		return
	_spawn_timer -= delta
	while _spawn_timer <= 0.0 and _spawn_index < _gained:
		_launch_sprite(_spawn_index)
		_spawn_index += 1
		_spawn_timer += SPAWN_STAGGER_SEC
	if _spawn_index >= _gained:
		_spawning = false
		set_process(false)


func _launch_sprite(_index: int) -> void:
	var sprite := TextureRect.new()
	sprite.texture = CHEESE_ICON
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = CHEESE_SPRITE_SIZE
	sprite.size = CHEESE_SPRITE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite_layer.add_child(sprite)

	var vp := get_viewport_rect().size
	var start := Vector2(
		vp.x * 0.5 + randf_range(-90.0, 90.0),
		vp.y * 0.55 + randf_range(-40.0, 50.0)
	)
	sprite.global_position = start
	sprite.pivot_offset = CHEESE_SPRITE_SIZE * 0.5
	sprite.rotation = randf_range(-0.4, 0.4)
	sprite.scale = Vector2(0.6, 0.6)

	var target := _counter_target_global()
	var mid := (start + target) * 0.5 + Vector2(randf_range(-40.0, 40.0), randf_range(-80.0, -20.0))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		_fly_sprite_step.bind(sprite, start, mid, target),
		0.0,
		1.0,
		FLY_DURATION_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(1.05, 1.05), FLY_DURATION_SEC * 0.7)
	tween.tween_property(sprite, "rotation", 0.0, FLY_DURATION_SEC)
	tween.chain().tween_callback(_on_sprite_arrived.bind(sprite))


func _fly_sprite_step(t: float, sprite: Variant, start: Vector2, mid: Vector2, target: Vector2) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var node := sprite as Control
	if node == null:
		return
	var a := start.lerp(mid, t)
	var b := mid.lerp(target, t)
	node.global_position = a.lerp(b, t)


func _counter_target_global() -> Vector2:
	if _cheese_icon != null and is_instance_valid(_cheese_icon):
		return _cheese_icon.get_global_rect().get_center()
	if _counter_label != null:
		return _counter_label.get_global_rect().get_center()
	return get_viewport_rect().size * Vector2(0.85, 0.06)


func _on_sprite_arrived(sprite: Variant) -> void:
	if sprite != null and is_instance_valid(sprite):
		(sprite as Node).queue_free()
	_arrived += 1
	var display_to: int = _cheese_before + _arrived
	if _reel != null:
		_reel.set_target(float(display_to))
	_sfx_hits += 1
	if _sfx_hits == 1 or _sfx_hits % SFX_EVERY_N == 0 or _arrived >= _gained:
		SfxManager.play_pickup_plink(1)
	if _arrived >= _gained and _reel != null:
		_reel.set_target(float(_cheese_before + _gained))


func _clear_sprites() -> void:
	if _sprite_layer == null:
		return
	for child in _sprite_layer.get_children():
		child.queue_free()


func _on_advance_pressed() -> void:
	match _phase:
		Phase.CELEBRATE:
			_enter_shop_phase()
		Phase.SHOP:
			_finish_ritual()
		_:
			pass


func _enter_shop_phase() -> void:
	_phase = Phase.SHOP
	_spawning = false
	set_process(false)
	_clear_sprites()
	if _reel != null:
		_reel.snap(float(GameState.cheese))
	_celebrate_root.visible = false
	_dim.visible = false
	_sky.visible = false
	# Pass clicks through to ritual upgrade panel; keep Advance clickable.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_advance_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_advance_button.text = "Advance"
	var panel := _upgrade_panel()
	if panel != null and panel.has_method("open_ritual_shop"):
		panel.open_ritual_shop()


func _finish_ritual() -> void:
	_phase = Phase.IDLE
	_spawning = false
	set_process(false)
	_clear_sprites()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_celebrate_root.visible = true
	_dim.visible = true
	_sky.visible = true
	var panel := _upgrade_panel()
	if panel != null and panel.has_method("close_ritual_shop"):
		panel.close_ritual_shop()
	_restore_range_after_prestige()
	EventBus.ui_panel_toggled.emit("prestige_flow", false)
	ritual_finished.emit()


func _upgrade_panel() -> Node:
	return get_parent().get_node_or_null("UpgradePanel")


func _restore_range_after_prestige() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var range_view := main.get_node_or_null("RangeView")
	if range_view != null and range_view.has_method("prepare_after_prestige"):
		range_view.prepare_after_prestige()
