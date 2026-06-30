extends Control
## Settings cog icon from cog.png — 22x22 to match upgrade glyph size.

const ICON_SIZE := Vector2i(22, 22)
const COG_TEXTURE: Texture2D = preload("res://assets/ui/cog.png")
## Visible gear art in the 26x26 source (2px transparent margin each side).
const COG_REGION := Rect2i(2, 2, 22, 22)

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
	custom_minimum_size = Vector2(ICON_SIZE)
	size = custom_minimum_size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var tint := Color(1.12, 1.12, 1.08) if _highlighted else Color.WHITE
	draw_texture_rect_region(
		COG_TEXTURE,
		Rect2(Vector2.ZERO, Vector2(ICON_SIZE)),
		COG_REGION,
		tint
	)
