extends Control
## Flat dollar-sign glyph — two-tone, no shading speckles.

const PIXEL := 2
const GRID := 11

const COLOR_FILL := UiTheme.COLOR_PANEL_TEXT
const COLOR_FILL_HOVER := UiTheme.COLOR_GLYPH_BRIGHT
const COLOR_OUTLINE := UiTheme.COLOR_GLYPH_OUTLINE
const COLOR_LOCKED_FILL := Color(0.45, 0.42, 0.38, 1.0)
const COLOR_LOCKED_OUTLINE := Color(0.32, 0.30, 0.28, 1.0)

# Centered dollar sign: O=outline, #=fill (7 cols x 7 rows).
const DOLLAR: PackedStringArray = [
	"..O#O..",
	".O###O.",
	".O#O...",
	"..O#O..",
	"...O#O.",
	".O###O.",
	"..O#O..",
]

const GLYPH_OFFSET := Vector2i(2, 2)

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
	custom_minimum_size = Vector2(GRID * PIXEL, GRID * PIXEL)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func _draw() -> void:
	var fill := COLOR_FILL
	var outline := COLOR_OUTLINE
	if _locked:
		fill = COLOR_LOCKED_FILL
		outline = COLOR_LOCKED_OUTLINE
	elif _highlighted:
		fill = COLOR_FILL_HOVER
	_draw_grid(DOLLAR, {"O": outline, "#": fill}, GLYPH_OFFSET)


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
