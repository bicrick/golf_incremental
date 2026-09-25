class_name TourBackdrop
extends CanvasLayer
## v8 — the painted sky and horizon behind the 3D ground, at native 480 px.
## Layers come from assets/sprites/tour/backdrops/<range>_<n>.png, back to
## front; a layer whose name ends in "clouds" drifts and wraps.

const DIR := "res://assets/sprites/tour/backdrops/"
const LAYER_NAMES := ["sky", "far", "clouds", "mid", "near"]
const DRIFT := {"clouds": 2.0}

var _root: Node2D
## What's right next to the rat (giant trunks, grass taller than him), drawn
## over the 3D world. Lives on its own layer above the range.
var foreground: CanvasLayer
var _fg_sprite: Sprite2D
var _layers: Array[Dictionary] = []
var _range_id := ""
var _fade: Tween
var _t := 0.0


func _ready() -> void:
	layer = -5
	_root = Node2D.new()
	add_child(_root)
	foreground = CanvasLayer.new()
	foreground.layer = 0
	add_child(foreground)
	_fg_sprite = Sprite2D.new()
	_fg_sprite.centered = false
	_fg_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/tour/tour_sway.gdshader")
	_fg_sprite.material = mat
	foreground.add_child(_fg_sprite)


func set_range(range_id: String) -> void:
	_range_id = range_id
	for l in _layers:
		(l["node"] as Node).queue_free()
	_layers.clear()
	var fg_path := "res://assets/sprites/tour/foreground/%s.png" % range_id
	_fg_sprite.texture = load(fg_path) if ResourceLoader.exists(fg_path) else null
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
	_fg_sprite.modulate.a = a


func fade_view(a: float, sec: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(_root, "modulate:a", a, sec)
	_fade.tween_property(_fg_sprite, "modulate:a", a, sec * 0.6)


func _process(delta: float) -> void:
	## The world moves with the music: clouds drift faster when it swells, the
	## sky brightens a touch on the beat, the foreground sways.
	_t += delta * (0.7 + Audio.energy * 1.2)
	var m := _fg_sprite.material as ShaderMaterial
	m.set_shader_parameter("energy", Audio.energy)
	m.set_shader_parameter("pulse", Audio.pulse)
	m.set_shader_parameter("t", _t)
	for l in _layers:
		if l["name"] == "sky":
			var b := 1.0 + Audio.pulse * 0.05 + Audio.energy * 0.03
			(l["node"] as Sprite2D).modulate = Color(b, b, b * 0.98)
	for l in _layers:
		var n: String = l["name"]
		if not DRIFT.has(n):
			continue
		var w := float(l["w"])
		var x := -fmod(_t * float(DRIFT[n]), w)
		(l["node"] as Sprite2D).position.x = floor(x)
		(l["twin"] as Sprite2D).position.x = floor(x + w)
