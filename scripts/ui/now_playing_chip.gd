extends Control
## v5 — "now playing" chip: slides in bottom-left when a new BGM track starts.

const HOLD_SEC := 4.5
const SLIDE_SEC := 0.35
const MARGIN := 8.0

var _plate: PanelContainer
var _label: Label
var _note: Control
var _tween: Tween
var _pulse_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.make_hud_plate()
	style.content_margin_left = 4
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_plate.add_theme_stylebox_override(&"panel", style)
	add_child(_plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	_plate.add_child(row)
	_note = Control.new()
	_note.custom_minimum_size = Vector2(9, 11)
	_note.draw.connect(_draw_note)
	row.add_child(_note)
	_label = Label.new()
	_label.add_theme_color_override(&"font_color", UiTheme.COLOR_PANEL_TEXT)
	PixelFont.apply_label(_label, 8)
	row.add_child(_label)
	_plate.visible = false
	var sfx := get_node_or_null("/root/SfxManager")
	if sfx != null and sfx.has_signal("music_track_changed"):
		sfx.music_track_changed.connect(_on_track_changed)
	set_process(false)


func _draw_note() -> void:
	## Tiny pixel eighth note that bobs to the beat.
	var bob := roundf(sin(_pulse_t * TAU * 1.2) * 0.6)
	var c := UiTheme.COLOR_TITLE
	_note.draw_rect(Rect2(1, 7 + bob, 4, 3), c)
	_note.draw_rect(Rect2(4, 1 + bob, 1, 7), c)
	_note.draw_rect(Rect2(5, 1 + bob, 3, 1), c)
	_note.draw_rect(Rect2(7, 2 + bob, 1, 2), c)


func _process(delta: float) -> void:
	_pulse_t += delta
	_note.queue_redraw()


func _on_track_changed(path: String) -> void:
	var title := get_tree().root.get_node_or_null("Main/TitleScreen")
	if title != null and title.visible:
		return
	var basename := MusicTrackRhythm.track_basename(path)
	show_track(MusicDayClock.display_name(basename))


func show_track(title: String) -> void:
	if title.is_empty():
		return
	_label.text = title
	_plate.visible = true
	_plate.reset_size()
	var vp := get_viewport_rect().size
	var rest := Vector2(MARGIN, vp.y - MARGIN - _plate.size.y)
	var hidden := Vector2(-_plate.size.x - 4.0, rest.y)
	_plate.position = hidden
	set_process(true)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(_plate, "position", rest, SLIDE_SEC)
	_tween.tween_interval(HOLD_SEC)
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_plate, "position", hidden, SLIDE_SEC)
	_tween.tween_callback(func() -> void:
		_plate.visible = false
		set_process(false)
	)
