class_name HitPoof
extends Node2D
## Turf-peel divot burst at ball contact — cup mark, scratch line, atlas grass/dirt chunks.

const ATLAS := preload("res://assets/sprites/fairway/grass_plus_atlas.png")
const TILE_PX := 16

const DURATION_SEC := 0.45
const CUP_FADE_SEC := 0.38
const SCRATCH_FADE_SEC := 0.50
const CHUNK_BASE_COUNT := 8
const CHUNK_MAX_COUNT := 12
const SPRAY_HALF_ANGLE := 0.44

const EARTH_COLOR := Color(0.32, 0.22, 0.12, 0.55)
const GRASS_LIP_COLOR := Color(0.38, 0.58, 0.34, 0.65)
const SCRATCH_COLOR := Color(0.32, 0.22, 0.12, 0.70)
const DIRT_PIXEL_COLOR := Color(0.48, 0.34, 0.20, 0.90)

const GRASS_TILES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
]

var _timing_tier: int = Balance.TimingTier.GOOD
var _rng := RandomNumberGenerator.new()


static func spawn(
	parent: Node2D,
	world_pos: Vector2,
	fairway_dir: Vector2,
	timing_tier: int = 0,
	_feedback_tier: int = 0
) -> void:
	var fx := HitPoof.new()
	parent.add_child(fx)
	fx.position = world_pos
	fx.z_as_relative = false
	fx.z_index = 5
	fx._timing_tier = timing_tier
	var dir := fairway_dir
	if dir.length_squared() < 0.0001:
		dir = Vector2(0.0, -1.0)
	else:
		dir = dir.normalized()
	fx.rotation = dir.angle() + PI / 2.0
	fx._play()


func _play() -> void:
	_rng.randomize()
	var intensity := _intensity_from_tier(_timing_tier)
	var forward := Vector2(0.0, -1.0)
	var sideways := Vector2(1.0, 0.0)
	_spawn_cup()
	_spawn_scratch(forward)
	_spawn_chunks(forward, sideways, intensity)

	var cleanup := create_tween()
	cleanup.tween_interval(DURATION_SEC + 0.05)
	cleanup.tween_callback(queue_free)


static func _intensity_from_tier(tier: int) -> Dictionary:
	var clamped := clampi(tier, 0, Balance.TimingTier.MISS)
	var quality := 1.0 - float(clamped) / float(Balance.TimingTier.MISS)
	var count := CHUNK_BASE_COUNT + int(
		round(quality * float(CHUNK_MAX_COUNT - CHUNK_BASE_COUNT))
	)
	return {
		"count": clampi(count, CHUNK_BASE_COUNT, CHUNK_MAX_COUNT),
		"spread": lerpf(0.85, 1.15, quality),
	}


static func _make_atlas_texture(col: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = ATLAS
	atlas.region = Rect2i(col * TILE_PX, row * TILE_PX, TILE_PX, TILE_PX)
	return atlas


func _spawn_cup() -> void:
	var earth := Polygon2D.new()
	earth.color = EARTH_COLOR
	earth.polygon = PackedVector2Array([
		Vector2(-1.0, 0.6), Vector2(1.0, 0.6),
		Vector2(0.65, -3.2), Vector2(-0.65, -3.2),
	])
	earth.scale = Vector2(0.25, 0.25)
	add_child(earth)

	var lip := Polygon2D.new()
	lip.color = GRASS_LIP_COLOR
	lip.polygon = PackedVector2Array([
		Vector2(-1.5, 1.1), Vector2(1.5, 1.1),
		Vector2(1.1, 0.35), Vector2(-1.1, 0.35),
	])
	lip.scale = Vector2(0.25, 0.25)
	add_child(lip)

	var earth_tween := create_tween()
	earth_tween.tween_property(earth, "scale", Vector2(1.0, 1.0), 0.07)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	earth_tween.tween_interval(0.04)
	earth_tween.tween_property(earth, "modulate:a", 0.0, CUP_FADE_SEC - 0.11)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var lip_tween := create_tween()
	lip_tween.tween_property(lip, "scale", Vector2(1.05, 1.05), 0.06)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lip_tween.tween_interval(0.05)
	lip_tween.tween_property(lip, "modulate:a", 0.0, CUP_FADE_SEC - 0.11)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _spawn_scratch(forward: Vector2) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = SCRATCH_COLOR
	line.antialiased = false
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = PackedVector2Array([
		Vector2(0.0, 0.8),
		forward * 3.5 + Vector2(-0.4, 0.0),
		forward * 7.5 + Vector2(0.3, 0.0),
		forward * 11.0 + Vector2(-0.2, 0.0),
	])
	line.modulate.a = 0.0
	add_child(line)

	var scratch_tween := create_tween()
	scratch_tween.tween_property(line, "modulate:a", 1.0, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scratch_tween.tween_interval(0.06)
	scratch_tween.tween_property(line, "modulate:a", 0.0, SCRATCH_FADE_SEC - 0.11)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _spawn_chunks(forward: Vector2, sideways: Vector2, intensity: Dictionary) -> void:
	var count: int = intensity["count"]
	var spread_mult: float = intensity["spread"]
	for _i in count:
		var use_dirt := _rng.randf() < 0.35
		var chunk_scale := Vector2(0.18, 0.18)
		var chunk: CanvasItem

		if use_dirt:
			var dirt := Polygon2D.new()
			dirt.color = DIRT_PIXEL_COLOR
			dirt.polygon = PackedVector2Array([
				Vector2(-1.5, -1.5), Vector2(1.5, -1.5),
				Vector2(1.5, 1.5), Vector2(-1.5, 1.5),
			])
			chunk = dirt
			chunk_scale = Vector2(1.0, 1.0)
		else:
			var grass := Sprite2D.new()
			grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			grass.centered = true
			var tile: Vector2i = GRASS_TILES[_rng.randi_range(0, GRASS_TILES.size() - 1)]
			grass.texture = _make_atlas_texture(tile.x, tile.y)
			chunk = grass

		chunk.modulate.a = 0.92
		chunk.rotation = _rng.randf_range(-0.8, 0.8)
		add_child(chunk)

		var dir := (
			forward + sideways * _rng.randf_range(-tan(SPRAY_HALF_ANGLE), tan(SPRAY_HALF_ANGLE))
		).normalized()
		var dist := _rng.randf_range(5.0, 13.0) * spread_mult
		var lift := _rng.randf_range(2.0, 5.5)
		var target_scale: Vector2 = chunk_scale * _rng.randf_range(0.85, 1.15)
		var start := dir * _rng.randf_range(0.2, 0.8)
		var end := dir * dist
		chunk.position = start
		chunk.scale = Vector2.ZERO

		var delay := _rng.randf_range(0.0, 0.04)
		var chunk_tween := create_tween()
		chunk_tween.tween_interval(delay)
		chunk_tween.tween_property(chunk, "scale", target_scale, 0.06)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		chunk_tween.parallel().tween_method(
			func(t: float) -> void:
				if not is_instance_valid(chunk):
					return
				var lift_offset := Vector2(0.0, sin(t * PI) * lift)
				chunk.position = start.lerp(end, t) + lift_offset,
			0.0,
			1.0,
			0.16
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		chunk_tween.chain().tween_property(chunk, "scale", target_scale * 0.35, 0.14)
		chunk_tween.parallel().tween_property(chunk, "modulate:a", 0.0, 0.22)
