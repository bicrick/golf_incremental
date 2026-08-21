class_name TutorialUiPreviews
extends RefCounted
## Miniature HUD replicas for tutorial dialogue (upgrades / bucket / shag bag).

const PixelUpArrowScript = preload("res://scripts/ui/pixel_up_arrow.gd")
const ShagBagGlyphScript = preload("res://scripts/ui/shag_bag_glyph.gd")

enum Kind {
	NONE = 0,
	UPGRADES = 1,
	BUCKET = 2,
	SHAG_BAG = 3,
}

const ICON_SIZE := Vector2i(24, 24)
const WRAP_MARGIN_H := 2
const WRAP_MARGIN_V := 1
const BALL_ICON_SIZE := Vector2(16, 16)


static func build(kind: int) -> Control:
	match kind:
		Kind.UPGRADES:
			return make_upgrades_preview()
		Kind.BUCKET:
			return make_bucket_preview()
		Kind.SHAG_BAG:
			return make_shag_bag_preview()
		_:
			return null


static func make_upgrades_preview() -> Control:
	## Matches IconBar UpgradesWrap: cream plate + up-arrow glyph.
	var wrap := PanelContainer.new()
	wrap.name = "UpgradesPreview"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.custom_minimum_size = Vector2(_wrap_outer_size())
	var style := UiTheme.make_hud_plate()
	style.content_margin_left = WRAP_MARGIN_H
	style.content_margin_right = WRAP_MARGIN_H
	style.content_margin_top = WRAP_MARGIN_V
	style.content_margin_bottom = WRAP_MARGIN_V
	wrap.add_theme_stylebox_override(&"panel", style)

	var glyph: Control = PixelUpArrowScript.new()
	glyph.name = "Glyph"
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.custom_minimum_size = Vector2(ICON_SIZE)
	glyph.size = Vector2(ICON_SIZE)
	wrap.add_child(glyph)
	return wrap


static func make_shag_bag_preview() -> Control:
	## Matches IconBar shag-bag wrap: cream plate + bag glyph (mobile harvest entry).
	var wrap := PanelContainer.new()
	wrap.name = "ShagBagPreview"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.custom_minimum_size = Vector2(_wrap_outer_size())
	var style := UiTheme.make_hud_plate()
	style.content_margin_left = WRAP_MARGIN_H
	style.content_margin_right = WRAP_MARGIN_H
	style.content_margin_top = WRAP_MARGIN_V
	style.content_margin_bottom = WRAP_MARGIN_V
	wrap.add_theme_stylebox_override(&"panel", style)

	var glyph: Control = ShagBagGlyphScript.new()
	glyph.name = "Glyph"
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.custom_minimum_size = Vector2(ICON_SIZE)
	glyph.size = Vector2(ICON_SIZE)
	wrap.add_child(glyph)
	return wrap


static func make_bucket_preview() -> Control:
	## Matches BucketCounter: plate + Dinky ball + count fraction.
	var plate := PanelContainer.new()
	plate.name = "BucketPreview"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_hud_plate(plate)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(row)

	var ball := TextureRect.new()
	ball.name = "BallIcon"
	ball.custom_minimum_size = BALL_ICON_SIZE
	ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ball.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball.texture = DinkySpriteFrames.ball_lay_texture()
	row.add_child(ball)

	var count := Label.new()
	count.name = "CountLabel"
	count.text = "0/6"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelFont.apply_label(count, 10)
	UiTheme.apply_panel_label(count)
	row.add_child(count)
	return plate


static func _wrap_outer_size() -> Vector2i:
	var border := UiTheme.BORDER_WIDTH
	return Vector2i(
		ICON_SIZE.x + WRAP_MARGIN_H * 2 + border * 2,
		ICON_SIZE.y + WRAP_MARGIN_V * 2 + border * 2
	)
