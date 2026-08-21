extends Control
## Shag-bag HUD glyph. Uses SHAG_BAG_TEXTURE_PATH when present; else pixel fallback.

const PIXEL := 2
const GRID := 11
const SHAG_BAG_TEXTURE_PATH := "res://assets/ui/shag_bag.png"

const COLOR_FILL_HOVER := UiTheme.COLOR_GLYPH_BRIGHT
const COLOR_OUTLINE := UiTheme.COLOR_GLYPH_OUTLINE
const COLOR_LOCKED_FILL := Color(0.45, 0.42, 0.38, 1.0)
const COLOR_LOCKED_OUTLINE := Color(0.32, 0.30, 0.28, 1.0)
const COLOR_BODY := Color(0.28, 0.46, 0.24, 1.0)
const COLOR_BODY_HOVER := Color(0.38, 0.58, 0.30, 1.0)
const COLOR_BODY_LOCKED := Color(0.40, 0.38, 0.34, 1.0)

## O=outline #=bag body .=empty
const BAG: PackedStringArray = [
	"..OOOOO..",
	".O#####O.",
	"O#######O",
	"O##O#O##O",
	"O#######O",
	"O#######O",
	".OOOOOOO.",
]

const BAG_OFFSET := Vector2i(1, 2)

var _texture: Texture2D
var _highlighted := false
var _locked := false

var highlighted: bool:
	get:
		return _highlighted
	set(value):
		if _highlighted == value:
			return
		_highlighted = value
		queue_redraw()

var locked: bool:
	get:
		return _locked
	set(value):
		if _locked == value:
			return
		_locked = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(24, 24)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	if ResourceLoader.exists(SHAG_BAG_TEXTURE_PATH):
		_texture = load(SHAG_BAG_TEXTURE_PATH) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	if _texture != null:
		var tex_size := Vector2(_texture.get_width(), _texture.get_height())
		var fit := 1.0
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			fit = minf(size.x / tex_size.x, size.y / tex_size.y)
		var dest_size := tex_size * fit
		var dest := Rect2((size - dest_size) * 0.5, dest_size)
		var modulate := Color.WHITE
		if _locked:
			modulate = Color(0.55, 0.55, 0.55, 1.0)
		elif _highlighted:
			modulate = Color(1.08, 1.08, 1.04, 1.0)
		draw_texture_rect(_texture, dest, false, modulate)
		return
	var outline := COLOR_OUTLINE
	var body := COLOR_BODY
	if _locked:
		outline = COLOR_LOCKED_OUTLINE
		body = COLOR_BODY_LOCKED
	elif _highlighted:
		outline = COLOR_FILL_HOVER
		body = COLOR_BODY_HOVER
	_draw_grid(BAG, {"O": outline, "#": body}, BAG_OFFSET)


func _draw_grid(
	grid: PackedStringArray,
	colors: Dictionary,
	offset: Vector2i = Vector2i.ZERO
) -> void:
	for y in grid.size():
		var row := grid[y]
		for x in row.length():
			var ch: String = row[x]
			if not colors.has(ch):
				continue
			draw_rect(
				Rect2((offset.x + x) * PIXEL, (offset.y + y) * PIXEL, PIXEL, PIXEL),
				colors[ch]
			)
