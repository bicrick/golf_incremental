extends Control
## Up-arrow glyph for the upgrades button — wood-panel palette, no squircle frame.

const PIXEL := 2
const GRID := 11

const COLOR_ARROW := UiTheme.COLOR_BORDER
const COLOR_ARROW_BRIGHT := Color(0.26, 0.64, 0.58, 1.0)
const COLOR_ARROW_OUTLINE := Color(0.12, 0.32, 0.28, 1.0)
const COLOR_ARROW_HI := Color(0.34, 0.68, 0.62, 1.0)

# Centered arrow: O=outline, #=fill (7 cols x 7 rows).
const ARROW: PackedStringArray = [
	"...O...",
	"..O#O..",
	".O###O.",
	"O#####O",
	"..O#O..",
	"..O#O..",
	"..O#O..",
]

const ARROW_OFFSET := Vector2i(2, 2)

var _highlighted := false

var highlighted: bool:
	get:
		return _highlighted
	set(value):
		if _highlighted == value:
			return
		_highlighted = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(GRID * PIXEL, GRID * PIXEL)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func _draw() -> void:
	var fill := COLOR_ARROW_HI if _highlighted else COLOR_ARROW
	var outline := COLOR_ARROW_OUTLINE
	if _highlighted:
		fill = COLOR_ARROW_BRIGHT
		outline = COLOR_ARROW
	_draw_grid(ARROW, {"O": outline, "#": fill}, ARROW_OFFSET)
	_draw_arrow_highlights()


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


func _draw_arrow_highlights() -> void:
	if _highlighted:
		return
	var highlights := [
		Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
		Vector2i(4, 3),
	]
	var origin := ARROW_OFFSET
	for cell in highlights:
		draw_rect(
			Rect2((origin.x + cell.x) * PIXEL, (origin.y + cell.y) * PIXEL, PIXEL, PIXEL),
			COLOR_ARROW_HI
		)
