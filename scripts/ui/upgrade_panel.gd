extends Control
## Upgrade overlay — opens from corner icon; purchase logic deferred to Workstream C.

@onready var panel: PanelContainer = $Panel
@onready var list: VBoxContainer = $Panel/Margin/VBox/Scroll/List
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton

var _is_open := false


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	EventBus.stats_changed.connect(_on_stats_changed)
	_style_panel()
	_refresh()


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	visible = true
	_notify_icon_bar(true)
	EventBus.ui_panel_toggled.emit("upgrades", true)


func close() -> void:
	_is_open = false
	visible = false
	_notify_icon_bar(false)
	EventBus.ui_panel_toggled.emit("upgrades", false)


func _notify_icon_bar(is_open: bool) -> void:
	var icon_bar := get_parent().get_node_or_null("IconBar")
	if icon_bar and icon_bar.has_method("set_upgrades_open"):
		icon_bar.set_upgrades_open(is_open)


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_refresh()


func _refresh() -> void:
	for child in list.get_children():
		child.queue_free()
	var placeholder := Label.new()
	placeholder.text = "Coming soon"
	placeholder.add_theme_color_override("font_color", Color(0.75, 0.68, 0.52, 1))
	placeholder.add_theme_font_size_override("font_size", 11)
	list.add_child(placeholder)


func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.62, 0.48, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.42, 0.34, 0.26, 1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)
