extends SceneTree
## Builds res://assets/tilesets/range_iso.tres from PixelLab isometric tiles.
## Run: godot --headless --script res://tools/build_iso_tileset.gd

const OUT_PATH := "res://assets/tilesets/range_iso.tres"
const TERRAIN_DIR := "res://assets/sprites/iso/terrain/"
const FOREST_DIR := "res://assets/sprites/iso/transitions/grass_to_forest/"
const GRAVEL_DIR := "res://assets/sprites/iso/transitions/grass_to_gravel/"
const PATH_DIR := "res://assets/sprites/iso/transitions/grass_to_path/"

## Godot TERRAIN_MODE_MATCH_CORNERS peering bits (bitmask of corners):
## NW=1, NE=2, SW=4, SE=8  — matches PixelLab 16-tile corner set indices 0..15
## when tile_i means "corners matching terrain B in binary pattern i".
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

	# Terrain set 0: fairway(0), forest(1), gravel(2), path(3), rough(4), water(5)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	var terrain_names := ["fairway", "forest", "gravel", "path", "rough", "water"]
	for i in terrain_names.size():
		ts.add_terrain(0)
		ts.set_terrain_name(0, i, terrain_names[i])
		ts.set_terrain_color(0, i, _terrain_color(i))

	var source_id := 0
	source_id = _add_base_source(ts, source_id)
	source_id = _add_transition_source(ts, source_id, FOREST_DIR, 0, 1) # fairway -> forest
	source_id = _add_transition_source(ts, source_id, GRAVEL_DIR, 0, 2) # fairway -> gravel
	source_id = _add_transition_source(ts, source_id, PATH_DIR, 0, 3) # fairway -> path

	var err := ResourceSaver.save(ts, OUT_PATH)
	if err != OK:
		print("FAIL: could not save tileset: ", err)
		quit(1)
		return
	print("OK: wrote ", OUT_PATH, " sources=", ts.get_source_count())
	quit(0)


func _add_base_source(ts: TileSet, source_id: int) -> int:
	## Atlas: light [0..N), dark [N..2N), mat [2N..3N). Optional extras after.
	var lights := _fairway_variant_paths("light")
	var darks := _fairway_variant_paths("dark")
	var mats := _fairway_variant_paths("mat")
	if lights.is_empty() or darks.is_empty() or lights.size() != darks.size():
		print("WARN: fairway light/dark variants missing or mismatched at ", TERRAIN_DIR)
		return source_id
	if mats.size() != lights.size():
		print("WARN: fairway mat variants missing or mismatched at ", TERRAIN_DIR)
		return source_id
	var paths: Array[String] = []
	paths.append_array(lights)
	paths.append_array(darks)
	paths.append_array(mats)
	var fairway_count := paths.size()
	for i in range(2, 16):
		var extra := "%stile_%d.png" % [TERRAIN_DIR, i]
		var abs_extra := ProjectSettings.globalize_path(extra)
		if FileAccess.file_exists(abs_extra) or ResourceLoader.exists(extra):
			paths.append(extra)
	var packed := _pack_image_paths(paths)
	if packed.is_empty():
		print("WARN: no base terrain tiles at ", TERRAIN_DIR)
		return source_id
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
		if i < fairway_count:
			data.terrain_set = 0
			data.terrain = 0 # fairway (mats share fairway terrain; visual only)
			_set_all_corners(data, 0)
			continue
		# Optional solid extras after fairway block (legacy tile_N indices).
		var extra_i := i - fairway_count + 2
		match extra_i:
			2:
				data.terrain_set = 0
				data.terrain = 4 # rough
				_set_all_corners(data, 4)
			3:
				pass # dirt
			4:
				data.terrain_set = 0
				data.terrain = 2 # gravel solid
				_set_all_corners(data, 2)
			5:
				pass # sand
			6:
				data.terrain_set = 0
				data.terrain = 5 # water
				_set_all_corners(data, 5)
	ts.add_source(src, source_id)
	print(
		"OK: base source ", source_id,
		" region=", region,
		" tiles=", count,
		" fairway_variants=", variant_n,
		" bands=light+dark+mat"
	)
	return source_id + 1


func _fairway_variant_paths(band: String) -> Array[String]:
	## Prefer fairway_light_0.png…; fall back to fairway_light.png alone.
	var numbered: Array[String] = []
	for i in 16:
		var path := "%sfairway_%s_%d.png" % [TERRAIN_DIR, band, i]
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path) or ResourceLoader.exists(path):
			numbered.append(path)
		else:
			break
	if not numbered.is_empty():
		return numbered
	var single := "%sfairway_%s.png" % [TERRAIN_DIR, band]
	var abs_single := ProjectSettings.globalize_path(single)
	if FileAccess.file_exists(abs_single) or ResourceLoader.exists(single):
		return [single]
	return []


func _add_transition_source(
	ts: TileSet,
	source_id: int,
	dir: String,
	terrain_a: int,
	terrain_b: int
) -> int:
	var packed := _pack_tiles_horizontal(dir, 16)
	if packed.is_empty():
		print("WARN: no transition tiles at ", dir)
		return source_id
	var atlas: ImageTexture = packed["texture"]
	var region: Vector2i = packed["region"]
	var origin := _texture_origin_for_region(region)
	var src := TileSetAtlasSource.new()
	src.texture = atlas
	src.texture_region_size = region
	for i in 16:
		var coords := Vector2i(i, 0)
		src.create_tile(coords)
		var data := src.get_tile_data(coords, 0)
		data.texture_origin = origin
		data.terrain_set = 0
		# PixelLab mask: NW<<3|NE<<2|SW<<1|SE — set bit = first terrain (A).
		# CORNER_PEERING order: NW, NE, SW, SE → bit positions 3, 2, 1, 0.
		var bits := i
		var bit_order := [3, 2, 1, 0]
		var a_count := 0
		for bit_i in 4:
			if (bits >> bit_order[bit_i]) & 1:
				a_count += 1
		data.terrain = terrain_a if a_count >= 2 else terrain_b
		for bit_i in 4:
			var peer: int = CORNER_PEERING[bit_i]
			var t := terrain_a if ((bits >> bit_order[bit_i]) & 1) else terrain_b
			data.set_terrain_peering_bit(peer, t)
	ts.add_source(src, source_id)
	print("OK: transition source ", source_id, " from ", dir, " region=", region)
	return source_id + 1


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


func _pack_tiles_horizontal(dir: String, count: int) -> Dictionary:
	var paths: Array[String] = []
	for i in count:
		paths.append("%stile_%d.png" % [dir, i])
	return _pack_image_paths(paths)


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
		# Fallback via ResourceLoader after import
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


func _terrain_color(i: int) -> Color:
	match i:
		0:
			return Color(0.35, 0.75, 0.15)
		1:
			return Color(0.12, 0.35, 0.12)
		2:
			return Color(0.55, 0.55, 0.5)
		3:
			return Color(0.7, 0.7, 0.65)
		4:
			return Color(0.25, 0.55, 0.12)
		5:
			return Color(0.25, 0.55, 0.75)
		_:
			return Color.WHITE
