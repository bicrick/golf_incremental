class_name TourUi
extends RefCounted
## v8 UI house style: cream paper plates, ink borders, one pixel font.

const PAPER := Color("f6efdc")
const PAPER_HI := Color("fffaf0")
const PAPER_DIM := Color("e4d9bf")
const INK := Color("2d2433")
const INK_SOFT := Color("6b5d6e")
const GREEN := Color("3f8f4e")
const GREEN_DARK := Color("2c6a3a")
const GOLD := Color("e8b84a")
const PINK := Color("e8739f")
const RED := Color("c2453c")
const SHADOW := Color(0.05, 0.03, 0.08, 0.35)


static func plate(fill: Color = PAPER, border: Color = INK, margin: int = 4, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(0)
	s.content_margin_left = margin + 1
	s.content_margin_right = margin + 1
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	s.shadow_color = SHADOW
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 2)
	s.anti_aliasing = false
	return s


static func label(text: String, size: int = 8, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", PixelFont.font_for_size(size))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func outlined(l: Label, outline: Color = INK, px: int = 2) -> Label:
	l.add_theme_color_override(&"font_outline_color", outline)
	l.add_theme_constant_override(&"outline_size", px)
	return l


static func button(text: String, fill: Color = GREEN, text_color: Color = PAPER_HI) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	b.add_theme_font_size_override(&"font_size", 8)
	for state in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		b.add_theme_color_override(state, text_color)
	b.add_theme_color_override(&"font_disabled_color", INK_SOFT)
	b.add_theme_stylebox_override(&"normal", plate(fill, INK, 4))
	b.add_theme_stylebox_override(&"hover", plate(fill.lightened(0.12), INK, 4))
	b.add_theme_stylebox_override(&"pressed", plate(fill.darkened(0.15), INK, 4))
	b.add_theme_stylebox_override(&"disabled", plate(PAPER_DIM, INK_SOFT, 4))
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	return b


static func icon_button(tex: Texture2D, tip: String) -> Button:
	var b := Button.new()
	b.icon = tex
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.expand_icon = false
	b.add_theme_stylebox_override(&"normal", plate(PAPER, INK, 2))
	b.add_theme_stylebox_override(&"hover", plate(PAPER_HI, GOLD.darkened(0.3), 2))
	b.add_theme_stylebox_override(&"pressed", plate(PAPER_DIM, INK, 2))
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	return b
