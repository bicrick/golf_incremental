class_name UiTheme
extends RefCounted
## Centralized UI chrome — edit tokens here to restyle HUD and menus.

# --- Geometry ---
const BORDER_WIDTH := 2
const CORNER_RADIUS := 0

const MARGIN_PLATE_H := 6
const MARGIN_PLATE_V := 4
const MARGIN_HEADER_H := 8
const MARGIN_HEADER_V := 4
const MARGIN_MENU_PANEL := 8
const MARGIN_BUTTON_H := 12
const MARGIN_BUTTON_V := 6
const MARGIN_BUTTON_COMPACT_H := 6
const MARGIN_BUTTON_COMPACT_V := 2
const MARGIN_BUTTON_TRANSPORT_H := 4
const MARGIN_BUTTON_TRANSPORT_V := 2
const MARGIN_BUTTON_DANGER_H := 10
const MARGIN_BUTTON_DANGER_V := 6

# --- Colors (opaque pixel boxes — golfer cream fill + hat green) ---
const COLOR_PLATE := Color(0.97, 0.94, 0.86, 1.0)
const COLOR_PLATE_HOVER := Color(1.0, 0.98, 0.92, 1.0)
const COLOR_PLATE_PRESSED := Color(0.90, 0.85, 0.72, 1.0)
const COLOR_PLATE_DISABLED := Color(0.82, 0.78, 0.68, 1.0)
## Matches range-rat cap / collar green (not near-black).
const COLOR_BORDER := Color(0.30, 0.62, 0.36, 1.0)
const COLOR_PLATE_SHADOW := Color(0.16, 0.28, 0.16, 0.22)
const COLOR_BORDER_DISABLED := Color(0.48, 0.58, 0.46, 1.0)

const COLOR_PANEL_TEXT := Color(0.22, 0.48, 0.28, 1.0)
const COLOR_PANEL_TEXT_OUTLINE := Color(0.98, 0.96, 0.88, 1.0)
## Readable on cream headers / bright sky (not yellow-on-cream).
const COLOR_TITLE := Color(0.18, 0.42, 0.24, 1.0)
## Gold accent only on dark backdrops (pause menu).
const COLOR_TITLE_ON_DARK := Color(1.0, 0.90, 0.38, 1.0)
const COLOR_LABEL := Color(0.14, 0.28, 0.16, 1.0)
const COLOR_LABEL_OUTLINE := Color(0.98, 0.96, 0.88, 1.0)
const COLOR_LABEL_ON_DARK := Color(0.92, 0.94, 0.86, 1.0)
const COLOR_BUTTON_TEXT := Color(0.18, 0.42, 0.24, 1.0)
const COLOR_DISABLED := Color(0.45, 0.50, 0.42, 1.0)
const COLOR_TAB_ACTIVE := COLOR_TITLE
const COLOR_TAB_INACTIVE := Color(0.42, 0.48, 0.40, 1.0)

const COLOR_DANGER_FILL := Color(0.68, 0.24, 0.22, 1.0)
const COLOR_DANGER_BORDER := Color(0.45, 0.14, 0.12, 1.0)
const COLOR_DANGER_HOVER := Color(0.80, 0.32, 0.28, 1.0)
const COLOR_DANGER_PRESSED := Color(0.48, 0.16, 0.14, 1.0)
const COLOR_DANGER_TEXT := Color(1.0, 0.96, 0.88, 1.0)

const COLOR_ACCENT_FILL := Color(0.78, 0.58, 0.16, 1.0)
const COLOR_ACCENT_BORDER := Color(0.48, 0.34, 0.08, 1.0)
const COLOR_ACCENT_HOVER := Color(0.90, 0.70, 0.24, 1.0)
const COLOR_ACCENT_PRESSED := Color(0.58, 0.42, 0.10, 1.0)
const COLOR_ACCENT_DISABLED_FILL := Color(0.58, 0.54, 0.44, 1.0)
const COLOR_ACCENT_DISABLED_BORDER := Color(0.40, 0.38, 0.30, 1.0)

const COLOR_GLYPH_OUTLINE := Color(0.16, 0.38, 0.20, 1.0)
const COLOR_GLYPH_HI := Color(0.38, 0.72, 0.44, 1.0)
const COLOR_GLYPH_BRIGHT := Color(0.44, 0.78, 0.50, 1.0)

## Day/night mood on HUD chrome. Full tint (1.0) crushed cream/greens; 0 ignored time of day.
## ~0.45 softens night without turning plates olive/black.
const UI_ATMOSPHERE_STRENGTH := 0.45


static func ui_atmosphere_modulate(tint: Color) -> Color:
	return Color.WHITE.lerp(tint, UI_ATMOSPHERE_STRENGTH)


# --- Factories ---

static func make_hud_plate() -> StyleBoxFlat:
	return _make_box(
		COLOR_PLATE,
		COLOR_BORDER,
		BORDER_WIDTH,
		MARGIN_PLATE_H,
		MARGIN_PLATE_V
	)


static func make_header_bar() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PLATE
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = BORDER_WIDTH
	style.border_color = COLOR_BORDER
	style.set_corner_radius_all(CORNER_RADIUS)
	style.content_margin_left = MARGIN_HEADER_H
	style.content_margin_right = MARGIN_HEADER_H
	style.content_margin_top = MARGIN_HEADER_V
	style.content_margin_bottom = MARGIN_HEADER_V
	return style


static func make_menu_panel() -> StyleBoxFlat:
	return _make_box(
		COLOR_PLATE,
		COLOR_BORDER,
		BORDER_WIDTH,
		MARGIN_MENU_PANEL,
		MARGIN_MENU_PANEL
	)


static func make_button_style(
	fill: Color,
	border: Color,
	margin_h: int = MARGIN_BUTTON_H,
	margin_v: int = MARGIN_BUTTON_V
) -> StyleBoxFlat:
	return _make_box(fill, border, BORDER_WIDTH, margin_h, margin_v)


# --- Apply helpers ---

static func apply_hud_plate(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override(&"panel", make_hud_plate())


static func apply_header_bar(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override(&"panel", make_header_bar())


static func apply_menu_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override(&"panel", make_menu_panel())


static func apply_primary_button(
	button: Button,
	margin_h: int = MARGIN_BUTTON_H,
	margin_v: int = MARGIN_BUTTON_V,
	font_size: int = 8
) -> void:
	_apply_button_font(button, font_size)
	button.add_theme_color_override(&"font_color", COLOR_BUTTON_TEXT)
	button.add_theme_color_override(&"font_hover_color", COLOR_BUTTON_TEXT)
	button.add_theme_color_override(&"font_pressed_color", COLOR_BUTTON_TEXT)
	button.add_theme_color_override(&"font_disabled_color", COLOR_DISABLED)
	button.add_theme_stylebox_override(
		&"normal", make_button_style(COLOR_PLATE, COLOR_BORDER, margin_h, margin_v)
	)
	button.add_theme_stylebox_override(
		&"hover", make_button_style(COLOR_PLATE_HOVER, COLOR_BORDER, margin_h, margin_v)
	)
	button.add_theme_stylebox_override(
		&"pressed", make_button_style(COLOR_PLATE_PRESSED, COLOR_BORDER, margin_h, margin_v)
	)
	button.add_theme_stylebox_override(
		&"disabled",
		make_button_style(COLOR_PLATE_DISABLED, COLOR_BORDER_DISABLED, margin_h, margin_v)
	)


static func apply_compact_primary_button(button: Button, font_size: int = 8) -> void:
	apply_primary_button(
		button, MARGIN_BUTTON_COMPACT_H, MARGIN_BUTTON_COMPACT_V, font_size
	)


static func apply_transport_button(button: Button) -> void:
	apply_primary_button(
		button, MARGIN_BUTTON_TRANSPORT_H, MARGIN_BUTTON_TRANSPORT_V, 8
	)


static func apply_danger_button(
	button: Button,
	margin_h: int = MARGIN_BUTTON_DANGER_H,
	margin_v: int = MARGIN_BUTTON_DANGER_V,
	font_size: int = 8
) -> void:
	_apply_button_font(button, font_size)
	button.add_theme_color_override(&"font_color", COLOR_DANGER_TEXT)
	button.add_theme_color_override(&"font_hover_color", COLOR_DANGER_TEXT)
	button.add_theme_color_override(&"font_pressed_color", COLOR_DANGER_TEXT)
	button.add_theme_stylebox_override(
		&"normal", make_button_style(COLOR_DANGER_FILL, COLOR_DANGER_BORDER, margin_h, margin_v)
	)
	button.add_theme_stylebox_override(
		&"hover", make_button_style(COLOR_DANGER_HOVER, COLOR_DANGER_BORDER, margin_h, margin_v)
	)
	button.add_theme_stylebox_override(
		&"pressed",
		make_button_style(COLOR_DANGER_PRESSED, COLOR_DANGER_BORDER, margin_h, margin_v)
	)


static func apply_accent_button(
	button: Button,
	margin_h: int = MARGIN_BUTTON_COMPACT_H,
	margin_v: int = MARGIN_BUTTON_COMPACT_V,
	font_size: int = 8
) -> void:
	_apply_button_font(button, font_size)
	button.add_theme_color_override(&"font_color", COLOR_BUTTON_TEXT)
	button.add_theme_color_override(&"font_hover_color", COLOR_BUTTON_TEXT)
	button.add_theme_color_override(&"font_pressed_color", COLOR_BUTTON_TEXT)
	button.add_theme_color_override(&"font_disabled_color", COLOR_DISABLED)
	button.add_theme_stylebox_override(
		&"normal", make_button_style(COLOR_ACCENT_FILL, COLOR_ACCENT_BORDER, margin_h, margin_v)
	)
	button.add_theme_stylebox_override(
		&"hover", make_button_style(COLOR_ACCENT_HOVER, COLOR_ACCENT_BORDER, margin_h, margin_v)
	)
	button.add_theme_stylebox_override(
		&"pressed",
		make_button_style(COLOR_ACCENT_PRESSED, COLOR_ACCENT_BORDER, margin_h, margin_v)
	)
	button.add_theme_stylebox_override(
		&"disabled",
		make_button_style(
			COLOR_ACCENT_DISABLED_FILL, COLOR_ACCENT_DISABLED_BORDER, margin_h, margin_v
		)
	)


static func apply_panel_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", COLOR_PANEL_TEXT)
	label.add_theme_color_override(&"font_outline_color", COLOR_PANEL_TEXT_OUTLINE)


static func apply_title_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", COLOR_TITLE)
	label.add_theme_color_override(&"font_outline_color", COLOR_PANEL_TEXT_OUTLINE)


static func apply_title_on_dark(label: Label) -> void:
	label.add_theme_color_override(&"font_color", COLOR_TITLE_ON_DARK)
	label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.10, 0.06, 0.9))


static func apply_body_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", COLOR_LABEL)
	label.add_theme_color_override(&"font_outline_color", COLOR_LABEL_OUTLINE)
	label.add_theme_constant_override(&"outline_size", 1)


static func apply_body_on_dark(label: Label) -> void:
	label.add_theme_color_override(&"font_color", COLOR_LABEL_ON_DARK)
	label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.10, 0.06, 0.85))
	label.add_theme_constant_override(&"outline_size", 1)


# --- Internals ---

static func _make_box(
	fill: Color,
	border: Color,
	border_w: int,
	margin_h: int,
	margin_v: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = border_w
	style.border_width_top = border_w
	style.border_width_right = border_w
	style.border_width_bottom = border_w
	style.border_color = border
	style.set_corner_radius_all(CORNER_RADIUS)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	style.shadow_color = COLOR_PLATE_SHADOW
	style.shadow_size = 1
	style.shadow_offset = Vector2(1, 1)
	return style


static func _apply_button_font(button: Button, font_size: int) -> void:
	button.add_theme_font_override(&"font", PixelFont.font_for_size(font_size))
	button.add_theme_font_size_override(&"font_size", font_size)
