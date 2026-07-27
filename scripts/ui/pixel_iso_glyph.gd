extends Control
## Flat isometric diamond glyph for the Build button.

const PIXEL := 2

const COLOR_FILL := UiTheme.COLOR_BORDER
const COLOR_FILL_HOVER := UiTheme.COLOR_GLYPH_BRIGHT
const COLOR_OUTLINE := UiTheme.COLOR_GLYPH_OUTLINE

# 11x11 grid: O=outline, #=fill — isometric diamond.
const DIAMOND: PackedStringArray = [
	"....O....",
	"...O#O...",
	"..O###O..",
	".O#####O.",
	"O###O###O",
	".O#####O.",
	"..O###O..",
	"...O#O...",
	"....O....",
]

const OFFSET := Vector2i(1, 1)

var _highlighted := false

var highlighted: bool:
	get:
		return _highlighted
	set(value):
		if _highlighted == value:
			return
		_highlighted = value
		queue_redraw()


func _draw() -> void:
	var fill := COLOR_FILL_HOVER if _highlighted else COLOR_FILL
	for row in DIAMOND.size():
		var line: String = DIAMOND[row]
		for col in line.length():
			var ch := line[col]
			if ch == ".":
				continue
			var color := COLOR_OUTLINE if ch == "O" else fill
			var p := Vector2((OFFSET.x + col) * PIXEL, (OFFSET.y + row) * PIXEL)
			draw_rect(Rect2(p, Vector2(PIXEL, PIXEL)), color)
