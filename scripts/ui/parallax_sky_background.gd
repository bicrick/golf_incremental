extends Control
## Full-screen parallax cloud sky — smooth sub-pixel bob via sin waves in _process.

const SKY_DIR := "res://assets/imported/background/parallax_sky/"
const BOB_MARGIN_X := 8.0
const BOB_MARGIN_Y := 4.0
const BOB_FREQ := 0.42

const LAYER_FILES: Array[String] = [
	"Layer_4.png",
	"Layer_3.png",
	"Layer_2.png",
	"Layer_1.png",
]
## Back → front: front layers bob more (depth parallax). Subtle amplitudes only.
const BOB_AMP_X: Array[float] = [0.25, 0.4, 0.55, 0.75]
const BOB_AMP_Y: Array[float] = [0.35, 0.55, 0.75, 1.0]
const BOB_PHASE_X: Array[float] = [0.0, 1.4, 2.8, 4.2]
const BOB_PHASE_Y: Array[float] = [0.9, 2.1, 3.5, 5.0]

var _layers: Array[TextureRect] = []
var _base_positions: Array[Vector2] = []
var _bob_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layers()


func layer_count() -> int:
	return _layers.size()


func _build_layers() -> void:
	for child in get_children():
		child.free()
	_layers.clear()
	_base_positions.clear()

	var viewport_size := get_viewport_rect().size

	for index in LAYER_FILES.size():
		var slot := Control.new()
		slot.name = "Layer%d" % (LAYER_FILES.size() - index)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.clip_contents = true
		add_child(slot)

		var texture: Texture2D = load(SKY_DIR.path_join(LAYER_FILES[index]))
		var layer := TextureRect.new()
		layer.name = "Sprite"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.texture = texture
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

		var tex_size := texture.get_size()
		var cover_scale := maxf(
			(viewport_size.x + BOB_MARGIN_X * 2.0) / tex_size.x,
			(viewport_size.y + BOB_MARGIN_Y * 2.0) / tex_size.y
		)
		var layer_size := tex_size * cover_scale
		layer.custom_minimum_size = layer_size
		layer.size = layer_size

		var base_pos := Vector2(
			(viewport_size.x - layer_size.x) * 0.5,
			(viewport_size.y - layer_size.y) * 0.5
		)
		layer.position = base_pos
		slot.add_child(layer)
		_layers.append(layer)
		_base_positions.append(base_pos)


func _process(delta: float) -> void:
	_bob_time += delta
	var t := _bob_time * BOB_FREQ
	for index in _layers.size():
		var layer := _layers[index]
		var drift := Vector2(
			sin(t + BOB_PHASE_X[index]) * BOB_AMP_X[index],
			sin(t * 0.87 + BOB_PHASE_Y[index]) * BOB_AMP_Y[index]
		)
		layer.position = _base_positions[index] + drift
