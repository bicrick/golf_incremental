class_name WorldCloudGrid
extends Node3D
## Fixed discretized cloud curtain — full fairway deck, eastward streaming noise field.

const CloudNoiseFieldScript := preload("res://scripts/visual/cloud_noise_field.gd")
const CloudGridChunkScript := preload("res://scripts/visual/cloud_grid_chunk.gd")

const ORTHO_CAM_POS := Vector3(77.093094, 71.31996, 247.45828)
const ORTHO_CAM_SIZE := 13.277695
const ORTHO_VIEW_ASPECT := 16.0 / 9.0

@export var cloud_layer_y: float = 19.0
@export var cell_size: float = 4.0
@export var wind_columns: int = 100
@export var drift_speed: float = 2.5
@export var noise_seed: int = 0
@export var scale_x: float = 0.04
@export var scale_z: float = 0.035
@export var density_scale: float = 0.004
@export var inversion_scale: float = 0.0015
@export var fbm_octaves: int = 4
@export var sparse_threshold: float = 0.58
@export var dense_threshold: float = 0.45
@export var empty_density_cutoff: float = 0.15
@export var spawn_x_west: float = -25000.0
@export var despawn_x_east: float = 25000.0
@export var deck_x_min: float = -80.0
@export var deck_x_max: float = 160.0
@export var deck_z_near: float = 8.0
@export var deck_z_far: float = -300.0

var _density := 1.0
var _target_alpha := 0.96
var _day_tint := Color(0.97, 0.98, 1.0)
var _night_blend := 0.0
var _scroll_offset := 0.0
var _scroll_tick := 0
var _master_material: StandardMaterial3D
var _noise_field
var _deck_mesh: MeshInstance3D
var _deck_occupancy: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_master_material = CloudGridChunkScript.default_material()
	if noise_seed == 0:
		noise_seed = int(_rng.randi())
	_init_noise_field()
	_deck_mesh = _make_region_mesh(&"CloudDeck")
	add_child(_deck_mesh)
	if Engine.is_editor_hint():
		return
	_rebuild_deck()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var parent_3d := get_parent() as Node3D
	if parent_3d != null and not parent_3d.visible:
		return

	_scroll_offset += drift_speed * delta
	var deck_period := maxf(despawn_x_east - spawn_x_west, cell_size)
	if _scroll_offset > deck_period:
		_scroll_offset = fmod(_scroll_offset, deck_period)

	var next_tick := int(floor(_scroll_offset / maxf(cell_size, 0.001)))
	if next_tick != _scroll_tick:
		_scroll_tick = next_tick
		_rebuild_deck()


func update_atmosphere(
	cycle_time: float,
	snap: DayNightPalette.AtmosphereSnapshot,
	day_factor: float
) -> void:
	var day_peak := DayNightPalette.cloud_visibility(cycle_time)
	_density = lerpf(0.0, 1.0, day_peak)
	_target_alpha = lerpf(0.78, 0.96, maxf(_density, 0.15))
	_day_tint = Color(0.97, 0.98, 1.0)
	var night_tint := snap.canvas_modulate.lerp(Color(0.82, 0.85, 0.92), 0.6)
	_night_blend = 1.0 - day_factor
	_day_tint = _day_tint.lerp(night_tint, _night_blend)
	_apply_material_tint()


func get_density() -> float:
	return _density


func get_target_alpha() -> float:
	return _target_alpha


func get_drift_speed() -> float:
	return drift_speed


func get_scroll_offset() -> float:
	return _scroll_offset


func get_scroll_tick() -> int:
	return _scroll_tick


func get_noise_field():
	return _noise_field


func get_deck_occupancy() -> Dictionary:
	return _deck_occupancy


func get_deck_occupied_count() -> int:
	return CloudGridChunkScript.occupied_cell_count(_deck_occupancy)


func get_ortho_occupancy() -> Dictionary:
	return _deck_occupancy


func get_fairway_occupancy() -> Dictionary:
	return _deck_occupancy


func get_ortho_occupied_count() -> int:
	return get_deck_occupied_count()


func get_fairway_occupied_count() -> int:
	return get_deck_occupied_count()


func configure_noise_for_test(p_seed: int) -> void:
	noise_seed = p_seed
	_init_noise_field()
	_rebuild_deck()


func set_scroll_offset_for_test(offset: float) -> void:
	_scroll_offset = offset
	_scroll_tick = int(floor(_scroll_offset / maxf(cell_size, 0.001)))
	_rebuild_deck()


func rebuild_for_test() -> void:
	_rebuild_deck()


func is_ortho_visible_position(x: float, z: float, layer_y: float = cloud_layer_y) -> bool:
	var offset := Vector3(x, layer_y, z) - ORTHO_CAM_POS
	var basis := V4CameraConfig.LOCKED_BASIS
	var dot_right := offset.dot(basis.x)
	var dot_up := offset.dot(basis.y)
	var dot_forward := -offset.dot(basis.z)
	var half_width := ORTHO_CAM_SIZE * ORTHO_VIEW_ASPECT
	return (
		dot_forward > 1.0
		and absf(dot_right) <= half_width
		and absf(dot_up) <= ORTHO_CAM_SIZE
	)


func _init_noise_field() -> void:
	if _noise_field == null:
		_noise_field = CloudNoiseFieldScript.new(noise_seed)
	_noise_field.configure(
		noise_seed,
		scale_x,
		scale_z,
		density_scale,
		inversion_scale,
		fbm_octaves,
		sparse_threshold,
		dense_threshold,
		empty_density_cutoff
	)


func _make_region_mesh(mesh_name: StringName) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = _master_material
	return mesh_instance


class _DeckGrid:
	var x_min: float
	var x_max: float
	var z_near: float
	var z_far: float
	var columns: int
	var rows: int
	var cell_x: float
	var cell_z: float


func _deck_grid() -> _DeckGrid:
	var grid := _DeckGrid.new()
	grid.x_min = deck_x_min
	grid.x_max = deck_x_max
	grid.z_near = deck_z_near
	grid.z_far = deck_z_far
	var width := maxf(grid.x_max - grid.x_min, cell_size)
	var depth := maxf(grid.z_near - grid.z_far, cell_size)
	grid.columns = maxi(wind_columns, 1)
	grid.cell_x = width / float(grid.columns)
	grid.cell_z = maxf(cell_size, grid.cell_x)
	grid.rows = maxi(int(ceil(depth / grid.cell_z)), 1)
	return grid


func _rebuild_deck() -> void:
	var grid := _deck_grid()
	_deck_occupancy = _sample_deck_occupancy(grid)
	var mesh := CloudGridChunkScript.build_mesh_from_occupancy(
		_deck_occupancy,
		grid.x_min,
		grid.z_far,
		grid.cell_x,
		cloud_layer_y
	)
	_deck_mesh.mesh = mesh


func _sample_deck_occupancy(grid: _DeckGrid) -> Dictionary:
	var occupancy: Dictionary = {}
	for col in grid.columns:
		var world_x := grid.x_min + (float(col) + 0.5) * grid.cell_x
		if world_x < spawn_x_west or world_x > despawn_x_east:
			continue
		for row in grid.rows:
			var world_z := grid.z_far + (float(row) + 0.5) * grid.cell_z
			if world_z > grid.z_near or world_z < grid.z_far:
				continue
			if _noise_field.occupancy(world_x, world_z, _scroll_offset):
				occupancy[Vector2i(col, row)] = true
	return occupancy


func _apply_material_tint() -> void:
	if _master_material == null:
		return
	_master_material.albedo_color = Color(
		_day_tint.r,
		_day_tint.g,
		_day_tint.b,
		_target_alpha
	)
