@tool
extends Sprite3D
## Editor-only calibration aid — NOT used at runtime or in a real build.
##
## Drag this node around (Local scene tree, Perspective viewport) using the
## move/scale gizmo until it visually reads correctly next to the golfer and
## the fairway art: feet planted on the grass, size comparable to the golfer.
## Then report back this node's Transform > Position (especially Y) and
## Scale (or Pixel Size) — those numbers become the real spawn Y and
## Balance.RATTLING_PIXEL_SIZE used by rattling.gd.
##
## Toggle "Show Placeholder" off in the Inspector to hide it while you work
## on other things; it never appears when Engine.is_editor_hint() is false
## (i.e. never in the actual running game).

const IDLE_TEXTURE := "res://assets/sprites/rattling/rattling.png"

@export var show_placeholder: bool = true:
	set(value):
		show_placeholder = value
		_refresh_visibility()


func _ready() -> void:
	if texture == null:
		texture = load(IDLE_TEXTURE)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	## Deliberately center-anchored (no foot offset) — rattling.gd's sprite
	## uses this same zero offset so it matches exactly what was calibrated
	## here, instead of re-deriving a foot-anchored ground height.
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = Engine.is_editor_hint() and show_placeholder
