class_name FortuneRoom
extends Control
## v9 base for the 2D rooms (green, cards, dice). A room keeps running while
## you're elsewhere — its helpers never stop — and only draws when shown.

const AREA := Rect2(4, 36, 322, 230)

var room_id := ""
var t := 0.0
var font: Font
var font16: Font
var pops: Array[Dictionary] = [] ## floating text {pos, text, color, t, big}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	position = AREA.position
	size = AREA.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = PixelFont.font_for_size(8)
	font16 = PixelFont.font_for_size(16)
	visible = false
	setup()


func setup() -> void:
	pass


func is_open() -> bool:
	return Game.rooms.get(room_id, false)


## Room logic, every frame while unlocked (visible or not).
func tick(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	t += delta
	for p in pops:
		p["t"] = float(p["t"]) + delta
	pops = pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < float(p["life"]))
	if is_open():
		tick(delta)
	if visible:
		queue_redraw()


func pop(pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	if not visible:
		return
	pops.append({"pos": pos, "text": text, "color": color, "t": 0.0, "big": big, "life": 1.5 if big else 0.9})


func draw_pops() -> void:
	for p in pops:
		var k := float(p["t"])
		var life := float(p["life"])
		var a := clampf((life - k) / 0.3, 0.0, 1.0)
		var col: Color = p["color"]
		col.a *= a
		var sz := 16 if p["big"] else 8
		var f := font16 if p["big"] else font
		var text: String = p["text"]
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var pos := ((p["pos"] as Vector2) + Vector2(-w * 0.5, -k * 20.0)).round()
		pos.x = clampf(pos.x, 2, size.x - w - 2)
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 3 if sz == 8 else 4, Color(0.08, 0.06, 0.1, a))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func text(pos: Vector2, s: String, color: Color, sz: int = 8, outline: Color = Color(0.08, 0.06, 0.1)) -> void:
	var f := font16 if sz == 16 else font
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 3 if sz == 8 else 4, outline)
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)


func text_c(center_x: float, y: float, s: String, color: Color, sz: int = 8) -> void:
	var f := font16 if sz == 16 else font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	text(Vector2(round(center_x - w * 0.5), y), s, color, sz)


## Header strip: room name and a line of live numbers.
func draw_header(title: String, info: String) -> void:
	draw_rect(Rect2(0, 0, size.x, 16), Color(0.1, 0.08, 0.12, 0.8))
	text(Vector2(5, 11), title, Color(1.0, 0.9, 0.6))
	TinyText.draw(self, Vector2(size.x - TinyText.width(info) - 5, 6), info, Color(0.85, 1.0, 0.8))
