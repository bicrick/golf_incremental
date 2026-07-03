class_name CloudNoiseField
extends RefCounted
## Scrolling fBm + density envelope + inversion regime for discretized cloud pixels.

var seed: int = 0
var scale_x: float = 0.04
var scale_z: float = 0.035
var density_scale: float = 0.004
var inversion_scale: float = 0.0015
var fbm_octaves: int = 4
var fbm_lacunarity: float = 2.0
var fbm_gain: float = 0.5
var sparse_threshold: float = 0.58
var dense_threshold: float = 0.45
var empty_density_cutoff: float = 0.15

var _field_noise: FastNoiseLite
var _density_noise: FastNoiseLite
var _inversion_noise: FastNoiseLite


func _init(p_seed: int = 0) -> void:
	seed = p_seed
	_rebuild_noises()


func configure(
	p_seed: int,
	p_scale_x: float,
	p_scale_z: float,
	p_density_scale: float,
	p_inversion_scale: float,
	p_fbm_octaves: int = 4,
	p_sparse_threshold: float = 0.58,
	p_dense_threshold: float = 0.45,
	p_empty_density_cutoff: float = 0.15
) -> void:
	seed = p_seed
	scale_x = p_scale_x
	scale_z = p_scale_z
	density_scale = p_density_scale
	inversion_scale = p_inversion_scale
	fbm_octaves = p_fbm_octaves
	sparse_threshold = p_sparse_threshold
	dense_threshold = p_dense_threshold
	empty_density_cutoff = p_empty_density_cutoff
	_rebuild_noises()


func occupancy(x: float, z: float, scroll_offset: float) -> bool:
	var density := density_at(x, scroll_offset)
	if density < empty_density_cutoff:
		return false
	var scroll_x := x - scroll_offset
	var field_val := _sample_fbm(scroll_x * scale_x, z * scale_z)
	var inversion := inversion_at(x, scroll_offset)
	var blended := lerpf(field_val, 1.0 - field_val, inversion)
	var density_t := inverse_lerp(empty_density_cutoff, 0.92, density)
	var threshold := lerpf(sparse_threshold, dense_threshold, density_t)
	return blended > threshold


func field_value(x: float, z: float, scroll_offset: float) -> float:
	return _sample_fbm((x - scroll_offset) * scale_x, z * scale_z)


func density_at(x: float, scroll_offset: float) -> float:
	return _density_noise.get_noise_1d((x - scroll_offset) * density_scale) * 0.5 + 0.5


func inversion_at(x: float, scroll_offset: float) -> float:
	return _inversion_noise.get_noise_1d((x - scroll_offset) * inversion_scale) * 0.5 + 0.5


func blended_value(x: float, z: float, scroll_offset: float) -> float:
	var field_val := field_value(x, z, scroll_offset)
	var inversion := inversion_at(x, scroll_offset)
	return lerpf(field_val, 1.0 - field_val, inversion)


func threshold_at(x: float, scroll_offset: float) -> float:
	var density := density_at(x, scroll_offset)
	if density < empty_density_cutoff:
		return 1.0
	var density_t := inverse_lerp(empty_density_cutoff, 0.92, density)
	return lerpf(sparse_threshold, dense_threshold, density_t)


func _rebuild_noises() -> void:
	_field_noise = FastNoiseLite.new()
	_field_noise.seed = seed
	_field_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_field_noise.frequency = 1.0
	_field_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_field_noise.fractal_octaves = fbm_octaves
	_field_noise.fractal_lacunarity = fbm_lacunarity
	_field_noise.fractal_gain = fbm_gain

	_density_noise = FastNoiseLite.new()
	_density_noise.seed = seed + 9137
	_density_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_density_noise.frequency = 1.0

	_inversion_noise = FastNoiseLite.new()
	_inversion_noise.seed = seed + 18257
	_inversion_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_inversion_noise.frequency = 1.0


func _sample_fbm(nx: float, nz: float) -> float:
	return _field_noise.get_noise_2d(nx, nz) * 0.5 + 0.5
