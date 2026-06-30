extends Control
## 8-bit app-icon squircle with upward arrow — nearest-neighbor pixel art.

const PIXEL := 2
const GRID := 11

const COLOR_BORDER := Color("#2A4420")
const COLOR_BORDER_DARK := Color("#1E3018")
const COLOR_FILL := Color("#D8EECF")
const COLOR_FILL_HI := Color("#EAF6E4")
const COLOR_ARROW := Color("#3DDC84")
const COLOR_ARROW_BRIGHT := Color("#5AF098")
const COLOR_ARROW_OUTLINE := Color("#1B3D18")

# Pixel-rounded square frame (B=border, F=fill).
const SQUIRCLE: PackedStringArray = [
	"..BBBBBBB..",
	".BFFFFFFFB.",
	"BFFFFFFFFFB",
	"BFFFFFFFFFB",
	"BFFFFFFFFFB",
	"BFFFFFFFFFB",
	"BFFFFFFFFFB",
	"BFFFFFFFFFB",
	"BFFFFFFFFFB",
	".BFFFFFFFB.",
	"..BBBBBBB..",
]

# Centered arrow: O=outline, #=fill (7 cols x 7 rows inside squircle).
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
	var fill := COLOR_FILL_HI if _highlighted else COLOR_FILL
	_draw_grid(SQUIRCLE, {"B": COLOR_BORDER, "F": fill})
	_draw_corner_accents(COLOR_BORDER_DARK)
	_draw_grid(ARROW, {"O": COLOR_ARROW_OUTLINE, "#": COLOR_ARROW}, ARROW_OFFSET)
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


func _draw_corner_accents(dark: Color) -> void:
	# One-pixel dark accents on outer corners for depth.
	var corners := [
		Vector2i(2, 1), Vector2i(8, 1),
		Vector2i(1, 2), Vector2i(9, 2),
		Vector2i(1, 8), Vector2i(9, 8),
		Vector2i(2, 9), Vector2i(8, 9),
	]
	for cell in corners:
		draw_rect(Rect2(cell * PIXEL, Vector2(PIXEL, PIXEL)), dark)


func _draw_arrow_highlights() -> void:
	# Bright cap on arrow head for readable 8-bit shading.
	var highlights := [
		Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
		Vector2i(4, 3),
	]
	var origin := ARROW_OFFSET
	for cell in highlights:
		draw_rect(
			Rect2((origin.x + cell.x) * PIXEL, (origin.y + cell.y) * PIXEL, PIXEL, PIXEL),
			COLOR_ARROW_BRIGHT
		)
