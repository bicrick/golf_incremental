class_name StrikeMist
extends Node3D
## v5 — the mist bank. Rows of stylized pixel-art mist puffs (drawn like the
## painted sky cumulus) stand just past the fog line. The same bank exists in
## both views (tee + harvest) so the mist reads as one thing in the world.
##
## • Grounded: each puff is sunk into the fairway; the opaque, depth-tested
##   ground plane cuts its base off, so the bank sits ON the grass.
## • Pixel-matched: every frame each puff's pixel_size is set so one texel ≈ one
##   screen pixel at its distance (perspective or ortho), matching the art.

const PUFFS := [
	"res://assets/sprites/story/mist_puff_a.png",
	"res://assets/sprites/story/mist_puff_b.png",
	"res://assets/sprites/story/mist_puff_c.png",
	"res://assets/sprites/story/mist_puff_d.png",
]
## [yards past the fog line, puffs in the row, texel scale, alpha]
const ROWS := [
	[1.0, 11, 0.62, 0.95],
	[9.0, 10, 0.7, 1.0],
	[22.0, 9, 0.8, 1.0],
	[42.0, 8, 0.9, 1.0],
]
## Fraction of each puff buried below the ground plane.
const SINK := 0.44
## Horizontal overlap: next puff starts this fraction of a width along.
const OVERLAP := 0.62
const DRIFT_TEXELS := 6.0
const TINT_STRENGTH := 0.32
## Clamp so puffs never become sub-pixel mush or giant blobs.
const MIN_PIXEL_SIZE := 0.03
const MAX_PIXEL_SIZE := 0.6

var _puffs: Array[Dictionary] = []
var _tee_z := 0.0
var _time := 0.0
var _tint := Color(0.9, 0.92, 0.9, 1.0)
var _camera_getter: Callable


func setup(tee_z: float, camera_getter: Callable) -> void:
	_tee_z = tee_z
	_camera_getter = camera_getter
	name = "StrikeMist"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var textures: Array[Texture2D] = []
	for path in PUFFS:
		textures.append(load(path))
	for row_i in ROWS.size():
		var row: Array = ROWS[row_i]
		var count := int(row[1])
		for slot in count:
			var sprite := Sprite3D.new()
			sprite.texture = textures[rng.randi() % textures.size()]
			sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.shaded = false
			sprite.double_sided = true
			sprite.flip_h = rng.randf() < 0.5
			## Farther rows draw first so nearer puffs overlap them.
			sprite.render_priority = ROWS.size() - row_i
			add_child(sprite)
			_puffs.append({
				"sprite": sprite,
				"row": row_i,
				## Slot position across the row, centred on the fairway.
				"u": float(slot) - float(count - 1) * 0.5 + rng.randf_range(-0.25, 0.25),
				"phase": rng.randf_range(0.0, TAU),
				"w": float(sprite.texture.get_width()),
				"h": float(sprite.texture.get_height()),
			})


func set_mist_color(c: Color) -> void:
	_tint = Color(0.97, 0.97, 0.95).lerp(c, TINT_STRENGTH)


## Yards per screen pixel at `world_pos` for the active camera.
func _yards_per_pixel(cam: Camera3D, world_pos: Vector3) -> float:
	var vp_h := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return cam.size / vp_h
	var d := maxf(-cam.global_transform.basis.z.dot(world_pos - cam.global_position), 0.5)
	return 2.0 * d * tan(deg_to_rad(cam.fov) * 0.5) / vp_h


## `reveal_yards` is the fog line (same value the ground fog uses).
func update(delta: float, reveal_yards: float) -> void:
	_time += delta
	visible = not GameState.story_complete
	if not visible:
		return
	var cam: Camera3D = _camera_getter.call() if _camera_getter.is_valid() else null
	if cam == null:
		return
	for p in _puffs:
		var row: Array = ROWS[int(p["row"])]
		var yards := reveal_yards + float(row[0])
		var sprite: Sprite3D = p["sprite"]
		## Past the far edge of the range there's nothing to hide.
		sprite.visible = yards < RangeGrid.DEPTH_YARDS + 70.0
		if not sprite.visible:
			continue
		var z := _tee_z - yards
		var px := clampf(
			_yards_per_pixel(cam, Vector3(0.0, 0.0, z)) * float(row[2]),
			MIN_PIXEL_SIZE,
			MAX_PIXEL_SIZE
		)
		sprite.pixel_size = px
		var w := float(p["w"]) * px
		var h := float(p["h"]) * px
		var drift := sin(_time * 0.1 + float(p["phase"])) * DRIFT_TEXELS * px
		sprite.position = Vector3(
			float(p["u"]) * w * OVERLAP + drift,
			h * (0.5 - SINK),
			z
		)
		var c := _tint
		c.a = float(row[3])
		sprite.modulate = c
