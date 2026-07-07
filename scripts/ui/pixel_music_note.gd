extends Control
## Music-note glyph for the pause menu player — pause-menu gold/teal palette.

const PIXEL := 2
const GRID := 11

const COLOR_FILL := Color(1.0, 0.92, 0.45, 1.0)
const COLOR_OUTLINE := Color(0.18, 0.52, 0.48, 1.0)

# Eighth note: O=outline, #=fill (7 cols x 8 rows).
const NOTE: PackedStringArray = [
	"....O..",
	"...O#O.",
	"..O###.",
	"...O#O.",
	"...O#O.",
	"..O###O",
	".O#####",
	"..O###.",
]

const GLYPH_OFFSET := Vector2i(2, 1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(GRID * PIXEL, GRID * PIXEL)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func _draw() -> void:
	_draw_grid(NOTE, {"O": COLOR_OUTLINE, "#": COLOR_FILL}, GLYPH_OFFSET)


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
