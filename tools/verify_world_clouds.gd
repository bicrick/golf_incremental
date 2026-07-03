extends SceneTree
## Headless world cloud tests — run:
## godot --headless --script res://tools/verify_world_clouds.gd


const WorldCloudClusterScript := preload("res://scripts/visual/world_cloud_cluster.gd")

const LAYER_Y := 19.0
const BLOCK_SIZE := 2.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_cluster_generation() and ok
	ok = _check_deterministic_seed() and ok
	ok = _check_depth_wrap() and ok
	ok = await _check_field_in_scene() and ok
	ok = await _check_field_prefill() and ok
	print("world_clouds_ok=", ok)
	quit(0 if ok else 1)


func _check_cluster_generation() -> bool:
	var sparse: Node3D = WorldCloudClusterScript.generate(42, LAYER_Y, 0.3, BLOCK_SIZE)
	var blanket: Node3D = WorldCloudClusterScript.generate(42, LAYER_Y, 0.85, BLOCK_SIZE)
	var sparse_count: int = WorldCloudClusterScript.block_count_for(sparse)
	var blanket_count: int = WorldCloudClusterScript.block_count_for(blanket)

	if sparse_count < 3 or sparse_count > 35:
		print("FAIL: sparse cloud block count expected 3-35, got ", sparse_count)
		sparse.queue_free()
		blanket.queue_free()
		return false

	if blanket_count < 20:
		print("FAIL: blanket cloud block count expected >= 20, got ", blanket_count)
		sparse.queue_free()
		blanket.queue_free()
		return false

	if blanket_count <= sparse_count:
		print(
			"FAIL: blanket should exceed sparse block count (blanket=%d sparse=%d)"
			% [blanket_count, sparse_count]
		)
		sparse.queue_free()
		blanket.queue_free()
		return false

	if not WorldCloudClusterScript.has_merged_mesh(sparse):
		print("FAIL: sparse cluster should have one merged MeshInstance3D child")
		sparse.queue_free()
		blanket.queue_free()
		return false
	if not WorldCloudClusterScript.has_merged_mesh(blanket):
		print("FAIL: blanket cluster should have one merged MeshInstance3D child")
		sparse.queue_free()
		blanket.queue_free()
		return false

	var different_seed: Node3D = WorldCloudClusterScript.generate(99, LAYER_Y, 0.85, BLOCK_SIZE)
	var pos_a: Array[Vector3] = WorldCloudClusterScript.block_positions(blanket)
	var pos_b: Array[Vector3] = WorldCloudClusterScript.block_positions(different_seed)
	if pos_a.size() == pos_b.size():
		var same_shape := true
		for i in pos_a.size():
			if not pos_a[i].is_equal_approx(pos_b[i]):
				same_shape = false
				break
		if same_shape:
			print("FAIL: different seeds should produce different cloud shapes")
			sparse.queue_free()
			blanket.queue_free()
			different_seed.queue_free()
			return false

	for cluster in [sparse, blanket, different_seed]:
		for pos in WorldCloudClusterScript.block_positions(cluster):
			var bottom_y := pos.y - BLOCK_SIZE * 0.5
			if bottom_y < LAYER_Y - 0.01:
				print("FAIL: block bottom Y expected >= %.1f, got %.1f" % [LAYER_Y, bottom_y])
				sparse.queue_free()
				blanket.queue_free()
				different_seed.queue_free()
				return false

	sparse.queue_free()
	blanket.queue_free()
	different_seed.queue_free()
	print("OK: thermo cloud generation sparse=%d blanket=%d" % [sparse_count, blanket_count])
	return true


func _check_deterministic_seed() -> bool:
	var a: Node3D = WorldCloudClusterScript.generate(12345, LAYER_Y, 0.55, BLOCK_SIZE)
	var b: Node3D = WorldCloudClusterScript.generate(12345, LAYER_Y, 0.55, BLOCK_SIZE)
	var pos_a: Array[Vector3] = WorldCloudClusterScript.block_positions(a)
	var pos_b: Array[Vector3] = WorldCloudClusterScript.block_positions(b)
	if pos_a.size() != pos_b.size():
		print("FAIL: same seed should produce same block count")
		a.queue_free()
		b.queue_free()
		return false
	for i in pos_a.size():
		if not pos_a[i].is_equal_approx(pos_b[i]):
			print("FAIL: same seed should reproduce identical block layout")
			a.queue_free()
			b.queue_free()
			return false
	a.queue_free()
	b.queue_free()
	print("OK: cloud layout deterministic for seed")
	return true


func _check_depth_wrap() -> bool:
	var field := WorldCloudField.new()
	field.deck_half_extent_x = 20000.0
	field.spawn_depth_x_factor = 8.0

	var near_push: float = field.depth_push_for_z(-15.0)
	var far_push: float = field.depth_push_for_z(-285.0)
	if far_push <= near_push:
		print("FAIL: farther Z should push wrap band further west")
		field.free()
		return false

	var near_extent: float = field.deck_half_extent_x_for_z(-15.0)
	var far_extent: float = field.deck_half_extent_x_for_z(-285.0)
	if far_extent <= near_extent:
		print("FAIL: farther Z should expand symmetric deck extent")
		field.free()
		return false

	var near_despawn: float = field.despawn_x_for_z(-15.0)
	var far_despawn: float = field.despawn_x_for_z(-285.0)
	var near_wrap: float = field.west_wrap_limit_for_z(-15.0)
	var far_wrap: float = field.west_wrap_limit_for_z(-285.0)
	if not is_equal_approx(near_despawn, -near_wrap):
		print("FAIL: east despawn should mirror west wrap limit")
		field.free()
		return false
	if not is_equal_approx(far_despawn, -far_wrap):
		print("FAIL: depth-scaled east despawn should mirror west wrap limit")
		field.free()
		return false
	if far_despawn <= near_despawn:
		print("FAIL: farther Z should despawn further east before wrap")
		field.free()
		return false

	var pos := field.pick_wrap_position()
	var extent_at_z: float = field.deck_half_extent_x_for_z(pos.z)
	var west_outer: float = -extent_at_z
	var west_inner: float = -extent_at_z * field.wrap_inner_fraction
	if pos.x < west_outer or pos.x > west_inner:
		print("FAIL: wrap position X expected far west, got ", pos.x)
		field.free()
		return false
	if pos.z < field.spawn_z_far or pos.z > field.spawn_z_near:
		print("FAIL: wrap position Z expected within fairway band, got ", pos.z)
		field.free()
		return false

	field.free()
	print("OK: symmetric extreme depth-scaled wrap band")
	return true


func _check_field_in_scene() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame
	await process_frame

	var field: Node3D = range_view.get_node_or_null("WorldClouds")
	if field == null or not field.has_method(&"get_density"):
		print("FAIL: RangeView missing WorldClouds")
		range_view.queue_free()
		return false

	if not is_equal_approx(field.cloud_layer_y, LAYER_Y):
		print("FAIL: cloud_layer_y expected %.1f, got %.1f" % [LAYER_Y, field.cloud_layer_y])
		range_view.queue_free()
		return false

	var cycle := range_view.get_node_or_null("DayNightCycle")
	if cycle:
		cycle.set_process(false)

	range_view.apply_atmosphere(40.0)
	await process_frame
	if field.get_density() < 0.7:
		print("FAIL: day atmosphere should raise cloud density, got ", field.get_density())
		range_view.queue_free()
		return false
	if field.get_target_alpha() < 0.7:
		print("FAIL: day cloud alpha expected > 0.7, got ", field.get_target_alpha())
		range_view.queue_free()
		return false

	range_view.apply_atmosphere(0.0)
	await process_frame
	if field.get_max_active() > 1:
		print("FAIL: midnight should lower active cloud cap, got ", field.get_max_active())
		range_view.queue_free()
		return false

	var day_speed: float = field.get_drift_speed()
	range_view.apply_atmosphere(0.0)
	await process_frame
	if not is_equal_approx(field.get_drift_speed(), day_speed):
		print("FAIL: drift speed should stay uniform at night")
		range_view.queue_free()
		return false

	var start_x := -45.0
	var cluster: Node3D = WorldCloudClusterScript.generate(7, LAYER_Y, 0.5, BLOCK_SIZE)
	cluster.position = Vector3(start_x, 0.0, -80.0)
	field.add_child(cluster)
	field.track_cluster_for_test(cluster)

	var before: float = cluster.position.x
	field.move_clouds_step(1.0)
	var day_delta: float = cluster.position.x - before
	if day_delta <= 0.0:
		print("FAIL: clouds should drift east (+X)")
		range_view.queue_free()
		return false
	if not is_equal_approx(day_delta, field.get_drift_speed()):
		print("FAIL: day drift delta expected %.2f, got %.2f" % [field.get_drift_speed(), day_delta])
		range_view.queue_free()
		return false
	if not is_equal_approx(cluster.position.z, -80.0):
		print("FAIL: east drift should not change Z")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: WorldClouds wired with atmosphere and uniform east drift")
	return true


func _check_field_prefill() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame
	await process_frame

	var field: Node3D = range_view.get_node("WorldClouds")
	var cycle := range_view.get_node_or_null("DayNightCycle")
	if cycle:
		cycle.set_process(false)

	range_view.apply_atmosphere(40.0)
	await process_frame
	field.set_deck_mood_for_test(WorldCloudField.DeckMood.OVERCAST)
	await process_frame

	var x_min := 999.0
	var x_max := -999.0
	var z_min := 0.0
	var z_max := -999.0
	var cloud_count := 0
	for child in field.get_children():
		cloud_count += 1
		x_min = minf(x_min, child.position.x)
		x_max = maxf(x_max, child.position.x)
		z_min = minf(z_min, child.position.z)
		z_max = maxf(z_max, child.position.z)

	if cloud_count < 6:
		print("FAIL: pre-filled deck should spawn multiple clouds, got ", cloud_count)
		range_view.queue_free()
		return false

	if x_min > -5000.0:
		print("FAIL: pre-filled deck should place clouds far west off-screen, min_x=", x_min)
		range_view.queue_free()
		return false
	if z_max < -70.0:
		print("FAIL: pre-filled deck should include near-tee Z, closest_z=", z_max)
		range_view.queue_free()
		return false
	if z_min > -150.0:
		print("FAIL: pre-filled deck should reach far fairway Z, farthest_z=", z_min)
		range_view.queue_free()
		return false
	if field.get_max_active() < 6:
		print("FAIL: overcast deck cap should allow many active clouds, got ", field.get_max_active())
		range_view.queue_free()
		return false

	field.set_deck_mood_for_test(WorldCloudField.DeckMood.CLEAR)
	await process_frame
	if field.get_child_count() != 0:
		print("FAIL: clear mood should remove all clouds, got ", field.get_child_count())
		range_view.queue_free()
		return false

	range_view.queue_free()
	print(
		"OK: deck spans fairway XZ (x=%.1f..%.1f z=%.1f..%.1f)"
		% [x_min, x_max, z_min, z_max]
	)
	return true
