class_name UiTheme
extends RefCounted
## Shared RPG-kit wood panel styling for HUD chrome.

const COLOR_PARCHMENT := Color(0.82, 0.72, 0.48, 0.92)
const COLOR_BORDER := Color(0.18, 0.52, 0.48, 1.0)
const COLOR_PANEL_TEXT := Color(0.85, 0.92, 0.98, 1.0)
const COLOR_PANEL_TEXT_OUTLINE := Color(0.2, 0.15, 0.1, 0.8)


static func make_wood_panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func apply_wood_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override(&"panel", make_wood_panel())


static func make_wood_header_bar() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func apply_wood_header_bar(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override(&"panel", make_wood_header_bar())


static func apply_panel_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", COLOR_PANEL_TEXT)
	label.add_theme_color_override(&"font_outline_color", COLOR_PANEL_TEXT_OUTLINE)
