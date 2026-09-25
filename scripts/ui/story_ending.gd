extends Control
## v5 ending — the last ball lands, the mist lifts, the closing lines, a title
## card with the run's numbers, credits, then "Keep swinging" into the postgame.

const TITLE_LOGO_PATH := "res://assets/sprites/range_rat/range-rat-title-logo.png"
## Wait for the last ball to land on the green before the mist lifts.
const FLIGHT_WAIT_SEC := 3.4
const MIST_IN_SEC := 2.2
const LINE_IN_SEC := 0.9
const LINE_HOLD_SEC := 3.2
const LINE_OUT_SEC := 0.7
const MIST_COLOR := Color(0.90, 0.92, 0.86, 1.0)
const INK := Color(0.20, 0.30, 0.20, 1.0)
const INK_SOFT := Color(0.36, 0.44, 0.34, 1.0)

var _running := false
var _mist: ColorRect
var _line_label: Label
var _card: VBoxContainer
var _stats_label: Label
var _credits_label: Label
var _continue_button: Button


func _ready() -> void:
	add_to_group(&"story_ending")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	EventBus.story_final_shot.connect(_on_final_shot)


func is_blocking_input() -> bool:
	return _running


func is_running() -> bool:
	return _running


func _build() -> void:
	_mist = ColorRect.new()
	_mist.color = Color(MIST_COLOR.r, MIST_COLOR.g, MIST_COLOR.b, 0.0)
	_mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mist)

	_line_label = Label.new()
	_line_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line_label.offset_left = 48
	_line_label.offset_right = -48
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.add_theme_color_override(&"font_color", INK)
	_line_label.modulate.a = 0.0
	PixelFont.apply_label(_line_label, 9)
	add_child(_line_label)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override(&"separation", 6)
	_card.modulate.a = 0.0
	_card.visible = false
	center.add_child(_card)

	var logo := TextureRect.new()
	logo.texture = load(TITLE_LOGO_PATH)
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(220, 84)
	_card.add_child(logo)

	var the_end := _label("— The End —", 10, INK)
	_card.add_child(the_end)

	_stats_label = _label("", 7, INK_SOFT)
	_card.add_child(_stats_label)

	_credits_label = _label(
		"A game by bicrick\nArt: PixelLab + hand-pixelled story props\n"
		+ "Dinky Tiny Golf by Mike Moore · UI kit by Craftpix\n"
		+ "Thanks for keeping the lights on.",
		6,
		INK_SOFT
	)
	_card.add_child(_credits_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(row)
	_continue_button = Button.new()
	_continue_button.text = "Keep swinging"
	_continue_button.focus_mode = Control.FOCUS_NONE
	_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiTheme.apply_primary_button(_continue_button)
	_continue_button.pressed.connect(_on_continue)
	row.add_child(_continue_button)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", color)
	PixelFont.apply_label(label, size)
	return label


func _on_final_shot() -> void:
	if _running:
		return
	_running = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().create_timer(FLIGHT_WAIT_SEC).timeout
	play_ending(false)


## Also used by the Journal ("Read the ending again") with replay = true.
func play_ending(replay: bool) -> void:
	_running = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	_card.modulate.a = 0.0
	var sfx := get_node_or_null("/root/SfxManager")
	if sfx != null and sfx.has_method("play_story_finale"):
		sfx.play_story_finale()
	var tw := create_tween()
	tw.tween_property(_mist, "color:a", 0.96, MIST_IN_SEC)
	await tw.finished
	for line in StoryScript.ENDING_LINES:
		_line_label.text = line
		var t_in := create_tween()
		t_in.tween_property(_line_label, "modulate:a", 1.0, LINE_IN_SEC)
		await t_in.finished
		await get_tree().create_timer(LINE_HOLD_SEC).timeout
		var t_out := create_tween()
		t_out.tween_property(_line_label, "modulate:a", 0.0, LINE_OUT_SEC)
		await t_out.finished
	_stats_label.text = _stats_text()
	_continue_button.text = "Back to the range" if replay else "Keep swinging"
	_card.visible = true
	var t_card := create_tween()
	t_card.tween_property(_card, "modulate:a", 1.0, 1.2)
	if not replay:
		GameState.complete_story()


func _stats_text() -> String:
	var lt: Dictionary = GameState.lifetime
	var minutes := int(GameState.play_time_sec / 60.0)
	var time_text := "%dh %02dm" % [minutes / 60, minutes % 60]
	return "%d swings · %d Perfects · %d yd best · %d/%d finds · %s" % [
		int(lt.get("total_swings", 0)),
		int(lt.get("perfect_count", 0)),
		int(round(GameState.max_carry_yards())),
		GameState.story_found_count(),
		GameState.story_total_count(),
		time_text,
	]


func _on_continue() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_card, "modulate:a", 0.0, 0.6)
	tw.tween_property(_mist, "color:a", 0.0, 1.4)
	await tw.finished
	_card.visible = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_running = false
