class_name FortuneBanner
extends Control
## v9 big moments: JACKPOT, HOLE IN ONE, TRIPLES… a gold flash and a banner
## that punches in over everything. Queued so none are lost.

var _queue: Array[Dictionary] = []
var _cur: Dictionary = {}
var _t := 0.0
var _font16: Font
var _font: Font

const LIFE := 1.8


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font16 = PixelFont.font_for_size(16)
	_font = PixelFont.font_for_size(8)


func show_moment(title: String, sub: String, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	_queue.append({"title": title, "sub": sub, "color": color})


func _process(delta: float) -> void:
	if _cur.is_empty() and not _queue.is_empty():
		_cur = _queue.pop_front()
		_t = 0.0
	if not _cur.is_empty():
		_t += delta * (1.6 if _queue.size() > 1 else 1.0)
		if _t > LIFE:
			_cur = {}
	queue_redraw()


func _draw() -> void:
	if _cur.is_empty():
		return
	var col: Color = _cur["color"]
	var flash := clampf(1.0 - _t / 0.25, 0.0, 1.0)
	if flash > 0.0:
		draw_rect(Rect2(0, 0, 330, 270), Color(col.r, col.g, col.b, flash * 0.28))
	var a := clampf((LIFE - _t) / 0.35, 0.0, 1.0)
	var punch := 1.0 + maxf(0.0, 0.5 - _t * 3.0)
	var cx := 165.0
	var y := 92.0
	var band := Rect2(0, y - 22, 330, 38)
	draw_rect(band, Color(0.06, 0.04, 0.08, 0.6 * a))
	draw_rect(Rect2(0, band.position.y, 330, 1), Color(col.r, col.g, col.b, a))
	draw_rect(Rect2(0, band.end.y - 1, 330, 1), Color(col.r, col.g, col.b, a))
	var title: String = _cur["title"]
	var w := _font16.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_set_transform(Vector2(cx, y), 0.0, Vector2(punch, punch))
	draw_string_outline(_font16, Vector2(-w * 0.5, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0.1, 0.05, 0.02, a))
	draw_string(_font16, Vector2(-w * 0.5, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col.r, col.g, col.b, a).lerp(Color(1, 1, 1, a), flash))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sub: String = _cur["sub"]
	var w2 := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var p := Vector2(round(cx - w2 * 0.5), y + 11)
	draw_string_outline(_font, p, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.1, 0.05, 0.02, a))
	draw_string(_font, p, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, a))
