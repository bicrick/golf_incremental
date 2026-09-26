class_name FortuneTitle
extends Control
## v9 title: the logo over the live range, Continue / New game.

signal play_pressed(new_game: bool)

const LOGO := "res://assets/sprites/range_rat/range-rat-title-logo.png"

var _logo: TextureRect
var _t := 0.0
var _confirm := false
var _new_btn: Button
var _cont_btn: Button
var _sub: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.06, 0.12, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_logo = TextureRect.new()
	_logo.texture = load(LOGO)
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.size = Vector2(280, 88)
	_logo.position = Vector2(100, 30)
	add_child(_logo)
	_sub = TourUi.outlined(TourUi.label("FORTUNE RANGE", 8, TourUi.PAPER_HI), TourUi.INK, 3)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.position = Vector2(0, 122)
	_sub.size = Vector2(480, 10)
	add_child(_sub)
	var story := TourUi.outlined(TourUi.label("Barley's old range is going under.\nMake $1,000,000 and it's yours.", 8, Color(1.0, 0.9, 0.65)), TourUi.INK, 3)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.add_theme_constant_override(&"line_spacing", 3)
	story.position = Vector2(0, 136)
	story.size = Vector2(480, 20)
	add_child(story)
	var vb := VBoxContainer.new()
	vb.position = Vector2(180, 172)
	vb.custom_minimum_size = Vector2(120, 0)
	vb.add_theme_constant_override(&"separation", 6)
	add_child(vb)
	_cont_btn = TourUi.button("Continue", TourUi.GREEN)
	_cont_btn.custom_minimum_size = Vector2(120, 20)
	_cont_btn.pressed.connect(func() -> void: _go(false))
	vb.add_child(_cont_btn)
	_new_btn = TourUi.button("New game", TourUi.PAPER, TourUi.INK)
	_new_btn.custom_minimum_size = Vector2(120, 20)
	_new_btn.pressed.connect(_on_new)
	vb.add_child(_new_btn)
	_cont_btn.visible = Game.has_started()
	if not Game.has_started():
		_new_btn.text = "Play"
	var hint := TourUi.outlined(TourUi.label("Space to start", 8, TourUi.PAPER_HI), TourUi.INK, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 244)
	hint.size = Vector2(480, 10)
	hint.modulate.a = 0.8
	add_child(hint)


func _on_new() -> void:
	if Game.has_started() and not _confirm:
		_confirm = true
		_new_btn.text = "Erase save?"
		_new_btn.add_theme_color_override(&"font_color", TourUi.RED)
		return
	_go(true)


func _go(new_game: bool) -> void:
	Audio.play("travel")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		visible = false
		play_pressed.emit(new_game)
	)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	if event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
		get_viewport().set_input_as_handled()
		_go(not Game.has_started())


func _process(delta: float) -> void:
	_t += delta
	_logo.position.y = 30 + round(sin(_t * 1.4) * 2.0)
