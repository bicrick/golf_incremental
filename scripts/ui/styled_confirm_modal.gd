class_name StyledConfirmModal
extends Control
## Compact game-styled confirm modal: dim backdrop + UiTheme cream plate.

signal confirmed
signal cancelled

const DIM_COLOR := Color(0.02, 0.03, 0.02, 0.55)
const PANEL_WIDTH_WIDE := 280.0
const PANEL_WIDTH_NARROW := 220.0
const PANEL_EDGE_PAD := 32.0

var _dim: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _cancel_button: Button
var _confirm_button: Button
var _confirm_is_danger := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_ui()
	apply_viewport_layout()


func configure(
	title: String,
	body: String,
	confirm_label: String = "Confirm",
	cancel_label: String = "Cancel",
	confirm_is_danger: bool = false
) -> void:
	_ensure_ui()
	_title_label.text = title
	_body_label.text = body
	_confirm_button.text = confirm_label
	_cancel_button.text = cancel_label
	_confirm_is_danger = confirm_is_danger
	_style_buttons()


func open_modal() -> void:
	_ensure_ui()
	apply_viewport_layout()
	visible = true
	move_to_front()


func close_modal() -> void:
	visible = false


func apply_viewport_layout(viewport: Viewport = null) -> void:
	_ensure_ui()
	var vp := viewport if viewport != null else get_viewport()
	if vp == null:
		return
	var size := UiLayout.viewport_size(vp)
	var max_w := PANEL_WIDTH_NARROW if UiLayout.is_portrait(vp) else PANEL_WIDTH_WIDE
	var width := mini(max_w, size.x - PANEL_EDGE_PAD)
	_panel.custom_minimum_size = Vector2(width, 0)
	_body_label.custom_minimum_size = Vector2(maxf(width - 24.0, 80.0), 0)


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
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH_WIDE, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override(&"margin_left", 4)
	margin.add_theme_constant_override(&"margin_top", 4)
	margin.add_theme_constant_override(&"margin_right", 4)
	margin.add_theme_constant_override(&"margin_bottom", 4)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override(&"separation", 10)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(PANEL_WIDTH_WIDE - 24.0, 0)
	vbox.add_child(_body_label)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	vbox.add_child(buttons)

	_cancel_button = Button.new()
	_cancel_button.name = "CancelButton"
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(72, 20)
	_cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buttons.add_child(_cancel_button)

	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.text = "Confirm"
	_confirm_button.custom_minimum_size = Vector2(72, 20)
	_confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buttons.add_child(_confirm_button)

	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)

	UiTheme.apply_menu_panel(_panel)
	PixelFont.apply_label(_title_label, 9)
	PixelFont.apply_label(_body_label, 7)
	UiTheme.apply_title_label(_title_label)
	UiTheme.apply_body_label(_body_label)
	_style_buttons()


func _style_buttons() -> void:
	if _cancel_button == null or _confirm_button == null:
		return
	UiTheme.apply_primary_button(_cancel_button)
	if _confirm_is_danger:
		UiTheme.apply_danger_button(_confirm_button)
	else:
		UiTheme.apply_accent_button(_confirm_button)


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
