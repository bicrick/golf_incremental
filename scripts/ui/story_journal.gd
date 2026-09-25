extends Control
## v5 Journal — Barley's notes and everything found in the mist, by act.

const ICON_SIZE := 22

var _is_open := false
var _panel: PanelContainer
var _list: VBoxContainer
var _progress: Label
var _ending_button: Button


func _ready() -> void:
	add_to_group(&"story_journal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	EventBus.story_find_found.connect(func(_id: String) -> void: _refresh())
	EventBus.story_completed.connect(_refresh)


func is_open() -> bool:
	return _is_open


func is_blocking_input() -> bool:
	return _is_open


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	visible = true
	_refresh()
	SfxManager.play_ui_page()
	EventBus.ui_panel_toggled.emit("journal", true)


func close() -> void:
	_is_open = false
	visible = false
	EventBus.ui_panel_toggled.emit("journal", false)


func _gui_input(event: InputEvent) -> void:
	## Click on the dim backdrop closes.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_J):
			get_viewport().set_input_as_handled()
			close()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.12, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(300, 210)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UiTheme.make_menu_panel()
	style.bg_color = Color(0.98, 0.95, 0.85, 1.0)
	style.border_color = Color(0.55, 0.36, 0.20, 1.0)
	_panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	_panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := Label.new()
	title.text = "Journal"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override(&"font_color", Color(0.42, 0.26, 0.14, 1.0))
	PixelFont.apply_label(title, 10)
	header.add_child(title)
	_progress = Label.new()
	_progress.add_theme_color_override(&"font_color", Color(0.55, 0.42, 0.28, 1.0))
	PixelFont.apply_label(_progress, 7)
	header.add_child(_progress)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	UiTheme.apply_compact_primary_button(close_button, 7)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 3)
	scroll.add_child(_list)

	_ending_button = Button.new()
	_ending_button.text = "Read the ending again"
	_ending_button.focus_mode = Control.FOCUS_NONE
	UiTheme.apply_compact_primary_button(_ending_button, 7)
	_ending_button.pressed.connect(_replay_ending)
	col.add_child(_ending_button)


func _refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	_progress.text = "%d / %d found" % [GameState.story_found_count(), GameState.story_total_count()]
	_ending_button.visible = GameState.story_complete
	var last_act := -1
	for def in StoryFinds.all():
		var id: String = def["id"]
		var act := int(def["act"])
		if act != last_act:
			last_act = act
			var act_label := Label.new()
			act_label.text = StoryFinds.act_name(act)
			act_label.add_theme_color_override(&"font_color", Color(0.30, 0.50, 0.30, 1.0))
			PixelFont.apply_label(act_label, 7)
			_list.add_child(act_label)
		_list.add_child(_row_for(def))


func _row_for(def: Dictionary) -> Control:
	var id: String = def["id"]
	var found := GameState.is_find_found(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var tex_name := String(def.get("sprite_found", def["sprite"]))
	icon.texture = load(StoryFinds.sprite_path(tex_name))
	if not found:
		icon.modulate = Color(0.55, 0.52, 0.45, 0.35)
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override(&"separation", 1)
	row.add_child(text_col)
	var name_label := Label.new()
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(240, 0)
	if found:
		name_label.text = String(def["display_name"])
		var reward: Dictionary = def.get("reward", {})
		var note := ""
		if reward.has("note"):
			note = StoryScript.note_text(String(reward["note"]))
		var reward_line := StoryFinds.reward_text(id)
		body.text = note if not note.is_empty() else reward_line
		if not note.is_empty() and not reward_line.is_empty() and not reward.has("arm_finale"):
			body.text += "\n" + reward_line
	else:
		name_label.text = "???"
		var yards := int(def["yards"])
		if GameState.is_find_revealed(id):
			body.text = "Out on the range, around %d yd. Go look." % yards
		elif float(def["yards"]) <= GameState.revealed_yards() + StoryFinds.SILHOUETTE_YARDS:
			body.text = "A shape in the mist, around %d yd." % yards
		else:
			body.text = "Somewhere in the mist."
	name_label.add_theme_color_override(&"font_color", Color(0.36, 0.24, 0.14, 1.0))
	body.add_theme_color_override(&"font_color", Color(0.34, 0.33, 0.38, 1.0))
	PixelFont.apply_label(name_label, 7)
	PixelFont.apply_label(body, 6)
	text_col.add_child(name_label)
	text_col.add_child(body)
	return row


func _replay_ending() -> void:
	close()
	var ending := get_tree().get_first_node_in_group(&"story_ending")
	if ending != null and ending.has_method("play_ending"):
		ending.play_ending(true)
