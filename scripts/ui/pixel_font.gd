class_name PixelFont
extends RefCounted
## Cached 8-bit UI font — nearest filtering, no antialiasing.
## Always load via ResourceLoader so web exports use the imported .fontdata
## (raw TTF is remapped and is not available to load_dynamic_font on HTML5).

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

static var _cache: Dictionary = {}
static var _base_font: FontFile


static func font_for_size(size: int) -> FontFile:
	if _cache.has(size):
		return _cache[size]
	var font := _make_configured_font()
	_cache[size] = font
	return font


static func apply_label(label: Label, size: int) -> void:
	label.add_theme_font_override(&"font", font_for_size(size))
	label.add_theme_font_size_override(&"font_size", size)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func _make_configured_font() -> FontFile:
	var base := _load_base_font()
	if base == null:
		push_warning("PixelFont: failed to load %s" % FONT_PATH)
		return FontFile.new()
	var font := base.duplicate(true) as FontFile
	if font == null:
		font = base
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 0.0
	return font


static func _load_base_font() -> FontFile:
	if _base_font != null:
		return _base_font
	var loaded := load(FONT_PATH) as FontFile
	if loaded != null:
		_base_font = loaded
		return _base_font
	# Desktop fallback if import remap is missing.
	var dynamic := FontFile.new()
	var err := dynamic.load_dynamic_font(FONT_PATH)
	if err != OK:
		return null
	_base_font = dynamic
	return _base_font
