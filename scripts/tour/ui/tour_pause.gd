class_name TourPause
extends Control
## v8 pause: resume, music / sound volume, back to title.

signal to_title

var _panel: PanelContainer
var _music: HSlider
var _sfx_slider: HSlider


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.08, 0.05, 0.1, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER, TourUi.INK, 8))
	_panel.position = Vector2(150, 60)
	_panel.custom_minimum_size = Vector2(180, 0)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 6)
	_panel.add_child(vb)
	var title := TourUi.label("PAUSED", 8, TourUi.GREEN_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_music = _slider(vb, "Music", Audio.music_volume)
	_music.value_changed.connect(Audio.set_music_volume)
	_sfx_slider = _slider(vb, "Sound", Audio.sfx_volume)
	_sfx_slider.value_changed.connect(Audio.set_sfx_volume)
	var resume := TourUi.button("Resume", TourUi.GREEN)
	resume.pressed.connect(close)
	vb.add_child(resume)
	var title_btn := TourUi.button("Save & quit to title", TourUi.PAPER, TourUi.INK)
	title_btn.pressed.connect(func() -> void:
		close()
		Tour.save_game()
		to_title.emit()
	)
	vb.add_child(title_btn)
	var keys := TourUi.label("Space swing  A/D aim\nTab shop  J journal  M map", 8, TourUi.INK_SOFT)
	keys.add_theme_constant_override(&"line_spacing", 3)
	vb.add_child(keys)


func _slider(parent: Control, text: String, value: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := TourUi.label(text, 8, TourUi.INK)
	l.custom_minimum_size = Vector2(52, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(100, 12)
	var grab := GradientTexture2D.new()
	grab.width = 6
	grab.height = 10
	var g := Gradient.new()
	g.set_color(0, TourUi.GREEN)
	g.set_color(1, TourUi.GREEN)
	grab.gradient = g
	s.add_theme_icon_override(&"grabber", grab)
	s.add_theme_icon_override(&"grabber_highlight", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = TourUi.PAPER_DIM
	track.border_color = TourUi.INK
	track.set_border_width_all(1)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	s.add_theme_stylebox_override(&"slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("9fd08a")
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	s.add_theme_stylebox_override(&"grabber_area", fill)
	s.add_theme_stylebox_override(&"grabber_area_highlight", fill)
	row.add_child(s)
	return s


func is_blocking() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
