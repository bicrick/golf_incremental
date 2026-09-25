class_name TourJournal
extends Control
## v8 journal: Ratina's notes you've found, Barley's keepsakes, and stars.

var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.08, 0.05, 0.1, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER, TourUi.INK, 6))
	_panel.position = Vector2(60, 18)
	_panel.custom_minimum_size = Vector2(360, 234)
	_panel.size = Vector2(360, 234)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 4)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := TourUi.label("JOURNAL", 8, TourUi.GREEN_DARK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := TourUi.button("x", TourUi.PAPER_DIM, TourUi.INK)
	x.pressed.connect(close)
	head.add_child(x)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(346, 206)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override(&"separation", 3)
	_body.custom_minimum_size = Vector2(336, 0)
	_scroll.add_child(_body)


func is_blocking() -> bool:
	return visible


func open() -> void:
	_rebuild()
	visible = true
	Audio.play("page")


func close() -> void:
	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_J]:
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	for i in TourData.range_count():
		var r := TourData.get_range(i)
		if i > Tour.unlocked_range:
			_line("%s  ???" % r["numeral"], TourUi.INK_SOFT)
			continue
		_line("%s  %s   %d/%d stars" % [r["numeral"], r["name"], Tour.stars_in_range(i), (r["greens"] as Array).size()], TourUi.GREEN_DARK)
		var beat := "flag_" + String(r["id"])
		if Tour.cleared.get(r["id"], false):
			for l in TourStory.beat(beat):
				if l["who"] == "note":
					_line("  " + String(l["text"]), TourUi.PINK.darkened(0.35), true)
		for k in r["keepsakes"]:
			if Tour.keepsakes.get(k["id"], false):
				_line("  %s: %s (%s)" % [k["name"], k["line"], TourStory.bonus_text(k["bonus"])], TourUi.INK, true)
			else:
				_line("  A keepsake is still out there.", TourUi.INK_SOFT, true)
	_songs()


func _songs() -> void:
	_line("", TourUi.INK)
	_line("SONGS ON THE ROAD", TourUi.GREEN_DARK)
	var heard: Dictionary = Tour.flags.get("songs", {})
	for name in ["main-theme", "sunrise", "early-riser", "midday", "dusk", "night", "midnight", "final"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		if heard.get(name, false):
			var b := TourUi.button("Play", TourUi.GREEN)
			b.custom_minimum_size = Vector2(36, 12)
			b.pressed.connect(func() -> void: Audio.set_playlist([name] + Tour.current_range()["songs"], 0.6))
			row.add_child(b)
			var playing: bool = Audio.current_song() == name
			row.add_child(TourUi.label(("> " if playing else "  ") + Audio.song_title(name), 8, TourUi.PINK.darkened(0.3) if playing else TourUi.INK))
		else:
			row.add_child(TourUi.label("         ???", 8, TourUi.INK_SOFT))
		_body.add_child(row)


func _line(text: String, col: Color, wrap: bool = false) -> void:
	var l := TourUi.label(text, 8, col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(330, 0)
	l.add_theme_constant_override(&"line_spacing", 2)
	_body.add_child(l)
