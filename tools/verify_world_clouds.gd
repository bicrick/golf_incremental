extends SceneTree
## Headless discretized cloud grid tests — run:
## godot --headless --script res://tools/verify_world_clouds.gd

const CloudNoiseFieldScript := preload("res://scripts/visual/cloud_noise_field.gd")
const CloudGridChunkScript := preload("res://scripts/visual/cloud_grid_chunk.gd")

const LAYER_Y := 19.0
const TEST_SEED := 4242
const TEST_SCROLL := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_noise_determinism() and ok
	ok = _check_grid_non_overlap() and ok
	ok = _check_sparsity() and ok
	ok = _check_density_sweep() and ok
	ok = _check_inversion_flip() and ok
	ok = _check_mesh_build() and ok
	ok = await _check_scene_wiring() and ok
	ok = await _check_deck_population() and ok
	print("world_clouds_ok=", ok)
	quit(0 if ok else 1)


func _make_noise():
	var field = CloudNoiseFieldScript.new(TEST_SEED)
	field.configure(TEST_SEED, 0.04, 0.035, 0.004, 0.0015, 4, 0.58, 0.45, 0.15)
	return field


func _check_noise_determinism() -> bool:
	var a = _make_noise()
	var b = _make_noise()
	var samples := [
		Vector3(12.0, 0.0, -40.0),
		Vector3(33.0, 0.0, 18.0),
		Vector3(-5.0, 0.0, 72.0),
	]
	for sample in samples:
		var x: float = sample.x
		var z: float = sample.z
		if a.occupancy(x, z, TEST_SCROLL) != b.occupancy(x, z, TEST_SCROLL):
			print("FAIL: occupancy should be deterministic for seed")
			return false
		if not is_equal_approx(a.field_value(x, z, TEST_SCROLL), b.field_value(x, z, TEST_SCROLL)):
			print("FAIL: field_value should be deterministic for seed")
			return false

	print("OK: noise field deterministic for seed")
	return true


func _check_grid_non_overlap() -> bool:
	var occupancy: Dictionary = {}
	occupancy[Vector2i(0, 0)] = true
	occupancy[Vector2i(1, 0)] = true
	occupancy[Vector2i(0, 1)] = true
	if CloudGridChunkScript.occupied_cell_count(occupancy) != 3:
		print("FAIL: occupancy count mismatch")
		return false
	var seen: Dictionary = {}
	for key: Variant in occupancy.keys():
		if seen.has(key):
			print("FAIL: occupancy keys should be unique")
			return false
		seen[key] = true

	print("OK: grid cells are unique discrete slots")
	return true


func _check_sparsity() -> bool:
	var noise = _make_noise()
	var occupied := 0
	var samples := 120
	for i in samples:
		var x := float(i * 6)
		var z := -120.0
		if noise.occupancy(x, z, TEST_SCROLL):
			occupied += 1
	if occupied >= samples * 0.45:
		print("FAIL: cloud field should stay sparse, got ", occupied, "/", samples)
		return false
	if occupied <= 8:
		print("FAIL: cloud field should not be empty at default scroll, got ", occupied)
		return false

	print("OK: cloud field stays sparse (occupied=%d/%d)" % [occupied, samples])
	return true


func _check_density_sweep() -> bool:
	var noise = _make_noise()
	var low_count := 0
	var high_count := 0
	var samples := 48
	for i in samples:
		var x := float(i * 40)
		var z := -60.0
		if noise.occupancy(x, z, 0.0):
			low_count += 1
		if noise.occupancy(x, z, 4000.0):
			high_count += 1

	if low_count >= samples * 0.85:
		print("FAIL: low scroll offset should not be near-solid, got ", low_count)
		return false
	if high_count <= samples * 0.05 and low_count <= samples * 0.05:
		print("FAIL: density sweep should produce both sparse and dense samples")
		return false

	print("OK: density envelope spans sparse-to-dense occupancy")
	return true


func _check_inversion_flip() -> bool:
	var noise = _make_noise()
	var flipped := 0
	var samples := 64
	for i in samples:
		var x := float(i * 8)
		var z := 24.0
		var scroll_a := 256.0
		var scroll_b := 5256.0
		if noise.occupancy(x, z, scroll_a) != noise.occupancy(x, z, scroll_b):
			flipped += 1

	if flipped < 8:
		print("FAIL: inversion regime should flip occupancy across scroll offsets, got ", flipped)
		return false

	print("OK: inversion regime changes occupancy pattern")
	return true


func _check_mesh_build() -> bool:
	var occupancy: Dictionary = {}
	occupancy[Vector2i(0, 0)] = true
	occupancy[Vector2i(1, 0)] = true
	occupancy[Vector2i(1, 1)] = true
	var mesh := CloudGridChunkScript.build_mesh_from_occupancy(
		occupancy,
		0.0,
		-20.0,
		4.0,
		LAYER_Y
	)
	if mesh == null:
		print("FAIL: occupied grid should build merged mesh")
		return false
	if mesh.get_surface_count() != 1:
		print("FAIL: merged mesh should have one surface")
		return false

	var empty_mesh := CloudGridChunkScript.build_mesh_from_occupancy({}, 0.0, 0.0, 4.0, LAYER_Y)
	if empty_mesh != null:
		print("FAIL: empty occupancy should not build mesh")
		return false

	print("OK: grid chunk builds merged exterior mesh")
	return true


func _check_scene_wiring() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame
	await process_frame

	var grid: Node3D = range_view.get_node_or_null("WorldClouds")
	if grid == null or not grid.has_method(&"update_atmosphere"):
		print("FAIL: RangeView missing WorldClouds grid API")
		range_view.queue_free()
		return false

	if not is_equal_approx(grid.cloud_layer_y, LAYER_Y):
		print("FAIL: cloud_layer_y expected %.1f, got %.1f" % [LAYER_Y, grid.cloud_layer_y])
		range_view.queue_free()
		return false
	if grid.get("spawn_x_west") >= 0.0:
		print("FAIL: spawn_x_west should stay far west, got ", grid.get("spawn_x_west"))
		range_view.queue_free()
		return false
	if grid.get("despawn_x_east") <= 0.0:
		print("FAIL: despawn_x_east should stay far east, got ", grid.get("despawn_x_east"))
		range_view.queue_free()
		return false

	var cycle := range_view.get_node_or_null("DayNightCycle")
	if cycle:
		cycle.set_process(false)

	range_view.apply_atmosphere(40.0)
	await process_frame
	if grid.get_density() < 0.7:
		print("FAIL: day atmosphere should raise cloud density, got ", grid.get_density())
		range_view.queue_free()
		return false
	if grid.get_target_alpha() < 0.7:
		print("FAIL: day cloud alpha expected > 0.7, got ", grid.get_target_alpha())
		range_view.queue_free()
		return false
	if grid.get_drift_speed() <= 0.0:
		print("FAIL: drift speed should stay positive")
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(0.0)
	await process_frame
	if grid.get_target_alpha() < 0.5:
		print("FAIL: midnight should keep usable cloud alpha, got ", grid.get_target_alpha())
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: WorldClouds grid wired with atmosphere API")
	return true


func _check_deck_population() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame
	await process_frame

	var grid: Node3D = range_view.get_node("WorldClouds")
	grid.call("configure_noise_for_test", TEST_SEED)
	grid.call("set_scroll_offset_for_test", TEST_SCROLL)
	await process_frame

	var deck_count: int = grid.call("get_deck_occupied_count")
	if deck_count <= 0:
		print("FAIL: deck should populate cloud cells at test scroll offset")
		range_view.queue_free()
		return false
	if deck_count >= 8000:
		print("FAIL: deck should stay sparse, got ", deck_count)
		range_view.queue_free()
		return false

	var deck_grid: Dictionary = grid.call("get_deck_occupancy")
	var width: float = grid.get("deck_x_max") - grid.get("deck_x_min")
	var depth: float = grid.get("deck_z_near") - grid.get("deck_z_far")
	if width < 200.0:
		print("FAIL: deck should span fairway width, got ", width)
		range_view.queue_free()
		return false
	if depth < 250.0:
		print("FAIL: deck should span full fairway depth, got ", depth)
		range_view.queue_free()
		return false

	var ortho_visible := 0
	var cell_x: float = width / float(maxi(grid.get("wind_columns"), 1))
	var cell_z: float = maxf(grid.get("cell_size"), cell_x)
	for key: Variant in deck_grid.keys():
		if not bool(deck_grid[key]):
			continue
		var cell: Vector2i = key as Vector2i
		var world_x: float = grid.get("deck_x_min") + (float(cell.x) + 0.5) * cell_x
		var world_z: float = grid.get("deck_z_far") + (float(cell.y) + 0.5) * cell_z
		if grid.call("is_ortho_visible_position", world_x, world_z):
			ortho_visible += 1

	var deck_mesh: MeshInstance3D = grid.get_node("CloudDeck")
	if deck_count > 0 and deck_mesh.mesh == null:
		print("FAIL: deck should expose merged mesh when occupied")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print(
		"OK: full fairway deck populated (cells=%d ortho_visible=%d span=%.0fx%.0f)"
		% [deck_count, ortho_visible, width, depth]
	)
	return true
