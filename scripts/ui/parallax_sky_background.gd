extends Control
## Full-screen parallax cloud sky — smooth sub-pixel bob via sin waves in _process.
## Optional day/night tint via DayNightPalette (menus share mood with the range).
## Layer_4 (solid blue fill) is omitted; a palette-driven ColorRect fills the sky instead.

const SKY_DIR := "res://assets/imported/background/parallax_sky/"
const VIEWPORT_SIZE := Vector2(480.0, 270.0)
const BOB_MARGIN_X := 8.0
const BOB_MARGIN_Y := 4.0
const BOB_FREQ := 0.42
const DEFAULT_CYCLE_TIME := 60.0
## How hard day/night canvas_modulate hits the cloud sprites (1.0 = full).
const CLOUD_TINT_STRENGTH := 0.95
## Extra darken/cool on night so white cloud art still reads as shaded.
const CLOUD_NIGHT_DARKEN := 0.22

## Cloud layers only (back → front). Former Layer_4 was a solid blue plate.
const LAYER_FILES: Array[String] = [
	"Layer_3.png",
	"Layer_2.png",
	"Layer_1.png",
]
## Back → front: front layers bob more (depth parallax). Subtle amplitudes only.
const BOB_AMP_X: Array[float] = [0.4, 0.55, 0.75]
const BOB_AMP_Y: Array[float] = [0.55, 0.75, 1.0]
const BOB_PHASE_X: Array[float] = [1.4, 2.8, 4.2]
const BOB_PHASE_Y: Array[float] = [2.1, 3.5, 5.0]
## Back → front: farther clouds take more atmosphere shading.
const LAYER_SHADE_WEIGHT: Array[float] = [1.0, 0.92, 0.84]

var _sky_fill: ColorRect
var _layers: Array[TextureRect] = []
var _base_positions: Array[Vector2] = []
var _bob_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layers()
	apply_cycle_time(DEFAULT_CYCLE_TIME)
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _on_resized() -> void:
	_rebuild_layer_geometry()


func layer_count() -> int:
	return _layers.size()


func apply_cycle_time(cycle_time: float) -> void:
	var snap := DayNightPalette.sample_at(cycle_time)
	if _sky_fill:
		_sky_fill.color = snap.sky
	_apply_cloud_tints(snap.canvas_modulate, DayNightPalette.day_light_factor(cycle_time))


func apply_atmosphere_tint(tint: Color) -> void:
	_apply_cloud_tints(tint, 1.0)


func _apply_cloud_tints(atmosphere: Color, day_factor: float) -> void:
	var night_factor := 1.0 - clampf(day_factor, 0.0, 1.0)
	for index in _layers.size():
		var weight: float = LAYER_SHADE_WEIGHT[index] if index < LAYER_SHADE_WEIGHT.size() else 1.0
		var strength := CLOUD_TINT_STRENGTH * weight
		var tinted := Color.WHITE.lerp(atmosphere, strength)
		## Pull brightness down at night so bright cloud PNGs don't stay daylight-white.
		var shade := 1.0 - CLOUD_NIGHT_DARKEN * night_factor * weight
		_layers[index].modulate = Color(tinted.r * shade, tinted.g * shade, tinted.b * shade, 1.0)


func _viewport_size() -> Vector2:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return VIEWPORT_SIZE
	return s


func _build_layers() -> void:
	for child in get_children():
		child.free()
	_layers.clear()
	_base_positions.clear()
	_sky_fill = null

	_sky_fill = ColorRect.new()
	_sky_fill.name = "SkyFill"
	_sky_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_fill.color = DayNightPalette.sample_at(DEFAULT_CYCLE_TIME).sky
	add_child(_sky_fill)

	for index in LAYER_FILES.size():
		var slot := Control.new()
		## Keep Layer1/2/3 names matching asset numbers (Layer_1 = front).
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
		slot.add_child(layer)
		_layers.append(layer)
		_base_positions.append(Vector2.ZERO)

	_rebuild_layer_geometry()


func _rebuild_layer_geometry() -> void:
	var vp := _viewport_size()
	for index in _layers.size():
		var layer := _layers[index]
		var texture := layer.texture
		if texture == null:
			continue
		var tex_size := texture.get_size()
		var cover_scale := maxf(
			(vp.x + BOB_MARGIN_X * 2.0) / tex_size.x,
			(vp.y + BOB_MARGIN_Y * 2.0) / tex_size.y
		)
		var layer_size := tex_size * cover_scale
		layer.custom_minimum_size = layer_size
		layer.size = layer_size
		var base_pos := Vector2((vp.x - layer_size.x) * 0.5, (vp.y - layer_size.y) * 0.5)
		layer.position = base_pos
		_base_positions[index] = base_pos


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
