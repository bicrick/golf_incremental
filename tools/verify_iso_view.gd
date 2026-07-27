extends SceneTree
## Headless isometric build-view checks.
## godot --headless --script res://tools/verify_iso_view.gd

const TILESET_PATH := "res://assets/tilesets/range_iso.tres"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_iso_grid() and ok
	ok = _check_tileset() and ok
	ok = _check_map_to_local_agreement() and ok
	ok = _check_placement_model() and ok
	ok = _check_picker_ground_projection() and ok
	ok = _check_duff_in_front_alignment() and ok
	ok = await _check_iso_view_scene() and ok
	ok = await _check_fairway_stripes_and_atmosphere() and ok
	ok = await _check_build_toggle() and ok
	ok = await _check_fairway_only_and_pan() and ok
	ok = await _check_camera_memory_and_key_pan() and ok
	ok = await _check_bay_mats() and ok
	ok = _check_fairway_native_flat() and ok
	ok = _check_fairway_palette_colors() and ok
	ok = _check_fairway_dark_is_tint() and ok
	ok = _check_fairway_seam_flat() and ok
	ok = _check_litter_sprite_scale() and ok
	ok = _check_fairway_variant_assets() and ok
	ok = await _check_iso_harvest_litter() and ok
	ok = await _check_iso_picker_hit_alignment() and ok
	ok = await _check_iso_actor_mirrors() and ok
	ok = await _check_iso_flight_mirror() and ok

	if ok:
		print("iso_view_ok=true")
		quit(0)
	else:
		print("iso_view_ok=false")
		quit(1)


func _check_iso_grid() -> bool:
	var cell := Vector2i(9, 5)
	var yards := IsoGrid.yards_from_cell(cell)
	var back := IsoGrid.cell_from_yards(yards)
	if back != cell:
		print("FAIL: yards/cell round-trip ", cell, " -> ", yards, " -> ", back)
		return false
	var iso_cell := IsoGrid.iso_cell_from_range_cell(cell)
	var expected_iso := Vector2i(9, RangeGrid.GRID_DEPTH_CELLS - 1 - 5)
	if iso_cell != expected_iso:
		print("FAIL: depth-flipped iso cell expected ", expected_iso, " got ", iso_cell)
		return false
	var range_back := IsoGrid.range_cell_from_iso_cell(iso_cell)
	if range_back != cell:
		print("FAIL: range/iso round-trip ", cell, " -> ", iso_cell, " -> ", range_back)
		return false
	var px := IsoGrid.iso_px_from_cell(iso_cell)
	var cell_back := IsoGrid.cell_from_iso_px(px + Vector2(0.1, 0.1))
	if cell_back != iso_cell:
		print("FAIL: iso_px/cell round-trip ", iso_cell, " -> ", px, " -> ", cell_back)
		return false
	# Downrange (increasing RangeGrid row) must move toward screen top-right.
	var tee_px := IsoGrid.iso_px_from_cell(IsoGrid.iso_cell_from_range_cell(Vector2i(9, 5)))
	var far_px := IsoGrid.iso_px_from_cell(IsoGrid.iso_cell_from_range_cell(Vector2i(9, 50)))
	var delta := far_px - tee_px
	if delta.x <= 0.0 or delta.y >= 0.0:
		print("FAIL: downrange should aim top-right, delta=", delta)
		return false
	if IsoGrid.TILE_PX != Vector2i(64, 32):
		print("FAIL: TILE_PX expected 64x32 got ", IsoGrid.TILE_PX)
		return false
	if IsoGrid.SUBCELLS != 1:
		print("FAIL: SUBCELLS expected 1 got ", IsoGrid.SUBCELLS)
		return false
	if IsoGrid.iso_width_cells() != RangeGrid.GRID_WIDTH_CELLS:
		print("FAIL: iso width expected ", RangeGrid.GRID_WIDTH_CELLS)
		return false
	if IsoGrid.iso_depth_cells() != RangeGrid.GRID_DEPTH_CELLS:
		print("FAIL: iso depth expected ", RangeGrid.GRID_DEPTH_CELLS)
		return false
	print("OK: IsoGrid conversions + depth flip toward top-right")
	return true


func _check_picker_ground_projection() -> bool:
	## A world-XZ circle must project to a flattened ellipse on 64x32 tiles,
	## not a screen-space circle (major axis wider than minor).
	var ground := IsoGrid.yards_from_cell(RangeGrid.PLAYER_CELL)
	var center_px := IsoGrid.iso_px_from_yards(ground)
	var radius := 1.0
	var max_abs_x := 0.0
	var max_abs_y := 0.0
	for i in 48:
		var a := TAU * float(i) / 48.0
		var edge := IsoGrid.iso_px_from_yards(
			ground + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		)
		var d := edge - center_px
		max_abs_x = maxf(max_abs_x, absf(d.x))
		max_abs_y = maxf(max_abs_y, absf(d.y))
	if max_abs_x < 1.0 or max_abs_y < 1.0:
		print("FAIL: picker projection degenerate extents x=", max_abs_x, " y=", max_abs_y)
		return false
	var aspect := max_abs_x / max_abs_y
	## 64x32 diamond → ~2:1 screen ellipse for a ground circle.
	if aspect < 1.6 or aspect > 2.5:
		print("FAIL: picker projection aspect expected ~2 got ", aspect)
		return false
	var closed := IsoGrid.iso_px_radii_from_yards(radius)
	if absf(closed.x - max_abs_x) > 0.01 or absf(closed.y - max_abs_y) > 0.01:
		print(
			"FAIL: iso_px_radii_from_yards mismatch closed=", closed,
			" sampled=(", max_abs_x, ", ", max_abs_y, ")"
		)
		return false
	var dash_cycle := IsoPickerIndicator.DASH_ON + IsoPickerIndicator.DASH_OFF
	var dash_count := IsoPickerIndicator.SEGMENTS / dash_cycle
	if dash_count != 24:
		print(
			"FAIL: picker dash count expected 24 got ", dash_count,
			" (SEGMENTS=", IsoPickerIndicator.SEGMENTS, " cycle=", dash_cycle, ")"
		)
		return false
	print(
		"OK: picker ground circle projects to ellipse aspect=", snappedf(aspect, 0.01),
		" closed=", closed, " dashes=", dash_count
	)
	return true


func _check_tileset() -> bool:
	if not ResourceLoader.exists(TILESET_PATH):
		print("FAIL: missing tileset ", TILESET_PATH)
		return false
	var ts := load(TILESET_PATH) as TileSet
	if ts == null:
		print("FAIL: tileset failed to load")
		return false
	if ts.tile_shape != TileSet.TILE_SHAPE_ISOMETRIC:
		print("FAIL: tile_shape not ISOMETRIC")
		return false
	if ts.tile_layout != TileSet.TILE_LAYOUT_DIAMOND_DOWN:
		print("FAIL: tile_layout not DIAMOND_DOWN")
		return false
	if ts.tile_size != Vector2i(64, 32):
		print("FAIL: tile_size expected 64x32 got ", ts.tile_size)
		return false
	if ts.get_terrain_sets_count() < 1:
		print("FAIL: expected terrain set 0")
		return false
	if ts.get_terrain_set_mode(0) != TileSet.TERRAIN_MODE_MATCH_CORNERS:
		print("FAIL: terrain set 0 not MATCH_CORNERS")
		return false
	if ts.get_terrains_count(0) < 1:
		print("FAIL: expected fairway terrain")
		return false
	if ts.get_source_count() < 1:
		print("FAIL: expected fairway source, got ", ts.get_source_count())
		return false
	var src0 := ts.get_source(0) as TileSetAtlasSource
	var n := IsoView.FAIRWAY_VARIANT_COUNT
	if src0 == null:
		print("FAIL: base source missing")
		return false
	## light + dark + single mat
	for i in n * 2 + 1:
		if not src0.has_tile(Vector2i(i, 0)):
			print("FAIL: base source missing fairway atlas tile ", Vector2i(i, 0))
			return false
	if not ResourceLoader.exists("res://assets/sprites/iso/terrain/fairway_mat.png"):
		print("FAIL: missing fairway_mat.png")
		return false
	if not _atlas_mat_matches_fairway_mat_png(src0):
		return false
	print("OK: tileset shape/layout/terrains sources=", ts.get_source_count(), " fairway_variants=", n)
	return true


## Atlas tile at FAIRWAY_ATLAS_MAT must be the authored fairway_mat.png (white lip included).
func _atlas_mat_matches_fairway_mat_png(src0: TileSetAtlasSource) -> bool:
	var tex := src0.texture as Texture2D
	if tex == null:
		print("FAIL: fairway atlas has no texture")
		return false
	var atlas_img := tex.get_image()
	if atlas_img == null:
		print("FAIL: fairway atlas texture has no image")
		return false
	var mat_coords := IsoView.FAIRWAY_ATLAS_MAT
	if not src0.has_tile(mat_coords):
		print("FAIL: missing mat atlas tile ", mat_coords)
		return false
	var region := src0.get_tile_texture_region(mat_coords)
	var atlas_mat := atlas_img.get_region(region)
	var src_mat := Image.new()
	var abs_path := ProjectSettings.globalize_path("res://assets/sprites/iso/terrain/fairway_mat.png")
	if src_mat.load(abs_path) != OK:
		print("FAIL: could not load fairway_mat.png for atlas compare")
		return false
	if atlas_mat.get_size() != src_mat.get_size():
		print(
			"FAIL: atlas mat size ", atlas_mat.get_size(),
			" != fairway_mat.png ", src_mat.get_size()
		)
		return false
	var mismatch := 0
	var white := 0
	for y in atlas_mat.get_height():
		for x in atlas_mat.get_width():
			var a := atlas_mat.get_pixel(x, y)
			var b := src_mat.get_pixel(x, y)
			if a != b:
				mismatch += 1
			if a.a > 0.5 and a.r > 0.78 and a.g > 0.78 and a.b > 0.78:
				white += 1
	if mismatch > 0:
		print("FAIL: atlas mat tile != fairway_mat.png mismatches=", mismatch)
		return false
	if white < 1:
		print("FAIL: atlas mat tile missing white lip from fairway_mat.png")
		return false
	print("OK: atlas mat tile matches fairway_mat.png (white_lip_px=", white, ")")
	return true


func _check_map_to_local_agreement() -> bool:
	if not ResourceLoader.exists(TILESET_PATH):
		return false
	var layer := TileMapLayer.new()
	root.add_child(layer)
	layer.tile_set = load(TILESET_PATH) as TileSet
	var ok := true
	for cell in [Vector2i(0, 0), Vector2i(9, 5), Vector2i(3, 7), Vector2i(18, 199)]:
		var from_grid := IsoGrid.iso_px_from_cell_raw(cell)
		var from_map := layer.map_to_local(cell)
		if not from_grid.is_equal_approx(from_map):
			print("FAIL: map_to_local mismatch cell=", cell, " grid=", from_grid, " map=", from_map)
			ok = false
		## Shifted helpers: iso_px + view origin == raw map_to_local.
		var shifted := IsoGrid.iso_px_from_cell(cell)
		if not (shifted + IsoGrid.view_origin_px_raw()).is_equal_approx(from_map):
			print("FAIL: view-origin shift mismatch cell=", cell, " shifted=", shifted)
			ok = false
	layer.queue_free()
	if ok:
		print("OK: IsoGrid matches TileMapLayer.map_to_local (+ view origin)")
	return ok


func _check_placement_model() -> bool:
	var model := IsoWorldModel.new()
	var player_iso := IsoGrid.iso_cell_from_range_cell(RangeGrid.PLAYER_CELL)
	var ratina_iso := IsoGrid.iso_cell_from_range_cell(RangeGrid.RATINA_CELL)
	if model.can_place(&"pine_tree", player_iso):
		print("FAIL: player bay iso cell should be reserved")
		return false
	if model.can_place(&"pine_tree", ratina_iso):
		print("FAIL: ratina bay iso cell should be reserved")
		return false
	var free_cell := IsoGrid.iso_cell_from_range_cell(Vector2i(2, 10))
	if not model.can_place(&"pine_tree", free_cell):
		print("FAIL: expected free cell placeable")
		return false
	var pid := model.place(&"pine_tree", free_cell)
	if pid == &"":
		print("FAIL: place returned empty id")
		return false
	if model.can_place(&"pine_tree", free_cell):
		print("FAIL: occupied cell should reject")
		return false
	var data := model.serialize()
	var model2 := IsoWorldModel.new()
	model2.deserialize(data)
	if model2.all_placements().size() != model.all_placements().size():
		print("FAIL: serialize round-trip count mismatch")
		return false
	print("OK: placement model + serialize")
	return true


func _check_iso_view_scene() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var iso := main.get_node_or_null("IsoView") as Node2D
	var range_view := main.get_node_or_null("RangeView") as Node3D
	if iso == null:
		print("FAIL: Main missing IsoView")
		main.queue_free()
		return false
	if iso.visible:
		print("FAIL: IsoView should start hidden")
		main.queue_free()
		return false
	if range_view == null:
		print("FAIL: Main missing RangeView")
		main.queue_free()
		return false
	var cam := iso.get_node_or_null("Camera2D") as Camera2D
	var controller := iso.get_node_or_null("CameraController") as IsoCameraController
	if cam == null or controller == null:
		print("FAIL: IsoView missing camera pieces")
		main.queue_free()
		return false
	controller.setup(cam)
	controller.set_enabled(true)
	var expected_steps: Array[float] = [0.5, 1.0, 2.0, 3.0, 4.0]
	if IsoCameraController.ZOOM_STEPS != expected_steps:
		print("FAIL: zoom steps expected ", expected_steps, " got ", IsoCameraController.ZOOM_STEPS)
		main.queue_free()
		return false
	if not is_equal_approx(controller.get_zoom_level(), 1.0):
		print("FAIL: default zoom expected 1.0 got ", controller.get_zoom_level())
		main.queue_free()
		return false
	if cam.position.distance_to(Vector2.ZERO) > 1.0:
		print("FAIL: camera start expected view origin (0,0) got ", cam.position)
		main.queue_free()
		return false
	var origin_px := IsoGrid.iso_px_from_yards(IsoGrid.view_origin_yards())
	if origin_px.distance_to(Vector2.ZERO) > 0.5:
		print("FAIL: view origin yards should map to (0,0) got ", origin_px)
		main.queue_free()
		return false
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	controller.consume_zoom_event(wheel)
	if not is_equal_approx(controller.get_zoom_level(), 2.0):
		print("FAIL: zoom not stepped 1.0 -> 2.0 got ", controller.get_zoom_level())
		main.queue_free()
		return false
	print("OK: IsoView scene wired + zoom steps + camera on view origin")
	main.queue_free()
	return true


func _check_fairway_stripes_and_atmosphere() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var iso := main.get_node_or_null("IsoView") as IsoView
	if iso == null:
		print("FAIL: IsoView missing for stripe check")
		main.queue_free()
		return false
	iso.set_active(true)
	await process_frame
	var terrain := iso.get_node("Terrain") as TileMapLayer
	var w := RangeGrid.GRID_WIDTH_CELLS
	var d := RangeGrid.GRID_DEPTH_CELLS
	var n := IsoView.FAIRWAY_VARIANT_COUNT
	if terrain.get_used_cells().size() != w * d:
		print("FAIL: expected painted extent exactly ", w * d, " got ", terrain.get_used_cells().size())
		main.queue_free()
		return false
	var mat_cells: Dictionary = {}
	for c in [RangeGrid.PLAYER_CELL, RangeGrid.RATINA_CELL]:
		mat_cells[c] = true
	for c in RangeGrid.empty_bay_cells_on_player_row():
		mat_cells[c] = true
	var seen_variants: Dictionary = {}
	for col in mini(8, w):
		for row in mini(24, d):
			var range_cell := Vector2i(col, row)
			var iso_cell := IsoGrid.iso_cell_from_range_cell(range_cell)
			var atlas := terrain.get_cell_atlas_coords(iso_cell)
			if mat_cells.has(range_cell):
				var mat_expected := IsoView.fairway_mat_atlas_for_cell(col, row)
				if atlas != mat_expected:
					print(
						"FAIL: mat atlas col=", col, " row=", row,
						" expected=", mat_expected, " got=", atlas
					)
					main.queue_free()
					return false
				continue
			var expected := IsoView.fairway_atlas_for_cell(col, row)
			if atlas != expected:
				print(
					"FAIL: fairway atlas col=", col, " row=", row,
					" expected=", expected, " got=", atlas
				)
				main.queue_free()
				return false
			var is_dark := atlas.x >= n and atlas.x < n * 2
			if is_dark != ((col & 1) == 1):
				print("FAIL: stripe band wrong col=", col, " atlas=", atlas)
				main.queue_free()
				return false
			seen_variants[atlas.x % n] = true
	if seen_variants.size() < 2:
		print("FAIL: expected scattered fairway variants, saw ", seen_variants.keys())
		main.queue_free()
		return false
	iso.apply_atmosphere(60.0)
	var day_mod := terrain.modulate
	iso.apply_atmosphere(0.0)
	var night_mod := terrain.modulate
	if day_mod.is_equal_approx(night_mod):
		print("FAIL: day/night terrain modulate unchanged ", day_mod)
		main.queue_free()
		return false
	print(
		"OK: fairway stripes + variants=", seen_variants.size(),
		" + atmosphere + extent ", w, "x", d
	)
	main.queue_free()
	return true


func _check_build_toggle() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var title := main.get_node_or_null("TitleScreen") as CanvasLayer
	if title:
		title.visible = false
	main.get_node("UI").visible = true
	main.get_node("RangeView").visible = true
	if not main.has_method(&"set_build_view"):
		print("FAIL: Main missing set_build_view")
		main.queue_free()
		return false
	main.set_build_view(true)
	await process_frame
	var iso := main.get_node("IsoView") as Node2D
	var range_view := main.get_node("RangeView") as Node3D
	if not iso.visible or range_view.visible:
		print("FAIL: set_build_view(true) did not show IsoView")
		main.queue_free()
		return false
	main.set_build_view(false)
	await process_frame
	if iso.visible or not range_view.visible:
		print("FAIL: set_build_view(false) did not restore RangeView")
		main.queue_free()
		return false
	var icon_bar := main.get_node_or_null("UI/UIRoot/GameplayChrome/IconBar")
	if icon_bar == null or icon_bar.get_node_or_null("TopRight/BuildWrap/BuildButton") == null:
		print("FAIL: Build button missing from IconBar")
		main.queue_free()
		return false
	print("OK: build toggle + HUD button")
	main.queue_free()
	return true


func _check_fairway_only_and_pan() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var iso := main.get_node_or_null("IsoView") as IsoView
	if iso == null:
		print("FAIL: IsoView missing for fairway-only check")
		main.queue_free()
		return false
	if iso.get_node_or_null("TreeBorder") != null:
		print("FAIL: TreeBorder node should be removed")
		main.queue_free()
		return false
	iso.set_active(true)
	await process_frame
	var terrain := iso.get_node("Terrain") as TileMapLayer
	var w := RangeGrid.GRID_WIDTH_CELLS
	var d := RangeGrid.GRID_DEPTH_CELLS
	var used := terrain.get_used_cells()
	if used.size() != w * d:
		print("FAIL: expected fairway-only cell count ", w * d, " got ", used.size())
		main.queue_free()
		return false
	for cell in used:
		var range_cell := IsoGrid.range_cell_from_iso_cell(cell)
		if (
			range_cell.x < 0
			or range_cell.x >= w
			or range_cell.y < 0
			or range_cell.y >= d
		):
			print("FAIL: terrain cell outside fairway grid ", cell, " -> ", range_cell)
			main.queue_free()
			return false
	var placement := iso.get_node("PlacementController") as PlacementController
	if placement.get_active_catalog_id() != &"":
		print("FAIL: default catalog tool should be empty for pan")
		main.queue_free()
		return false
	var cam_ctrl := iso.get_node("CameraController") as IsoCameraController
	cam_ctrl.set_enabled(true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100, 100)
	cam_ctrl.consume_pan_drag_event(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100, 100) + Vector2(20, 0)
	cam_ctrl.consume_pan_drag_event(motion)
	if not cam_ctrl.is_dragging():
		print("FAIL: drag past threshold should pan")
		main.queue_free()
		return false
	var idx0 := cam_ctrl.get_zoom_index()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	cam_ctrl.consume_zoom_event(wheel)
	var expected_z: float = IsoCameraController.ZOOM_STEPS[
		clampi(idx0 + 1, 0, IsoCameraController.ZOOM_STEPS.size() - 1)
	]
	if not is_equal_approx(cam_ctrl.get_zoom_level(), expected_z):
		print("FAIL: zoom not stepped during fairway/pan check")
		main.queue_free()
		return false
	print("OK: fairway-only terrain ", w, "x", d, " + pan/zoom")
	main.queue_free()
	return true


func _check_camera_memory_and_key_pan() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var iso := main.get_node_or_null("IsoView") as IsoView
	if iso == null:
		print("FAIL: IsoView missing for camera memory check")
		main.queue_free()
		return false
	iso.set_mode(IsoView.Mode.BUILD)
	await process_frame
	var cam := iso.get_node("Camera2D") as Camera2D
	var cam_ctrl := iso.get_node("CameraController") as IsoCameraController
	cam_ctrl.set_enabled(true)
	if cam_ctrl.key_pan_speed_px <= 0.0:
		print("FAIL: key_pan_speed_px should be positive")
		main.queue_free()
		return false
	var before := cam.position
	cam_ctrl.apply_key_pan(Vector2(1.0, 0.0), 0.25)
	if cam.position.is_equal_approx(before):
		print("FAIL: key pan did not move camera")
		main.queue_free()
		return false
	var remembered := cam.position
	var remembered_zoom := cam_ctrl.get_zoom_index()
	iso.set_mode(IsoView.Mode.OFF)
	await process_frame
	iso.set_mode(IsoView.Mode.HARVEST)
	await process_frame
	if cam.position.distance_to(remembered) > 0.01:
		print("FAIL: harvest should restore last camera pos ", remembered, " got ", cam.position)
		main.queue_free()
		return false
	if cam_ctrl.get_zoom_index() != remembered_zoom:
		print("FAIL: zoom index should persist across mode toggles")
		main.queue_free()
		return false
	print("OK: key pan + session camera memory across harvest")
	main.queue_free()
	return true


func _check_bay_mats() -> bool:
	## Mats are dark fairway terrain tiles on reserved bay cells — not prop sprites.
	if IsoCatalog.has(&"range_mat"):
		print("FAIL: range_mat should stay out of IsoCatalog (terrain tile, not prop)")
		return false
	var mat_path := "res://assets/sprites/iso/terrain/fairway_mat.png"
	if not ResourceLoader.exists(mat_path) and not FileAccess.file_exists(ProjectSettings.globalize_path(mat_path)):
		print("FAIL: missing authored mat ", mat_path)
		return false
	if IsoView.FAIRWAY_ATLAS_MAT != Vector2i(IsoView.FAIRWAY_VARIANT_COUNT * 2, 0):
		print("FAIL: FAIRWAY_ATLAS_MAT should be atlas index 2N")
		return false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var iso := main.get_node_or_null("IsoView") as IsoView
	if iso == null:
		print("FAIL: IsoView missing for bay mat check")
		main.queue_free()
		return false
	iso.set_active(true)
	await process_frame
	var terrain := iso.get_node_or_null("Terrain") as TileMapLayer
	if terrain == null:
		print("FAIL: Terrain missing for bay mat check")
		main.queue_free()
		return false
	var bay_cells: Array[Vector2i] = [RangeGrid.PLAYER_CELL, RangeGrid.RATINA_CELL]
	bay_cells.append_array(RangeGrid.empty_bay_cells_on_player_row())
	var expected := IsoView.FAIRWAY_ATLAS_MAT
	for range_cell in bay_cells:
		for iso_cell in IsoGrid.iso_cells_for_range_cell(range_cell):
			var atlas := terrain.get_cell_atlas_coords(iso_cell)
			if atlas != expected:
				print(
					"FAIL: bay mat atlas at range=", range_cell, " iso=", iso_cell,
					" got ", atlas, " expected ", expected
				)
				main.queue_free()
				return false
			if terrain.get_cell_source_id(iso_cell) != IsoView.FAIRWAY_SOURCE_ID:
				print("FAIL: bay mat source_id wrong at ", iso_cell)
				main.queue_free()
				return false
	print("OK: bay mats use fairway_mat atlas ", expected, " on all bay iso cells")
	main.queue_free()
	return true


func _check_duff_in_front_alignment() -> bool:
	## 1 yd downrange of the tee stays in the player column and moves screen top-right.
	var tee := RangeGrid.player_bay_origin()
	var duff := tee + Vector3(0.0, 0.0, -1.0)
	var tee_cell := IsoGrid.cell_from_yards(tee)
	var duff_cell := IsoGrid.cell_from_yards(duff)
	if duff_cell.x != tee_cell.x:
		print("FAIL: duff should stay same column ", tee_cell, " -> ", duff_cell)
		return false
	if duff_cell.y < tee_cell.y:
		print("FAIL: duff should not move nearer than tee ", tee_cell, " -> ", duff_cell)
		return false
	var tee_px := IsoGrid.iso_px_from_yards(tee)
	var duff_px := IsoGrid.iso_px_from_yards(duff)
	var delta := duff_px - tee_px
	if delta.x <= 0.0 or delta.y >= 0.0:
		print("FAIL: duff should aim screen top-right from tee, delta=", delta)
		return false
	## Ground actors use a fixed left + into-cell bias; flight/litter leave bias at zero.
	var bias := IsoActorMirror.GROUND_DISPLAY_BIAS
	if not bias.is_equal_approx(Vector3(-0.35, 0.0, -0.85)):
		print("FAIL: unexpected GROUND_DISPLAY_BIAS ", bias)
		return false
	print("OK: duff-in-front same column + top-right iso delta=", delta)
	return true


func _check_fairway_palette_colors() -> bool:
	## Iso terrain means (iso-only; 3D DayNightPalette day fairway is separate).
	var target_light := Vector3(0x26 / 255.0, 0x74 / 255.0, 0x08 / 255.0)
	var target_dark := Vector3(0x1E / 255.0, 0x5C / 255.0, 0x06 / 255.0)
	for i in IsoView.FAIRWAY_VARIANT_COUNT:
		for band in ["light", "dark"]:
			var path := "res://assets/sprites/iso/terrain/fairway_%s_%d.png" % [band, i]
			var img := Image.new()
			if img.load(ProjectSettings.globalize_path(path)) != OK:
				print("FAIL: could not load ", path, " for palette check")
				return false
			var acc := Vector3.ZERO
			var n := 0
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a < 0.5:
						continue
					acc += Vector3(c.r, c.g, c.b)
					n += 1
			if n == 0:
				print("FAIL: no opaque pixels ", path)
				return false
			var mean := acc / float(n)
			var target := target_light if band == "light" else target_dark
			var err := (mean - target).length()
			if err > 0.08:
				print("FAIL: ", path, " mean ", mean, " far from palette ", target, " err=", err)
				return false
	print("OK: iso fairway light/dark means match #267408 / #1e5c06")
	return true


func _check_litter_sprite_scale() -> bool:
	var scale := IsoView.litter_sprite_scale()
	## Ground-projected 16px * 0.021 yd ball on 64x32 tiles → ~0.25–0.45.
	if scale < 0.2 or scale > 0.45:
		print("FAIL: litter_sprite_scale out of range ", scale)
		return false
	print("OK: litter_sprite_scale=", snappedf(scale, 0.001))
	return true


func _fairway_variant_paths(band: String) -> Array[String]:
	var paths: Array[String] = []
	for i in IsoView.FAIRWAY_VARIANT_COUNT:
		paths.append("res://assets/sprites/iso/terrain/fairway_%s_%d.png" % [band, i])
	return paths


func _fairway_all_band_paths() -> Array[String]:
	var paths: Array[String] = []
	for band in ["light", "dark"]:
		paths.append_array(_fairway_variant_paths(band))
	paths.append("res://assets/sprites/iso/terrain/fairway_mat.png")
	return paths


func _check_fairway_native_flat() -> bool:
	## Native PixelLab flat contract: 64x32 canvas, no brown skirts.
	for path in _fairway_all_band_paths():
		var abs_path := ProjectSettings.globalize_path(path)
		var img := Image.new()
		if img.load(abs_path) != OK:
			print("FAIL: could not load ", path)
			return false
		if img.get_width() != 64 or img.get_height() != 32:
			print("FAIL: ", path, " expected native 64x32 got ", img.get_width(), "x", img.get_height())
			return false
		var speckles := 0
		var browns := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				# Brown skirts are not allowed (thickness must be 0%).
				if c.r > c.g and c.r > c.b and c.g < 0.55:
					browns += 1
					continue
				## Deep greens (#267408 / #1e5c06 / dark mat #0e4406) — require G-dominant,
				## not the old bright-lime floor (g > 0.3).
				if c.g >= c.r and c.g >= c.b and c.g > 0.02:
					continue
				speckles += 1
		if browns > 0:
			print("FAIL: ", path, " has ", browns, " brown skirt pixels")
			return false
		if speckles > 0:
			print("FAIL: ", path, " has ", speckles, " non-green speckles")
			return false
	print("OK: fairway native 64x32 flat (no skirts) variants=", IsoView.FAIRWAY_VARIANT_COUNT)
	return true


func _check_fairway_dark_is_tint() -> bool:
	## Dark band is a darkened copy of light — same opaque footprint, darker mean green.
	for i in IsoView.FAIRWAY_VARIANT_COUNT:
		var light_path := "res://assets/sprites/iso/terrain/fairway_light_%d.png" % i
		var dark_path := "res://assets/sprites/iso/terrain/fairway_dark_%d.png" % i
		var light := Image.new()
		var dark := Image.new()
		if light.load(ProjectSettings.globalize_path(light_path)) != OK:
			print("FAIL: could not load ", light_path, " for tint check")
			return false
		if dark.load(ProjectSettings.globalize_path(dark_path)) != OK:
			print("FAIL: could not load ", dark_path, " for tint check")
			return false
		if light.get_size() != dark.get_size():
			print("FAIL: light/dark size mismatch variant ", i)
			return false
		var light_g := 0.0
		var dark_g := 0.0
		var n := 0
		var alpha_mismatch := 0
		for y in light.get_height():
			for x in light.get_width():
				var cl := light.get_pixel(x, y)
				var cd := dark.get_pixel(x, y)
				var la := cl.a >= 0.5
				var da := cd.a >= 0.5
				if la != da:
					alpha_mismatch += 1
				if not la:
					continue
				light_g += cl.g
				dark_g += cd.g
				n += 1
		if alpha_mismatch > 0:
			print("FAIL: light/dark alpha footprint mismatch variant=", i, " count=", alpha_mismatch)
			return false
		if n == 0:
			print("FAIL: no opaque fairway pixels variant ", i)
			return false
		light_g /= float(n)
		dark_g /= float(n)
		if dark_g >= light_g - 0.02:
			print("FAIL: dark mean green not darker than light variant ", i, " (", dark_g, " vs ", light_g, ")")
			return false
	print("OK: fairway_dark tint-derived for ", IsoView.FAIRWAY_VARIANT_COUNT, " variants")
	return true


func _check_fairway_seam_flat() -> bool:
	## Painted diamond rims should be near interior luminance (no grid bevel).
	var worst_mean := 0.0
	for i in IsoView.FAIRWAY_VARIANT_COUNT:
		var path := "res://assets/sprites/iso/terrain/fairway_light_%d.png" % i
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(path)) != OK:
			print("FAIL: could not load ", path, " for seam check")
			return false
		var diffs: Array[float] = []
		var w := img.get_width()
		var h := img.get_height()
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var edge := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h or img.get_pixel(nx, ny).a < 0.5:
						edge = true
						break
				if not edge:
					continue
				var best := -1.0
				for rad in range(1, 5):
					for yy in range(y - rad, y + rad + 1):
						for xx in range(x - rad, x + rad + 1):
							if xx < 0 or yy < 0 or xx >= w or yy >= h:
								continue
							var ic := img.get_pixel(xx, yy)
							if ic.a < 0.5:
								continue
							var iedge := false
							for d2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
								var ix: int = xx + d2.x
								var iy: int = yy + d2.y
								if ix < 0 or iy < 0 or ix >= w or iy >= h or img.get_pixel(ix, iy).a < 0.5:
									iedge = true
									break
							if iedge:
								continue
							var lum_e := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
							var lum_i := 0.299 * ic.r + 0.587 * ic.g + 0.114 * ic.b
							best = absf(lum_e - lum_i)
							break
						if best >= 0.0:
							break
					if best >= 0.0:
						break
				if best >= 0.0:
					diffs.append(best)
		if diffs.is_empty():
			print("FAIL: no edge samples for seam check variant ", i)
			return false
		var mean := 0.0
		for dval in diffs:
			mean += dval
		mean /= float(diffs.size())
		if mean > 0.05:
			print("FAIL: fairway edge rim still strong variant=", i, " mean_delta=", mean)
			return false
		worst_mean = maxf(worst_mean, mean)
	print("OK: fairway seam flat worst_mean_edge_delta=", worst_mean)
	return true


func _check_fairway_variant_assets() -> bool:
	## N light/dark variants + single authored mat.
	for i in IsoView.FAIRWAY_VARIANT_COUNT:
		for band in ["light", "dark"]:
			var path := "res://assets/sprites/iso/terrain/fairway_%s_%d.png" % [band, i]
			if not ResourceLoader.exists(path) and not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
				print("FAIL: missing fairway variant ", path)
				return false
	if not ResourceLoader.exists("res://assets/sprites/iso/terrain/fairway_mat.png"):
		print("FAIL: missing fairway_mat.png")
		return false
	# Hash scatter must not wallpaper a single atlas id across neighbors.
	var a := IsoView.fairway_atlas_for_cell(0, 0)
	var b := IsoView.fairway_atlas_for_cell(0, 1)
	var c := IsoView.fairway_atlas_for_cell(1, 0)
	if a == b and b == c:
		print("FAIL: fairway hash scatter collapsed to one atlas")
		return false
	if a.x >= IsoView.FAIRWAY_VARIANT_COUNT or c.x < IsoView.FAIRWAY_VARIANT_COUNT:
		print("FAIL: fairway_atlas_for_cell band mapping wrong a=", a, " c=", c)
		return false
	print("OK: fairway variant assets + hash scatter")
	return true


func _check_iso_harvest_litter() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var iso := main.get_node_or_null("IsoView") as IsoView
	if iso == null:
		print("FAIL: IsoView missing for harvest litter check")
		main.queue_free()
		return false
	if main.has_method(&"set_harvest_view"):
		main.set_harvest_view(true)
	else:
		iso.set_mode(IsoView.Mode.HARVEST)
	await process_frame
	if not iso.is_harvest_view_ready():
		print("FAIL: iso harvest view not ready")
		main.queue_free()
		return false
	if iso.get_node_or_null("LitteredBalls") == null:
		print("FAIL: LitteredBalls node missing")
		main.queue_free()
		return false
	var world := Vector3(0.0, 0.0, -12.0)
	var event_bus: Node = root.get_node("EventBus")
	event_bus.litter_spawned.emit(9001, world, 2, 12.0, false, "player")
	await process_frame
	var litter_root := iso.get_node("LitteredBalls") as Node2D
	if litter_root.get_child_count() < 1:
		print("FAIL: litter sprite not spawned on IsoView")
		main.queue_free()
		return false
	var spr := litter_root.get_child(0) as Sprite2D
	var expected := IsoGrid.iso_px_from_yards(world)
	if spr.position.distance_to(expected) > 1.0:
		print("FAIL: litter position mismatch ", spr.position, " vs ", expected)
		main.queue_free()
		return false
	var ball_ph := iso.get_actor_layer().get_player_ball_placeholder() if iso.get_actor_layer() else null
	var expected_scale := ball_ph.scale.x if ball_ph != null else IsoView.litter_sprite_scale()
	if not is_equal_approx(spr.scale.x, expected_scale):
		print("FAIL: litter scale ", spr.scale.x, " expected placeholder ", expected_scale)
		main.queue_free()
		return false
	var yards_back := IsoGrid.yards_from_iso_px(expected)
	if absf(yards_back.x - world.x) > 0.5 or absf(yards_back.z - world.z) > 0.5:
		print("FAIL: yards_from_iso_px round-trip ", world, " -> ", yards_back)
		main.queue_free()
		return false
	var pickup: Node = iso.get_pickup_controller()
	if pickup == null:
		print("FAIL: IsoPickupController missing")
		main.queue_free()
		return false
	event_bus.litter_cleared.emit()
	await process_frame
	if litter_root.get_child_count() != 0:
		print("FAIL: litter not cleared")
		main.queue_free()
		return false
	if main.has_method(&"set_harvest_view"):
		main.set_harvest_view(false)
	print("OK: iso harvest litter sync + yards bridge")
	main.queue_free()
	return true


func _check_iso_picker_hit_alignment() -> bool:
	## Pickup must use the same tip→ellipse geometry as the drawn ring.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var iso := main.get_node_or_null("IsoView") as IsoView
	if iso == null:
		print("FAIL: IsoView missing for picker hit alignment")
		main.queue_free()
		return false
	if main.has_method(&"set_harvest_view"):
		main.set_harvest_view(true)
	else:
		iso.set_mode(IsoView.Mode.HARVEST)
	await process_frame
	var pickup: Node = iso.get_pickup_controller()
	if pickup == null or not pickup.has_method(&"_pick_litter_at"):
		print("FAIL: IsoPickupController missing pick API")
		main.queue_free()
		return false
	var world := Vector3(2.0, 0.0, -20.0)
	var event_bus: Node = root.get_node("EventBus")
	event_bus.litter_spawned.emit(9101, world, 2, 20.0, false, "player")
	await process_frame
	var litter_root := iso.get_node("LitteredBalls") as Node2D
	if litter_root.get_child_count() < 1:
		print("FAIL: litter missing for picker hit alignment")
		main.queue_free()
		return false
	var spr := litter_root.get_child(0) as Sprite2D
	var ball_screen: Vector2 = spr.get_global_transform_with_canvas().origin
	var radii: Vector2 = pickup.picker_radii_screen()
	## Tip on bottom rim with ball at ellipse center → must hit.
	var tip_center := ball_screen + Vector2(0.0, radii.y)
	var hit_center: Sprite2D = pickup._pick_litter_at(tip_center)
	if hit_center != spr:
		print("FAIL: ball at ellipse center should collect")
		main.queue_free()
		return false
	## Ball halfway to right rim → still inside.
	var tip_inner := ball_screen - Vector2(radii.x * 0.5, 0.0) + Vector2(0.0, radii.y)
	var hit_inner: Sprite2D = pickup._pick_litter_at(tip_inner)
	if hit_inner != spr:
		print("FAIL: ball inside ellipse should collect")
		main.queue_free()
		return false
	## Far tip → miss.
	var tip_miss := ball_screen + Vector2(800.0, 800.0)
	if pickup._pick_litter_at(tip_miss) != null:
		print("FAIL: far tip should miss litter")
		main.queue_free()
		return false
	event_bus.litter_cleared.emit()
	if main.has_method(&"set_harvest_view"):
		main.set_harvest_view(false)
	print("OK: iso picker hit matches ellipse geometry")
	main.queue_free()
	return true


func _check_iso_actor_mirrors() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var iso := main.get_node_or_null("IsoView") as IsoView
	var range_view := main.get_node_or_null("RangeView") as Node3D
	if iso == null or range_view == null:
		print("FAIL: IsoView/RangeView missing for actor mirror check")
		main.queue_free()
		return false
	iso.set_mode(IsoView.Mode.BUILD)
	await process_frame
	await process_frame
	var actors := iso.get_actor_layer()
	if actors == null:
		print("FAIL: ActorLayer missing")
		main.queue_free()
		return false
	var player_m := actors.get_player_golfer_mirror()
	if player_m == null or not is_instance_valid(player_m):
		print("FAIL: player golfer mirror missing")
		main.queue_free()
		return false
	var golfer_ph := actors.get_player_golfer_placeholder()
	var ball_ph := actors.get_player_ball_placeholder()
	if golfer_ph == null or ball_ph == null:
		print("FAIL: player golfer/ball placeholders missing on ActorLayer")
		main.queue_free()
		return false
	if golfer_ph.visible or ball_ph.visible:
		print("FAIL: placeholders must be hidden at runtime")
		main.queue_free()
		return false
	if not is_equal_approx(player_m.scale.x, golfer_ph.scale.x):
		print("FAIL: golfer scale should match placeholder ", golfer_ph.scale, " got ", player_m.scale)
		main.queue_free()
		return false
	var golfer: AnimatedSprite3D = range_view.get_golfer()
	if golfer == null:
		print("FAIL: range golfer missing")
		main.queue_free()
		return false
	## Night: mirror color must match 3D modulate exactly (no parent wash stacking).
	iso.apply_atmosphere(0.0)
	await process_frame
	if not actors.modulate.is_equal_approx(Color.WHITE):
		print("FAIL: ActorLayer must stay untinted got ", actors.modulate)
		main.queue_free()
		return false
	if not player_m.modulate.is_equal_approx(golfer.modulate):
		print(
			"FAIL: golfer modulate not 1:1 with 3D iso=",
			player_m.modulate, " src=", golfer.modulate
		)
		main.queue_free()
		return false
	## Idle: mirror must sit on the authored placeholder (editor WYSIWYG).
	if player_m.position.distance_to(golfer_ph.position) > 1.0:
		print(
			"FAIL: idle golfer should match placeholder pos ",
			golfer_ph.position, " got ", player_m.position
		)
		main.queue_free()
		return false
	## Placeholder pose should sit nearer the painted mat cell center than the near-edge tee.
	var tee_px := IsoGrid.iso_px_from_yards(RangeGrid.player_bay_origin())
	var mat_center_px := IsoGrid.iso_px_from_yards(IsoGrid.yards_from_cell(RangeGrid.PLAYER_CELL))
	if player_m.position.distance_to(mat_center_px) > player_m.position.distance_to(tee_px) + 0.5:
		print("FAIL: biased golfer should sit nearer mat center than tee tip")
		main.queue_free()
		return false
	if not player_m.visible:
		print("FAIL: player mirror should be visible in build mode")
		main.queue_free()
		return false
	## Hidden RangeView must still drive mirrors (RangeView._process keeps running).
	golfer.play(&"idle")
	range_view.visible = false
	golfer.visible = true
	for _i in 10:
		await process_frame
	if not player_m.visible:
		print("FAIL: mirror should track source.visible while RangeView is hidden")
		main.queue_free()
		return false
	## Match live strike home — RangeView resets golfer.position each frame when idle.
	if player_m.position.distance_to(golfer_ph.position) > 1.0:
		print(
			"FAIL: mirror drifted while RangeView hidden ",
			player_m.position, " vs placeholder ", golfer_ph.position
		)
		main.queue_free()
		return false
	if player_m.sprite_frames == null or player_m.animation != golfer.animation:
		print("FAIL: mirror animation mismatch ", player_m.animation, " vs ", golfer.animation)
		main.queue_free()
		return false
	## Ratina bay is created in RangeView._ready — mirror should bind.
	var ratina_m := actors.get_ratina_golfer_mirror()
	if range_view.ratina_sprite != null and ratina_m == null:
		print("FAIL: Ratina mirror missing while ratina_sprite exists")
		main.queue_free()
		return false
	if ratina_m != null and range_view.ratina_sprite != null:
		var r_expected := IsoGrid.iso_px_from_yards(
			Vector3(
				range_view.ratina_sprite.global_position.x,
				0.0,
				range_view.ratina_sprite.global_position.z
			)
			+ IsoActorMirror.GROUND_DISPLAY_BIAS
		)
		## Ratina may be hidden until unlocked — still check position sync when visible.
		ratina_m.source = range_view.ratina_sprite
		await process_frame
		if range_view.ratina_sprite.visible and ratina_m.position.distance_to(r_expected) > 1.0:
			print("FAIL: Ratina mirror pos ", ratina_m.position, " expected ", r_expected)
			main.queue_free()
			return false
	print("OK: iso actor mirrors at bay cells + native scale")
	main.queue_free()
	return true


func _check_iso_flight_mirror() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var iso := main.get_node_or_null("IsoView") as IsoView
	var range_view := main.get_node_or_null("RangeView") as Node3D
	if iso == null or range_view == null:
		print("FAIL: IsoView/RangeView missing for flight mirror check")
		main.queue_free()
		return false
	iso.set_mode(IsoView.Mode.BUILD)
	await process_frame
	var flights_root := iso.get_node_or_null("Flights") as Node2D
	var trails_root := iso.get_node_or_null("Trails") as Node2D
	if flights_root == null or trails_root == null:
		print("FAIL: Flights/Trails nodes missing")
		main.queue_free()
		return false
	var flight_layer := iso.get_flight_layer()
	if flight_layer == null:
		print("FAIL: FlightLayer missing")
		main.queue_free()
		return false
	## Synthetic in-flight ball tagged like RangeView._spawn_flight_sprite.
	var src := AnimatedSprite3D.new()
	src.sprite_frames = DinkySpriteFrames.make_ball_frames()
	src.set_meta("timing_tier", Balance.TimingTier.GOOD)
	src.set_meta("is_golden", false)
	src.set_meta("with_bounces", true)
	src.add_to_group(&"range_flight_ball")
	src.visible = true
	range_view.add_child(src)
	src.global_position = Vector3(0.0, 0.0, -10.0)
	src.play(&"roll")
	await process_frame
	await process_frame
	if flight_layer.get_active_count() < 1:
		print("FAIL: flight layer did not mirror group ball")
		src.queue_free()
		main.queue_free()
		return false
	var mirror := flight_layer.get_mirror_for_source(src)
	var trail := flight_layer.get_trail_for_source(src)
	if mirror == null or trail == null:
		print("FAIL: missing flight mirror or trail")
		src.queue_free()
		main.queue_free()
		return false
	src.global_position = Vector3(0.0, 4.0, -20.0)
	## Advance roll frames — iso mirror must stay on idle/lay (constant size).
	for i in 8:
		src.frame = i % DinkySpriteFrames.BALL_ROLL_FRAME_COUNT
		await process_frame
		if mirror.animation != &"idle" or mirror.frame != 0:
			print(
				"FAIL: flight mirror should stay idle/0 while source rolls; got ",
				mirror.animation, " frame=", mirror.frame
			)
			src.queue_free()
			main.queue_free()
			return false
		var ball_ph := iso.get_actor_layer().get_player_ball_placeholder() if iso.get_actor_layer() else null
		var expected_scale := (
			ball_ph.scale.x if ball_ph != null else IsoView.litter_sprite_scale()
		)
		if not is_equal_approx(mirror.scale.x, expected_scale):
			print(
				"FAIL: flight mirror scale ", mirror.scale.x,
				" expected ", expected_scale
			)
			src.queue_free()
			main.queue_free()
			return false
	var ground_px := IsoGrid.iso_px_from_yards(Vector3(0.0, 0.0, -20.0))
	var air_px := IsoGrid.iso_px_from_yards(Vector3(0.0, 4.0, -20.0))
	var lift := ground_px.y - air_px.y
	if lift < IsoGrid.HEIGHT_PX_PER_YARD * 3.5:
		print("FAIL: altitude should lift ball; lift=", lift)
		src.queue_free()
		main.queue_free()
		return false
	if mirror.position.distance_to(air_px) > 1.0:
		print("FAIL: flight mirror pos ", mirror.position, " expected ", air_px)
		src.queue_free()
		main.queue_free()
		return false
	if trail.has_method(&"point_count") and trail.point_count() < 1:
		print("FAIL: trail should have samples")
		src.queue_free()
		main.queue_free()
		return false
	## Hand-off: remove flight source, spawn litter — trail finishes, litter appears.
	src.remove_from_group(&"range_flight_ball")
	src.queue_free()
	await process_frame
	await process_frame
	var bus: Node = root.get_node("EventBus")
	var rest := Vector3(0.0, 0.0, -20.0)
	bus.litter_spawned.emit(9101, rest, 2, 20.0, false, "player")
	await process_frame
	var litter_root := iso.get_node("LitteredBalls") as Node2D
	if litter_root.get_child_count() < 1:
		print("FAIL: litter handoff missing after flight")
		main.queue_free()
		return false
	bus.litter_cleared.emit()
	print("OK: iso flight mirror + trail + altitude + constant idle size + litter handoff")
	main.queue_free()
	return true
