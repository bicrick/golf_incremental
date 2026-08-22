class_name SkyBirdFrames
extends RefCounted
## Idle / fly / eat frames from bird_sprite.png. Recolor + flip_h for variety.

const SHEET_PATH := "res://assets/sprites/ambient/bird_sprite.png"
const FRAME_SIZE := 16

const IDLE_ROW := 0
const IDLE_FRAME_COUNT := 2
const FLY_ROW := 1
const FLY_FRAME_COUNT := 8
const EAT_ROW := 2
const EAT_FRAME_COUNT := 3

## Random ambient pool is BLUE/SPARROW/RUST. GOLDEN is spawn-only (rare harvest click).
enum Species { BLUE, SPARROW, RUST, GOLDEN }

const SPECIES_COUNT := 3

const _BLUE_BODY := Color8(42, 48, 132)
const _BLUE_SHADE := Color8(34, 39, 96)
const _BLUE_HIGHLIGHT := Color8(65, 73, 240)
const _BLUE_WING := Color8(95, 132, 236)

const _SPARROW_MAP := {
	_BLUE_BODY: Color8(110, 78, 48),
	_BLUE_SHADE: Color8(72, 52, 34),
	_BLUE_HIGHLIGHT: Color8(168, 128, 82),
	_BLUE_WING: Color8(196, 160, 110),
}

const _RUST_MAP := {
	_BLUE_BODY: Color8(168, 48, 36),
	_BLUE_SHADE: Color8(112, 32, 28),
	_BLUE_HIGHLIGHT: Color8(220, 86, 58),
	_BLUE_WING: Color8(232, 120, 78),
}

const _GOLDEN_MAP := {
	_BLUE_BODY: Color8(198, 142, 28),
	_BLUE_SHADE: Color8(132, 88, 14),
	_BLUE_HIGHLIGHT: Color8(255, 228, 96),
	_BLUE_WING: Color8(236, 186, 58),
}

static var _sheet_image: Image
static var _frames_cache: Dictionary = {}


static func make_fly_frames(flip_h: bool = false) -> SpriteFrames:
	return make_frames(Species.BLUE, flip_h)


static func make_frames(species: int = Species.BLUE, flip_h: bool = false) -> SpriteFrames:
	var key := "%d_%s" % [species, flip_h]
	if _frames_cache.has(key):
		return _frames_cache[key]

	var sheet := _sheet()
	if sheet == null:
		return SpriteFrames.new()

	var frames := SpriteFrames.new()
	_add_row(frames, sheet, &"idle", IDLE_ROW, IDLE_FRAME_COUNT, 2.0, true, species, flip_h)
	_add_row(frames, sheet, &"fly", FLY_ROW, FLY_FRAME_COUNT, 10.0, true, species, flip_h)
	_add_row(frames, sheet, &"eat", EAT_ROW, EAT_FRAME_COUNT, 6.0, false, species, flip_h)

	_frames_cache[key] = frames
	return frames


static func _sheet() -> Image:
	if _sheet_image != null:
		return _sheet_image

	var tex := load(SHEET_PATH) as Texture2D
	if tex == null:
		push_error("SkyBirdFrames: missing texture at %s" % SHEET_PATH)
		return null

	_sheet_image = tex.get_image()
	if _sheet_image == null:
		push_error("SkyBirdFrames: could not read image at %s" % SHEET_PATH)
		return null
	if _sheet_image.get_format() != Image.FORMAT_RGBA8:
		_sheet_image.convert(Image.FORMAT_RGBA8)
	return _sheet_image


static func _add_row(
	frames: SpriteFrames,
	sheet: Image,
	anim: StringName,
	row: int,
	count: int,
	fps: float,
	loop: bool,
	species: int,
	flip_h: bool
) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	for index in count:
		frames.add_frame(anim, _make_frame_texture(sheet, row, index, species, flip_h))


static func _make_frame_texture(
	sheet: Image,
	row: int,
	index: int,
	species: int,
	flip_h: bool
) -> Texture2D:
	var region := Rect2i(index * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
	var frame_img := sheet.get_region(region).duplicate()
	if species != Species.BLUE:
		_recolor(frame_img, species)
	if flip_h:
		frame_img.flip_x()
	return ImageTexture.create_from_image(frame_img)


static func _recolor(img: Image, species: int) -> void:
	var palette := _palette_for(species)
	if palette.is_empty():
		return
	var width := img.get_width()
	var height := img.get_height()
	for y in height:
		for x in width:
			var pixel := img.get_pixel(x, y)
			if pixel.a < 0.02:
				continue
			var mapped := _mapped_blue(pixel, palette)
			if mapped.a > 0.0:
				img.set_pixel(x, y, mapped)


static func _palette_for(species: int) -> Dictionary:
	match species:
		Species.SPARROW:
			return _SPARROW_MAP
		Species.RUST:
			return _RUST_MAP
		Species.GOLDEN:
			return _GOLDEN_MAP
		_:
			return {}


static func _mapped_blue(pixel: Color, palette: Dictionary) -> Color:
	for src: Color in palette.keys():
		if _near(pixel, src, 0.05):
			var dst: Color = palette[src]
			dst.a = pixel.a
			return dst
	## Catch leftover body blues that are not exact palette keys.
	if pixel.b > pixel.r + 0.12 and pixel.b > pixel.g + 0.04:
		var t := clampf(pixel.v, 0.0, 1.0)
		var dark: Color = palette[_BLUE_SHADE]
		var light: Color = palette[_BLUE_WING]
		var mixed := dark.lerp(light, t)
		mixed.a = pixel.a
		return mixed
	return Color(0, 0, 0, 0)


static func _near(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol
