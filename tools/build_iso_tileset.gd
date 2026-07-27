extends SceneTree
## Builds res://assets/tilesets/range_iso.tres from iso fairway terrain PNGs.
## Run: godot --headless --script res://tools/build_iso_tileset.gd
##
## Fairway atlas: light [0..N), dark [N..2N), forest [2N..3N), mat [3N].

const OUT_PATH := "res://assets/tilesets/range_iso.tres"
const TERRAIN_DIR := "res://assets/sprites/iso/terrain/"

const CORNER_PEERING := [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	ts.tile_size = Vector2i(64, 32)

	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	ts.add_terrain(0)
	ts.set_terrain_name(0, 0, "fairway")
	ts.set_terrain_color(0, 0, Color(0.35, 0.75, 0.15))

	if _add_fairway_source(ts, 0) < 0:
		quit(1)
		return

	var err := ResourceSaver.save(ts, OUT_PATH)
	if err != OK:
		print("FAIL: could not save tileset: ", err)
		quit(1)
		return
	print("OK: wrote ", OUT_PATH, " sources=", ts.get_source_count())
	quit(0)


func _add_fairway_source(ts: TileSet, source_id: int) -> int:
	## Atlas: light [0..N), dark [N..2N), forest [2N..3N), mat [3N].
	var lights := _fairway_variant_paths("light")
	var darks := _fairway_variant_paths("dark")
	var forests := _fairway_variant_paths("forest")
	if (
		lights.is_empty()
		or darks.is_empty()
		or forests.is_empty()
		or lights.size() != darks.size()
		or lights.size() != forests.size()
	):
		print("FAIL: fairway light/dark/forest variants missing or mismatched at ", TERRAIN_DIR)
		return -1
	var mat_path := "%sfairway_mat.png" % TERRAIN_DIR
	var abs_mat := ProjectSettings.globalize_path(mat_path)
	if not FileAccess.file_exists(abs_mat) and not ResourceLoader.exists(mat_path):
		print("FAIL: missing authored mat ", mat_path)
		return -1
	var paths: Array[String] = []
	paths.append_array(lights)
	paths.append_array(darks)
	paths.append_array(forests)
	paths.append(mat_path)
	var packed := _pack_image_paths(paths)
	if packed.is_empty():
		print("FAIL: could not pack fairway tiles at ", TERRAIN_DIR)
		return -1
	var atlas: ImageTexture = packed["texture"]
	var region: Vector2i = packed["region"]
	var origin := _texture_origin_for_region(region)
	var src := TileSetAtlasSource.new()
	src.texture = atlas
	src.texture_region_size = region
	var count: int = packed["count"]
	var variant_n := lights.size()
	for i in count:
		var coords := Vector2i(i, 0)
		src.create_tile(coords)
		var data := src.get_tile_data(coords, 0)
		data.texture_origin = origin
		data.terrain_set = 0
		data.terrain = 0
		_set_all_corners(data, 0)
	ts.add_source(src, source_id)
	print(
		"OK: fairway source ", source_id,
		" region=", region,
		" tiles=", count,
		" variants=", variant_n,
		" bands=light+dark+forest+mat"
	)
	return source_id + 1


func _fairway_variant_paths(band: String) -> Array[String]:
	## Numbered variants only: fairway_light_0.png…
	var numbered: Array[String] = []
	for i in 16:
		var path := "%sfairway_%s_%d.png" % [TERRAIN_DIR, band, i]
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path) or ResourceLoader.exists(path):
			numbered.append(path)
		else:
			break
	return numbered


## Flat 2:1 art (e.g. 64x32) matches tile_size aspect — no origin shift.
## Only shift when residual vertical padding remains above the diamond.
func _texture_origin_for_region(region: Vector2i) -> Vector2i:
	if region.x > 0 and region.x * 8 == region.y * 16:
		return Vector2i(0, 0)
	var extra_y := region.y - 8
	return Vector2i(0, maxi(extra_y / 2, 0))


func _set_all_corners(data: TileData, terrain: int) -> void:
	for peer in CORNER_PEERING:
		data.set_terrain_peering_bit(peer, terrain)


func _pack_image_paths(paths: Array[String]) -> Dictionary:
	var images: Array[Image] = []
	var tw := 0
	var th := 0
	for path in paths:
		var abs_path := ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(abs_path) and not ResourceLoader.exists(path):
			return {}
		var img := _load_image(path)
		if img == null:
			return {}
		if tw == 0:
			tw = img.get_width()
			th = img.get_height()
		images.append(img)
	if images.is_empty():
		return {}
	var count := images.size()
	var sheet := Image.create(tw * count, th, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for i in count:
		sheet.blit_rect(images[i], Rect2i(0, 0, tw, th), Vector2i(i * tw, 0))
	return {
		"texture": ImageTexture.create_from_image(sheet),
		"region": Vector2i(tw, th),
		"count": count,
	}


func _load_image(path: String) -> Image:
	var abs_path := ProjectSettings.globalize_path(path)
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				img = tex.get_image()
			else:
				return null
		else:
			return null
	return _normalize_flat_iso_canvas(img)


## Independent PixelLab tiles are often 64x64 with a flat 64x32 diamond
## padded by transparency (rows 16..48). Tilesets already emit 64x32.
func _normalize_flat_iso_canvas(img: Image) -> Image:
	if img == null:
		return null
	if img.get_width() == 64 and img.get_height() == 64:
		return img.get_region(Rect2i(0, 16, 64, 32))
	return img
