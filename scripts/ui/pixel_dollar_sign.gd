extends Control
## Dollar-sign glyph for the Pro Shop button — wood-panel palette, no squircle frame.

const PIXEL := 2
const GRID := 11

const COLOR_FILL := UiTheme.COLOR_BORDER
const COLOR_FILL_BRIGHT := Color(0.92, 0.78, 0.22, 1.0)
const COLOR_OUTLINE := Color(0.12, 0.32, 0.28, 1.0)
const COLOR_HI := Color(1.0, 0.92, 0.45, 1.0)

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
		fill = Color(0.45, 0.42, 0.38, 1.0)
		outline = Color(0.32, 0.30, 0.28, 1.0)
	elif _highlighted:
		fill = COLOR_FILL_BRIGHT
		outline = COLOR_OUTLINE
	_draw_grid(DOLLAR, {"O": outline, "#": fill}, GLYPH_OFFSET)
	if not _locked and not _highlighted:
		_draw_highlights()


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


func _draw_highlights() -> void:
	var highlights := [Vector2i(3, 1), Vector2i(4, 2), Vector2i(3, 4)]
	var origin := GLYPH_OFFSET
	for cell in highlights:
		draw_rect(
			Rect2((origin.x + cell.x) * PIXEL, (origin.y + cell.y) * PIXEL, PIXEL, PIXEL),
			COLOR_HI
		)
