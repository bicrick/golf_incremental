extends TextureRect
## Hit-button icon — a blacked-out silhouette of the player's own
## follow-through pose, so returning to hitting mode reads as a swing switch
## rather than an abstract transport glyph.

const COLOR_SILHOUETTE := Color(0.06, 0.06, 0.06, 1.0)
const RangeRatSpriteFramesScript := preload("res://scripts/range/range_rat_sprite_frames.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	modulate = COLOR_SILHOUETTE
	var sheet: Texture2D = load(RangeRatSpriteFramesScript.SWING_SHEET)
	texture = RangeRatSpriteFramesScript.make_atlas_frame(
		sheet, RangeRatSpriteFramesScript.SWING_COLS, RangeRatSpriteFramesScript.FOLLOW_END
	)
