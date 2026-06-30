extends Control
## 8-bit settings cog — squircle frame with 8-tooth gear, nearest-neighbor pixel art.

const PIXEL := 2
const GRID := 11

const COLOR_BORDER := Color("#2A4420")
const COLOR_BORDER_DARK := Color("#1E3018")
const COLOR_FILL := Color("#D8EECF")
const COLOR_FILL_HI := Color("#EAF6E4")
const COLOR_GEAR_OUTLINE := Color("#2A3824")
const COLOR_GEAR := Color("#7A8A72")
const COLOR_GEAR_BRIGHT := Color("#A8B8A0")
const COLOR_GEAR_DARK := Color("#4A5A42")

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

# 9x9 eight-tooth cog: O=outline, G=body, .=center hole (transparent).
const GEAR: PackedStringArray = [
	"..O...O..",
	".OGO.OGO.",
	"OGGGGGGGO",
	"OGG...GGO",
	"OGG...GGO",
	"OGG...GGO",
	"OGGGGGGGO",
	".OGO.OGO.",
	"..O...O..",
]

const GEAR_OFFSET := Vector2i(1, 1)

const GEAR_HIGHLIGHTS: Array[Vector2i] = [
	Vector2i(2, 1), Vector2i(3, 2), Vector2i(2, 3),
	Vector2i(6, 1), Vector2i(5, 2), Vector2i(6, 3),
	Vector2i(2, 7), Vector2i(6, 7),
]

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
	var body := COLOR_GEAR_BRIGHT if _highlighted else COLOR_GEAR
	_draw_grid(SQUIRCLE, {"B": COLOR_BORDER, "F": fill})
	_draw_corner_accents(COLOR_BORDER_DARK)
	_draw_grid(
		GEAR,
		{"O": COLOR_GEAR_OUTLINE, "G": body, "H": COLOR_GEAR_BRIGHT, ".": Color.TRANSPARENT},
		GEAR_OFFSET
	)
	_draw_gear_highlights()


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
			var color: Color = colors[ch]
			if color.a <= 0.0:
				continue
			draw_rect(
				Rect2((offset.x + x) * PIXEL, (offset.y + y) * PIXEL, PIXEL, PIXEL),
				color
			)


func _draw_corner_accents(dark: Color) -> void:
	var corners := [
	 Vector2i(2, 1), Vector2i(8, 1),
	 Vector2i(1, 2), Vector2i(9, 2),
	 Vector2i(1, 8), Vector2i(9, 8),
	 Vector2i(2, 9), Vector2i(8, 9),
	]
	for cell in corners:
		draw_rect(Rect2(cell * PIXEL, Vector2(PIXEL, PIXEL)), dark)


func _draw_gear_highlights() -> void:
	var origin := GEAR_OFFSET
	for cell in GEAR_HIGHLIGHTS:
		draw_rect(Rect2((origin + cell) * PIXEL, Vector2(PIXEL, PIXEL)), COLOR_GEAR_BRIGHT)
