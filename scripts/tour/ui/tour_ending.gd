class_name TourEnding
extends Control
## v8 ending: the sun comes up, then Barley's scorecard filled in with the
## run, the logo and credits, then "Keep swinging".

signal done

const LOGO := "res://assets/sprites/range_rat/range-rat-title-logo.png"

var _veil: ColorRect
var _card: Control
var _button: Button
var _t := 0.0
var _card_on := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(1.0, 0.93, 0.80, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_card = Control.new()
	_card.position = Vector2(80, 14)
	_card.size = Vector2(320, 242)
	_card.draw.connect(_draw_card)
	_card.modulate.a = 0.0
	_card.visible = false
	add_child(_card)
	_button = TourUi.button("Keep swinging", TourUi.GREEN)
	_button.position = Vector2(186, 234)
	_button.custom_minimum_size = Vector2(108, 18)
	_button.pressed.connect(_on_keep)
	_button.visible = false
	add_child(_button)


func is_blocking() -> bool:
	return visible and _card_on


## Warm light washes the screen while the last lines play underneath.
func sunrise(sec: float = 3.0) -> void:
	visible = true
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 0.55, sec)


func show_card() -> void:
	visible = true
	_card_on = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = true
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 0.85, 1.0)
	tw.parallel().tween_property(_card, "modulate:a", 1.0, 1.2)
	tw.tween_callback(func() -> void: _button.visible = true)


func _on_keep() -> void:
	_button.visible = false
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(_veil, "color:a", 0.0, 1.4)
	tw.tween_callback(func() -> void:
		visible = false
		_card.visible = false
		_card_on = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		done.emit()
	)


func _process(delta: float) -> void:
	if _card.visible:
		_t += delta
		_card.queue_redraw()


func _draw_card() -> void:
	var c := _card
	var font := PixelFont.font_for_size(8)
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r.grow(1), TourUi.INK)
	c.draw_rect(r, Color("fbf4e2"))
	c.draw_rect(Rect2(4, 4, r.size.x - 8, r.size.y - 8), Color("e9dcbc"), false, 1.0)
	var logo: Texture2D = load(LOGO)
	c.draw_texture(logo, Vector2((r.size.x - logo.get_width()) * 0.5, 8))
	_center(c, font, "BARLEY'S SCORECARD", 64, TourUi.GREEN_DARK)
	## Table.
	var y := 74.0
	var cols := [16.0, 40.0, 250.0]
	c.draw_rect(Rect2(12, y, r.size.x - 24, 1), TourUi.INK_SOFT)
	y += 4
	TinyText.draw(c, Vector2(cols[0], y), "HOLE", TourUi.INK_SOFT)
	TinyText.draw(c, Vector2(cols[1], y), "RANGE", TourUi.INK_SOFT)
	TinyText.draw(c, Vector2(cols[2], y), "SWINGS", TourUi.INK_SOFT)
	y += 9
	var total := 0
	for i in TourData.range_count():
		var rd := TourData.get_range(i)
		var n := int(Tour.range_swings.get(rd["id"], 0))
		total += n
		var name: String = rd["name"] if i < 4 else "The Longest Hole"
		c.draw_string(font, Vector2(cols[0], y + 8), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TourUi.INK)
		c.draw_string(font, Vector2(cols[1], y + 8), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TourUi.INK)
		c.draw_string(font, Vector2(cols[2], y + 8), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TourUi.RED)
		y += 13
	c.draw_rect(Rect2(12, y, r.size.x - 24, 1), TourUi.INK_SOFT)
	y += 4
	c.draw_string(font, Vector2(cols[1], y + 8), "Total", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TourUi.INK)
	c.draw_string(font, Vector2(cols[2], y + 8), str(total), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TourUi.RED)
	y += 16
	var minutes := int(Tour.play_time / 60.0)
	var stats := "%dM %02dS   %d PERFECTS   %d ACES   %d STARS   %d/10 KEEPSAKES" % [
		minutes, int(Tour.play_time) % 60, int(Tour.stats["perfects"]), int(Tour.stats["aces"]),
		Tour.total_stars(), Tour.keepsakes.size()]
	TinyText.draw(c, Vector2((r.size.x - TinyText.width(stats)) * 0.5, y), stats, TourUi.INK_SOFT)
	y += 12
	## Signatures.
	_center(c, font, "Played by Rat & Ratina", y + 8, TourUi.PINK.darkened(0.3))
	y += 18
	var credits := "A GAME BY BICRICK"
	TinyText.draw(c, Vector2((r.size.x - TinyText.width(credits)) * 0.5, y), credits, TourUi.INK_SOFT)
	TinyText.draw(c, Vector2((r.size.x - TinyText.width("THANKS FOR PLAYING.")) * 0.5, y + 9), "THANKS FOR PLAYING.", TourUi.INK_SOFT)


func _center(c: Control, font: Font, text: String, y: float, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(font, Vector2((c.size.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
