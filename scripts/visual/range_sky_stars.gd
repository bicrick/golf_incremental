class_name RangeSkyStars
extends Node3D
## Seeded pixel star field for the night sky — fades with DayNightPalette.star_visibility.

const STAR_COUNT := 52
const DISTANCE := 540.0
const RENDER_PRIORITY := -90
const SEED := 918273
const MIN_ELEVATION_DEG := 14.0
const MAX_ELEVATION_DEG := 68.0
const AZIMUTH_HALF_DEG := 58.0
const PIXEL_SIZE_MIN := 0.9
const PIXEL_SIZE_MAX := 2.6
const TWINKLE_FREQ := 0.35
const TWINKLE_AMP := 0.10

var _dirs: PackedVector3Array = PackedVector3Array()
var _phases: PackedFloat32Array = PackedFloat32Array()
var _brightness: PackedFloat32Array = PackedFloat32Array()
var _sprites: Array[Sprite3D] = []
var _visibility := 0.0
var _twinkle_time := 0.0
var _dot_texture: Texture2D


func setup() -> void:
	if not _sprites.is_empty():
		return
	_dot_texture = _make_dot_texture()
	_build_stars()
	visible = false
	set_process(true)


func update_for_viewer(viewer: Vector3, visibility: float) -> void:
	_visibility = clampf(visibility, 0.0, 1.0)
	if _visibility <= 0.01:
		visible = false
		return
	visible = true
	for i in _sprites.size():
		_sprites[i].global_position = viewer + _dirs[i] * DISTANCE
	_apply_modulates()


func _process(delta: float) -> void:
	if _visibility <= 0.01:
		return
	_twinkle_time += delta
	_apply_modulates()


func _build_stars() -> void:
	_dirs.clear()
	_phases.clear()
	_brightness.clear()
	_sprites.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for _i in STAR_COUNT:
		var elev := deg_to_rad(rng.randf_range(MIN_ELEVATION_DEG, MAX_ELEVATION_DEG))
		var az := deg_to_rad(rng.randf_range(-AZIMUTH_HALF_DEG, AZIMUTH_HALF_DEG))
		var dir := Vector3(sin(az) * cos(elev), sin(elev), -cos(az) * cos(elev)).normalized()
		_dirs.append(dir)
		_phases.append(rng.randf_range(0.0, TAU))
		_brightness.append(rng.randf_range(0.45, 1.0))

		var sprite := Sprite3D.new()
		sprite.name = "Star_%d" % _i
		sprite.texture = _dot_texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.double_sided = true
		sprite.transparent = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.render_priority = RENDER_PRIORITY
		sprite.pixel_size = rng.randf_range(PIXEL_SIZE_MIN, PIXEL_SIZE_MAX)
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_sprites.append(sprite)


func _apply_modulates() -> void:
	var global_twinkle := 1.0 + TWINKLE_AMP * sin(_twinkle_time * TWINKLE_FREQ * TAU)
	for i in _sprites.size():
		var flicker := 0.86 + 0.14 * sin(_twinkle_time * 2.1 + _phases[i])
		var alpha := clampf(_visibility * _brightness[i] * flicker * global_twinkle, 0.0, 1.0)
		_sprites[i].modulate = Color(0.92, 0.95, 1.0, alpha)


func _make_dot_texture() -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)
