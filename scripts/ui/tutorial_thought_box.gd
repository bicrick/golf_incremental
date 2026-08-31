extends Control
## Pokémon-style dialogue box — typewriter text, blips, continue caret.

signal dismissed
## Emitted when the player tries to advance while waiting for a gameplay event
## (advance_on_input false, typing finished). Controller may show a nudge tip.
signal nudge_requested

const CHAR_INTERVAL_SEC := 0.032
const BLIP_EVERY_N_CHARS := 1
const SLIDE_PX := 10.0
const SLIDE_SEC := 0.12
const CARET_BLINK_SEC := 0.35
const BOX_WIDTH := 360.0
const BOX_MIN_HEIGHT := 78.0
const PORTRAIT_SIZE := 44
const FONT_SIZE := 7
## Speaking sheet: 156×156, 52px cells, 3×3 grid, 7 occupied (row-major; skip 2 empty).
const SPEAKING_PATH := "res://assets/sprites/range_rat/rat-speaking-sheet.png"
const SPEAKING_FRAME := 52
const SPEAKING_COLS := 3
const SPEAKING_FRAMES := 7
const SPEAKING_FPS := 8.0
const FOOTER_HEIGHT := 12.0


var _panel: PanelContainer
var _portrait: TextureRect
var _text_col: VBoxContainer
var _body: Label
var _preview_host: HBoxContainer
var _footer: HBoxContainer
var _caret: Label
var _hint_row: HBoxContainer
var _hint_key: Control
var _hint_label: Label
var _full_text: String = ""
var _typing := false
var _open := false
var _char_index := 0
var _char_timer := 0.0
var _caret_timer := 0.0
var _caret_visible := true
var _rest_y := 0.0
var _slide_tween: Tween
var _portrait_frames: Array[AtlasTexture] = []
var _portrait_frame_i := 0
var _portrait_anim_timer := 0.0
var _dismissing := false
var _preview_kind: int = TutorialUiPreviews.Kind.NONE
## When false: overlay ignores mouse so world (harvest pickup) receives clicks;
## Space/tap only finish typewriter — dismiss requires dismiss_for_event().
var _advance_on_input := true


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_portrait_frames()
	_build_ui()
	set_process(false)


func is_open() -> bool:
	return _open


func is_typing() -> bool:
	return _typing


## True while open in normal click-to-advance mode (blocks range input).
func blocks_world_input() -> bool:
	return _open and _advance_on_input


func show_thought(
	text: String,
	_allow_skip: bool = false,
	preview_kind: int = TutorialUiPreviews.Kind.NONE,
	options: Dictionary = {}
) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_dismissing = false
	_advance_on_input = bool(options.get("advance_on_input", true))
	_full_text = text
	_char_index = 0
	_char_timer = 0.0
	_typing = true
	_open = true
	_portrait_frame_i = 0
	_portrait_anim_timer = 0.0
	if not _portrait_frames.is_empty():
		_portrait.texture = _portrait_frames[0]
	_body.text = _full_text
	_body.visible_characters = 0
	_caret_visible = false
	_set_footer_pulse(false)
	_set_preview(preview_kind)
	_sync_continue_hint()
	_apply_input_filters()
	visible = true
	_layout_box()
	_play_slide_in()
	set_process(true)
	set_process_unhandled_input(true)


func hide_thought() -> void:
	_typing = false
	_open = false
	_dismissing = false
	_advance_on_input = true
	_clear_preview()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _panel != null:
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_process_unhandled_input(false)
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()


## Programmatic dismiss while waiting for a gameplay event (e.g. first pickup).
func dismiss_for_event() -> void:
	if not _open or _dismissing:
		return
	if _typing:
		_finish_typing_visuals()
	_play_slide_out_then_dismiss()


func _apply_input_filters() -> void:
	if _advance_on_input:
		mouse_filter = Control.MOUSE_FILTER_STOP
		if _panel != null:
			_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		# Root passthrough so harvest / fairway clicks reach PickupController.
		# Panel still catches taps on the dialogue (mobile nudge / Space-equivalent).
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _panel != null:
			_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_portrait_frames() -> void:
	_portrait_frames.clear()
	var sheet: Texture2D = load(SPEAKING_PATH)
	if sheet == null:
		return
	for i in SPEAKING_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2i(
			(i % SPEAKING_COLS) * SPEAKING_FRAME,
			(i / SPEAKING_COLS) * SPEAKING_FRAME,
			SPEAKING_FRAME,
			SPEAKING_FRAME
		)
		_portrait_frames.append(atlas)


func _build_ui() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override(&"panel", UiTheme.make_hud_plate())
	add_child(_panel)
	_panel.gui_input.connect(_on_panel_gui_input)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 6)
	margin.add_theme_constant_override(&"margin_right", 6)
	margin.add_theme_constant_override(&"margin_top", 5)
	margin.add_theme_constant_override(&"margin_bottom", 5)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not _portrait_frames.is_empty():
		_portrait.texture = _portrait_frames[0]
	row.add_child(_portrait)

	# Body + preview + footer share one left-aligned column beside the portrait.
	_text_col = VBoxContainer.new()
	_text_col.name = "TextColumn"
	_text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_text_col.add_theme_constant_override(&"separation", 3)
	row.add_child(_text_col)

	_body = Label.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body.add_theme_color_override(&"font_color", UiTheme.COLOR_PANEL_TEXT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelFont.apply_label(_body, FONT_SIZE)
	_text_col.add_child(_body)

	_preview_host = HBoxContainer.new()
	_preview_host.name = "PreviewHost"
	_preview_host.visible = false
	_preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_host.alignment = BoxContainer.ALIGNMENT_BEGIN
	_text_col.add_child(_preview_host)

	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.add_theme_constant_override(&"separation", 6)
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.custom_minimum_size = Vector2(0, FOOTER_HEIGHT)
	_text_col.add_child(_footer)

	_hint_row = HBoxContainer.new()
	_hint_row.add_theme_constant_override(&"separation", 4)
	_hint_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.add_child(_hint_row)

	_hint_key = Control.new()
	_hint_key.custom_minimum_size = Vector2(34, FOOTER_HEIGHT)
	_hint_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_key.draw.connect(_draw_space_key)
	_hint_row.add_child(_hint_key)

	_hint_label = Label.new()
	_hint_label.add_theme_color_override(&"font_color", UiTheme.COLOR_TITLE)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PixelFont.apply_label(_hint_label, 6)
	_hint_row.add_child(_hint_label)

	_caret = Label.new()
	_caret.text = "v"
	_caret.add_theme_color_override(&"font_color", UiTheme.COLOR_TITLE)
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caret.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caret.custom_minimum_size = Vector2(10, FOOTER_HEIGHT)
	_caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PixelFont.apply_label(_caret, FONT_SIZE)
	_footer.add_child(_caret)

	_set_footer_pulse(false)


func _sync_continue_hint() -> void:
	var mobile := UiLayout.is_mobile_touch()
	_hint_key.visible = not mobile
	_hint_label.text = TutorialCopy.continue_hint()
	if _hint_key.visible:
		_hint_key.queue_redraw()


func _draw_space_key() -> void:
	# Tiny pixel spacebar glyph for the continue hint.
	var fill := UiTheme.COLOR_PLATE_HOVER
	var border := UiTheme.COLOR_BORDER
	var r := Rect2(0, 1, 32, 10)
	_hint_key.draw_rect(r, fill)
	_hint_key.draw_rect(r, border, false, 1.0)
	_hint_key.draw_rect(Rect2(3, 4, 26, 2), border)


func _set_footer_pulse(show_pulse: bool) -> void:
	## Keep footer in layout always; blink via modulate so height never collapses.
	_caret_visible = show_pulse
	var alpha := 1.0 if show_pulse else 0.0
	_caret.modulate.a = alpha
	_hint_row.modulate.a = alpha


func _layout_box() -> void:
	var vp := get_viewport().get_visible_rect().size
	var margin_left := 10.0
	var margin_bottom := 14.0
	# Leave room for bucket counter on the right.
	var max_w := mini(BOX_WIDTH, vp.x - margin_left - 72.0)
	_panel.custom_minimum_size = Vector2(max_w, BOX_MIN_HEIGHT)
	_panel.size = Vector2(max_w, BOX_MIN_HEIGHT)
	_panel.reset_size()
	var panel_h := maxf(_panel.size.y, BOX_MIN_HEIGHT)
	_rest_y = vp.y - margin_bottom - panel_h
	_panel.position = Vector2(margin_left, _rest_y)


func _play_slide_in() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_panel.position.y = _rest_y + SLIDE_PX
	_slide_tween = create_tween()
	_slide_tween.tween_property(_panel, "position:y", _rest_y, SLIDE_SEC)


func _play_slide_out_then_dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	_typing = false
	_set_footer_pulse(false)
	set_process_unhandled_input(false)
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.tween_property(_panel, "position:y", _rest_y + SLIDE_PX, SLIDE_SEC)
	_slide_tween.finished.connect(_finish_slide_out_dismiss, CONNECT_ONE_SHOT)


func _finish_slide_out_dismiss() -> void:
	_open = false
	_dismissing = false
	_advance_on_input = true
	_clear_preview()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _panel != null:
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_process_unhandled_input(false)
	dismissed.emit()


func _process(delta: float) -> void:
	if not _open:
		return
	if not _dismissing:
		_tick_portrait(delta)
	if _dismissing:
		return
	if _typing:
		_char_timer += delta
		while _typing and _char_timer >= CHAR_INTERVAL_SEC:
			_char_timer -= CHAR_INTERVAL_SEC
			_advance_char()
	else:
		_caret_timer += delta
		if _caret_timer >= CARET_BLINK_SEC:
			_caret_timer = 0.0
			_set_footer_pulse(not _caret_visible)


func _tick_portrait(delta: float) -> void:
	## Loop expressive speaking frames while the dialogue box is open.
	if _portrait_frames.is_empty():
		return
	var count := _portrait_frames.size()
	if count <= 1:
		return
	_portrait_anim_timer += delta
	var frame_sec := 1.0 / SPEAKING_FPS
	while _portrait_anim_timer >= frame_sec:
		_portrait_anim_timer -= frame_sec
		_portrait_frame_i = (_portrait_frame_i + 1) % count
		_portrait.texture = _portrait_frames[_portrait_frame_i]


func _advance_char() -> void:
	_char_index += 1
	var total := _full_text.length()
	if _char_index >= total:
		_finish_typing_visuals()
		return
	_body.visible_characters = _char_index
	if _char_index % BLIP_EVERY_N_CHARS == 0:
		var ch := _full_text.substr(_char_index - 1, 1)
		if _should_blip_for(ch):
			SfxManager.play_text_blip()


func _should_blip_for(ch: String) -> bool:
	return ch != " " and ch != "." and ch != "," and ch != "-" and ch != "'" and ch != "\n" and ch != "—"


func _finish_typing_visuals() -> void:
	_char_index = _full_text.length()
	_body.visible_characters = -1
	_typing = false
	_caret_timer = 0.0
	if _advance_on_input:
		_sync_continue_hint()
		_set_footer_pulse(true)
	else:
		# Wait-for-event: no continue caret — player must pick up a ball.
		_set_footer_pulse(false)
	_layout_box()


func _complete_typing() -> void:
	## Instant reveal (no remaining blips) — Pokémon advance while typing.
	if not _typing:
		return
	_finish_typing_visuals()


func _request_advance() -> void:
	if not _open or _dismissing:
		return
	if _typing:
		_complete_typing()
		return
	if not _advance_on_input:
		nudge_requested.emit()
		return
	_play_slide_out_then_dismiss()


func _gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_request_advance()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			accept_event()
			_request_advance()


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_request_advance()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			accept_event()
			_request_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo or not key.pressed:
			return
		if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_request_advance()


func apply_viewport_layout() -> void:
	if _open:
		_layout_box()
		_sync_continue_hint()


func _set_preview(kind: int) -> void:
	_clear_preview()
	_preview_kind = kind
	if kind == TutorialUiPreviews.Kind.NONE or _preview_host == null:
		return
	var preview: Control = TutorialUiPreviews.build(kind)
	if preview == null:
		return
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_preview_host.add_child(preview)
	_preview_host.visible = true


func _clear_preview() -> void:
	_preview_kind = TutorialUiPreviews.Kind.NONE
	if _preview_host == null:
		return
	for child in _preview_host.get_children():
		_preview_host.remove_child(child)
		child.queue_free()
	_preview_host.visible = false
