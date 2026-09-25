class_name TourDialogue
extends Control
## v8 dialogue: a paper box at the bottom with a portrait and typed text.
## "sign" lines show as a big title card instead. Space / Enter / click advances.

signal finished(beat_id: String)

const CPS := 55.0
const RAT_SHEET := "res://assets/sprites/range_rat/rat-speaking-sheet.png"
const RATINA_SHEET := "res://assets/sprites/ratina/ratina-waiting-sheet.png"
const NOTE_TEX := "res://assets/sprites/tour/scorecard.png"

var _queue: Array = []
var _beat := ""
var _lines: Array = []
var _i := 0
var _box: PanelContainer
var _portrait_frame: Control
var _portrait: TextureRect
var _name: Label
var _text: Label
var _more: Label
var _sign: Label
var _sign_sub: Label
var _typing := 0.0
var _talk_t := 0.0
var _rat_frames: Array[AtlasTexture] = []
var _ratina_tex: AtlasTexture
var _blip_acc := 0.0
var _extra: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var rat_sheet: Texture2D = load(RAT_SHEET)
	for i in 9:
		var a := AtlasTexture.new()
		a.atlas = rat_sheet
		a.region = Rect2((i % 3) * 52, (i / 3) * 52, 52, 52)
		_rat_frames.append(a)
	_ratina_tex = AtlasTexture.new()
	_ratina_tex.atlas = load(RATINA_SHEET)
	_ratina_tex.region = Rect2(0, 0, 52, 52)

	_box = PanelContainer.new()
	_box.add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER, TourUi.INK, 5))
	_box.position = Vector2(12, 270 - 74)
	_box.size = Vector2(456, 66)
	_box.custom_minimum_size = Vector2(456, 66)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.gui_input.connect(_on_box_input)
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	_box.add_child(row)
	_portrait_frame = PanelContainer.new()
	_portrait_frame.add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER_DIM, TourUi.INK, 1))
	_portrait_frame.custom_minimum_size = Vector2(54, 54)
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_frame.add_child(_portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override(&"separation", 4)
	row.add_child(vb)
	_name = TourUi.label("", 8, TourUi.GREEN_DARK)
	vb.add_child(_name)
	_text = TourUi.label("", 8, TourUi.INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(370, 36)
	_text.add_theme_constant_override(&"line_spacing", 3)
	vb.add_child(_text)
	_more = TourUi.label("v", 8, TourUi.INK_SOFT)
	_more.position = Vector2(456 - 14, 54)
	_box.add_child(_more)
	_more.top_level = false

	_sign = TourUi.outlined(TourUi.label("", 16, TourUi.PAPER_HI), TourUi.INK, 4)
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.position = Vector2(0, 96)
	_sign.size = Vector2(480, 24)
	add_child(_sign)
	_sign_sub = TourUi.outlined(TourUi.label("", 8, TourUi.PAPER_HI), TourUi.INK, 3)
	_sign_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign_sub.position = Vector2(0, 124)
	_sign_sub.size = Vector2(480, 12)
	add_child(_sign_sub)


func is_blocking() -> bool:
	return visible


## Queue a beat; extra lines (Array of {who,text}) can be appended.
func play(beat_id: String, lines: Array = []) -> void:
	var ls := lines if not lines.is_empty() else TourStory.beat(beat_id)
	if ls.is_empty():
		finished.emit(beat_id)
		return
	_queue.append({"id": beat_id, "lines": ls})
	if not visible:
		_next_beat()


func _next_beat() -> void:
	if _queue.is_empty():
		visible = false
		return
	var b: Dictionary = _queue.pop_front()
	_beat = b["id"]
	_lines = b["lines"]
	_i = 0
	visible = true
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_i]
	var who: String = line["who"]
	var is_sign := who == "sign"
	_box.visible = not is_sign
	_sign.visible = is_sign
	_sign_sub.visible = is_sign
	if is_sign:
		var parts := String(line["text"]).split(". ", false, 1)
		_sign.text = parts[0].trim_suffix(".")
		_sign_sub.text = parts[1] if parts.size() > 1 else ""
		_sign.modulate.a = 0.0
		_sign_sub.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_sign, "modulate:a", 1.0, 0.5)
		tw.parallel().tween_property(_sign_sub, "modulate:a", 1.0, 0.8)
		_typing = 9999.0
		return
	_text.text = line["text"]
	_text.visible_characters = 0
	_typing = 0.0
	match who:
		"rat":
			_name.text = "Rat"
			_portrait.texture = _rat_frames[0]
		"ratina":
			_name.text = "Ratina"
			_portrait.texture = _ratina_tex
		"note":
			_name.text = "Ratina's note"
			_portrait.texture = load(NOTE_TEX)
		"keepsake":
			_name.text = String(line.get("title", "Keepsake"))
			_portrait.texture = load(String(line.get("icon", NOTE_TEX)))
		_:
			_name.text = ""
			_portrait.texture = null
	_name.add_theme_color_override(&"font_color", TourUi.PINK.darkened(0.25) if who in ["ratina", "note"] else TourUi.GREEN_DARK)


func _process(delta: float) -> void:
	if not visible:
		return
	_talk_t += delta
	if _box.visible and _typing < 9000.0:
		var before := _text.visible_characters
		_typing += delta * CPS
		_text.visible_characters = int(_typing)
		if _text.visible_characters != before and _text.visible_characters % 2 == 0:
			if _text.visible_characters < _text.text.length():
				Audio.play_type()
		## Rat mouth flaps while typing.
		if _lines[_i]["who"] == "rat":
			var talking := _text.visible_characters < _text.text.length()
			_portrait.texture = _rat_frames[int(_talk_t * 9.0) % 9] if talking else _rat_frames[0]
	_more.visible = _box.visible and _text.visible_characters >= _text.text.length() and int(_talk_t * 2.0) % 2 == 0


func _on_box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
			advance()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()


func advance() -> void:
	if _box.visible and _text.visible_characters < _text.text.length():
		_typing = 9999.0
		_text.visible_characters = _text.text.length()
		return
	_i += 1
	if _i >= _lines.size():
		var done := _beat
		_next_beat()
		finished.emit(done)
		return
	_show_line()
