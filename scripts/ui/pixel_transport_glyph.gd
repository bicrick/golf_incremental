extends Control
## Pixel transport icons — music note, play, pause, skip forward/back.

enum Type { MUSIC_NOTE, PLAY, PAUSE, SKIP_FORWARD, SKIP_BACK }

const PIXEL := 2

const COLOR_FILL := UiTheme.COLOR_BUTTON_TEXT
const COLOR_NOTE_FILL := UiTheme.COLOR_TITLE
const COLOR_NOTE_OUTLINE := UiTheme.COLOR_BORDER
const COLOR_DISABLED := UiTheme.COLOR_DISABLED

@export var glyph_type: Type = Type.PLAY

var disabled: bool = false:
	set(value):
		if disabled == value:
			return
		disabled = value
		queue_redraw()

# Quaver — round note head, stem, flag curl.
const MUSIC_NOTE: PackedStringArray = [
	"....O...",
	"...O#O..",
	"..O###..",
	"...O#...",
	"...O#...",
	"...O#...",
	"...O#...",
	"..O###O.",
	".O#####.",
	"..O###..",
]

const PLAY: PackedStringArray = [
	"...#...",
	"..###..",
	".#####.",
	"#######",
	"#######",
	".#####.",
	"..###..",
	"...#...",
]

const PAUSE: PackedStringArray = [
	".#..#.",
	".#..#.",
	".#..#.",
	".#..#.",
	".#..#.",
	".#..#.",
]

# Two overlapping right chevrons (>>).
const SKIP_FORWARD: PackedStringArray = [
	"..#..#..",
	"..##.##.",
	".###.###",
	"..##.##.",
	"..#..#..",
]

# Two overlapping left chevrons (<<).
const SKIP_BACK: PackedStringArray = [
	"..#..#..",
	".##.##..",
	"###.###.",
	".##.##..",
	"..#..#..",
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_size_for_glyph()
	pivot_offset = size * 0.5


func _apply_size_for_glyph() -> void:
	var grid := _grid_for_type(glyph_type)
	var width := _grid_width(grid)
	var height := grid.size()
	custom_minimum_size = Vector2(width * PIXEL, height * PIXEL)
	size = custom_minimum_size


func _draw() -> void:
	var grid := _grid_for_type(glyph_type)
	var fill := COLOR_DISABLED if disabled else _fill_for_type()
	var outline := COLOR_DISABLED if disabled else _outline_for_type()
	var colors := {"O": outline, "#": fill}
	if glyph_type == Type.MUSIC_NOTE:
		colors = {"O": outline, "#": fill}
	_draw_grid(grid, colors)


func _grid_for_type(type: Type) -> PackedStringArray:
	match type:
		Type.MUSIC_NOTE:
			return MUSIC_NOTE
		Type.PLAY:
			return PLAY
		Type.PAUSE:
			return PAUSE
		Type.SKIP_FORWARD:
			return SKIP_FORWARD
		Type.SKIP_BACK:
			return SKIP_BACK
		_:
			return PLAY


func _fill_for_type() -> Color:
	return COLOR_NOTE_FILL if glyph_type == Type.MUSIC_NOTE else COLOR_FILL


func _outline_for_type() -> Color:
	return COLOR_NOTE_OUTLINE if glyph_type == Type.MUSIC_NOTE else COLOR_FILL


func _grid_width(grid: PackedStringArray) -> int:
	var width := 0
	for row in grid:
		width = maxi(width, row.length())
	return width


func _draw_grid(grid: PackedStringArray, colors: Dictionary) -> void:
	var width := _grid_width(grid)
	var height := grid.size()
	var offset_x := maxi(0, (11 - width) / 2)
	var offset_y := maxi(0, (11 - height) / 2)
	for y in height:
		var row := grid[y]
		for x in row.length():
			var ch: String = row[x]
			if not colors.has(ch):
				continue
			draw_rect(
				Rect2((offset_x + x) * PIXEL, (offset_y + y) * PIXEL, PIXEL, PIXEL),
				colors[ch]
			)
