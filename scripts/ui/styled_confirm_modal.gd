class_name StyledConfirmModal
extends Control
## Compact game-styled confirm modal: dim backdrop + pixel-font panel.

signal confirmed
signal cancelled

const PANEL_BG := Color(0.08, 0.11, 0.06, 0.96)
const PANEL_BORDER := Color(0.78, 0.66, 0.28, 1.0)
const TITLE_COLOR := Color(1.0, 0.9, 0.45, 1.0)
const BODY_COLOR := Color(0.82, 0.78, 0.66, 1.0)
const DIM_COLOR := Color(0.02, 0.03, 0.02, 0.62)
const PANEL_WIDTH := 220.0

var _dim: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _cancel_button: Button
var _confirm_button: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_ui()


func configure(title: String, body: String, confirm_label: String = "Confirm", cancel_label: String = "Cancel") -> void:
	_ensure_ui()
	_title_label.text = title
	_body_label.text = body
	_confirm_button.text = confirm_label
	_cancel_button.text = cancel_label


func open_modal() -> void:
	_ensure_ui()
	visible = true
	move_to_front()


func close_modal() -> void:
	visible = false


func _ensure_ui() -> void:
	if _panel != null:
		return

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = DIM_COLOR
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 8)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0)
	vbox.add_child(_body_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	vbox.add_child(buttons)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(64, 18)
	_cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buttons.add_child(_cancel_button)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.custom_minimum_size = Vector2(72, 18)
	_confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buttons.add_child(_confirm_button)

	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)

	_style_panel()
	_style_button(_cancel_button, false)
	_style_button(_confirm_button, true)
	PixelFont.apply_label(_title_label, 9)
	PixelFont.apply_label(_body_label, 6)
	_title_label.add_theme_color_override(&"font_color", TITLE_COLOR)
	_body_label.add_theme_color_override(&"font_color", BODY_COLOR)


func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = PANEL_BORDER
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	_panel.add_theme_stylebox_override(&"panel", style)


func _style_button(button: Button, primary: bool) -> void:
	button.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	button.add_theme_font_size_override(&"font_size", 8)
	button.add_theme_color_override(&"font_color", Color(0.12, 0.1, 0.08, 1))
	var style := StyleBoxFlat.new()
	if primary:
		style.bg_color = Color(0.86, 0.72, 0.28, 0.95)
		style.border_color = Color(0.45, 0.32, 0.08, 1)
	else:
		style.bg_color = Color(0.72, 0.66, 0.52, 0.92)
		style.border_color = Color(0.28, 0.26, 0.2, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	button.add_theme_stylebox_override(&"normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.12)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", hover)


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel_pressed()


func _on_cancel_pressed() -> void:
	close_modal()
	cancelled.emit()


func _on_confirm_pressed() -> void:
	close_modal()
	confirmed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
