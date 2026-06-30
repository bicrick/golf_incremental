class_name PixelFont
extends RefCounted
## Cached 8-bit UI font — nearest filtering, no antialiasing.

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

static var _cache: Dictionary = {}


static func font_for_size(size: int) -> FontFile:
	if _cache.has(size):
		return _cache[size]
	var font := FontFile.new()
	font.load_dynamic_font(FONT_PATH)
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 0.0
	_cache[size] = font
	return font


static func apply_label(label: Label, size: int) -> void:
	label.add_theme_font_override(&"font", font_for_size(size))
	label.add_theme_font_size_override(&"font_size", size)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
