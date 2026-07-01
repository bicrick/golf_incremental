class_name UiTheme
extends RefCounted
## Shared RPG-kit wood panel styling for HUD chrome.

const COLOR_PARCHMENT := Color(0.82, 0.72, 0.48, 0.92)
const COLOR_BORDER := Color(0.18, 0.52, 0.48, 1.0)


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
