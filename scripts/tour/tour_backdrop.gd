class_name TourBackdrop
extends CanvasLayer
## v8 — the painted sky and horizon behind the 3D ground, at native 480 px.
## Layers come from assets/sprites/tour/backdrops/<range>_<n>.png, back to
## front; a layer whose name ends in "clouds" drifts and wraps.

const DIR := "res://assets/sprites/tour/backdrops/"
const LAYER_NAMES := ["sky", "far", "clouds", "mid", "near"]
const DRIFT := {"clouds": 2.0}

var _root: Node2D
var _layers: Array[Dictionary] = []
var _range_id := ""
var _fade: Tween
var _t := 0.0


func _ready() -> void:
	layer = -5
	_root = Node2D.new()
	add_child(_root)


func set_range(range_id: String) -> void:
	_range_id = range_id
	for l in _layers:
		(l["node"] as Node).queue_free()
	_layers.clear()
	var look := TourLooks.look(range_id)
	RenderingServer.set_default_clear_color(TourLooks.c(look["sky"]))
	for n in LAYER_NAMES:
		var path := DIR + "%s_%s.png" % [range_id, n]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_root.add_child(s)
		var entry := {"node": s, "name": n, "w": tex.get_width()}
		if DRIFT.has(n):
			## Second copy for seamless wrap.
			var s2 := Sprite2D.new()
			s2.texture = tex
			s2.centered = false
			s2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_root.add_child(s2)
			entry["twin"] = s2
		_layers.append(entry)


func set_view_alpha(a: float) -> void:
	_root.modulate.a = a


func fade_view(a: float, sec: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_root, "modulate:a", a, sec)


func _process(delta: float) -> void:
	_t += delta
	for l in _layers:
		var n: String = l["name"]
		if not DRIFT.has(n):
			continue
		var w := float(l["w"])
		var x := -fmod(_t * float(DRIFT[n]), w)
		(l["node"] as Sprite2D).position.x = floor(x)
		(l["twin"] as Sprite2D).position.x = floor(x + w)
