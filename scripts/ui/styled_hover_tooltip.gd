class_name StyledHoverTooltip
extends Node
## Reusable upgrade-style hover tooltip (pixel font + dark gold-border panel).
## Attach as a child, then call bind(host) and set_content(title, body).

const DELAY_SEC := 0.08
const MAX_WIDTH := 150.0
const GAP := 5.0
const EDGE_MARGIN := 8.0
const BG := Color(0.08, 0.11, 0.06, 0.96)
const BORDER := Color(0.78, 0.66, 0.28, 1)
const TITLE_COLOR := Color(1.0, 0.9, 0.45, 1)
const BODY_COLOR := Color(0.82, 0.78, 0.66, 1)

const TooltipViewportClampScript = preload("res://scripts/ui/tooltip_viewport_clamp.gd")

var _host: Control
var _title: String = ""
var _body: String = ""
var _hovering := false
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _timer: Timer


func _ready() -> void:
	_ensure_ui()


func bind(host: Control) -> void:
	if _host != null:
		if _host.mouse_entered.is_connected(_on_mouse_entered):
			_host.mouse_entered.disconnect(_on_mouse_entered)
		if _host.mouse_exited.is_connected(_on_mouse_exited):
			_host.mouse_exited.disconnect(_on_mouse_exited)
	_host = host
	if _host == null:
		return
	# Avoid Godot's default grey tooltip chrome.
	_host.tooltip_text = ""
	if not _host.mouse_entered.is_connected(_on_mouse_entered):
		_host.mouse_entered.connect(_on_mouse_entered)
	if not _host.mouse_exited.is_connected(_on_mouse_exited):
		_host.mouse_exited.connect(_on_mouse_exited)


func set_content(title: String, body: String) -> void:
	_title = title
	_body = body
	_ensure_ui()
	_title_label.text = _title
	_body_label.text = _body
	_body_label.visible = not _body.is_empty()
	if _panel.visible:
		_position_panel()


func hide_now() -> void:
	_hovering = false
	if _timer:
		_timer.stop()
	if _panel:
		_panel.visible = false


func _ensure_ui() -> void:
	if _panel != null:
		return
	_panel = PanelContainer.new()
	_panel.name = "StyledHoverTooltipPanel"
	_panel.visible = false
	_panel.top_level = true
	_panel.z_index = 30
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 3)
	margin.add_theme_constant_override(&"margin_top", 3)
	margin.add_theme_constant_override(&"margin_right", 3)
	margin.add_theme_constant_override(&"margin_bottom", 3)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 1)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.custom_minimum_size = Vector2(88, 0)
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(88, 0)
	vbox.add_child(_body_label)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = DELAY_SEC
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	_style_panel()
	PixelFont.apply_label(_title_label, 7)
	PixelFont.apply_label(_body_label, 6)
	_title_label.add_theme_color_override(&"font_color", TITLE_COLOR)
	_body_label.add_theme_color_override(&"font_color", BODY_COLOR)


func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = BORDER
	style.shadow_size = 0
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	_panel.add_theme_stylebox_override(&"panel", style)


func _on_mouse_entered() -> void:
	_hovering = true
	if _title.is_empty() and _body.is_empty():
		return
	_timer.start()


func _on_mouse_exited() -> void:
	_hovering = false
	_timer.stop()
	_panel.visible = false


func _on_timer_timeout() -> void:
	if not _hovering:
		return
	_title_label.text = _title
	_body_label.text = _body
	_body_label.visible = not _body.is_empty()
	_position_panel()
	_panel.visible = true


func _position_panel() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var tip_size: Vector2 = _panel.get_combined_minimum_size()
	tip_size.x = clampf(tip_size.x, 72.0, MAX_WIDTH)
	_panel.custom_minimum_size = tip_size
	_panel.size = tip_size

	var host_rect := _host.get_global_rect()
	var bounds := TooltipViewportClampScript.visible_bounds(_host)
	var pos := Vector2(
		host_rect.position.x + host_rect.size.x + GAP,
		host_rect.position.y + (host_rect.size.y - tip_size.y) * 0.5
	)
	if pos.x + tip_size.x > bounds.end.x - EDGE_MARGIN:
		pos.x = host_rect.position.x - tip_size.x - GAP
	_panel.global_position = TooltipViewportClampScript.clamp_pos(pos, tip_size, bounds, EDGE_MARGIN)