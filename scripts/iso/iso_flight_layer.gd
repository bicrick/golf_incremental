class_name IsoFlightLayer
extends Node
## Mirrors 3D in-flight balls (group range_flight_ball) into iso sprites + trails.
## Optionally drives IsoCameraController follow while a ball is airborne.

const FLIGHT_GROUP := &"range_flight_ball"
const VANISH_FADE_SEC := 0.25

const IsoActorMirrorScript := preload("res://scripts/iso/iso_actor_mirror.gd")
const IsoBallTrailScript := preload("res://scripts/iso/iso_ball_trail.gd")

var _flights_root: Node2D
var _trails_root: Node2D
var _camera: Camera2D
var _camera_controller: IsoCameraController
var _enabled := false
## int instance_id -> { "mirror": IsoActorMirror, "trail": Node2D, "follow": bool }
var _active: Dictionary = {}


func setup(
	flights_root: Node2D,
	trails_root: Node2D,
	camera: Camera2D,
	camera_controller: IsoCameraController
) -> void:
	_flights_root = flights_root
	_trails_root = trails_root
	_camera = camera
	_camera_controller = camera_controller


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process(enabled)
	if not enabled:
		_clear_all()
		if _camera_controller:
			_camera_controller.cancel_follow()


func get_active_count() -> int:
	return _active.size()


func get_mirror_for_source(src: Node) -> IsoActorMirror:
	if src == null:
		return null
	var entry: Variant = _active.get(src.get_instance_id())
	if entry == null:
		return null
	return entry.get("mirror") as IsoActorMirror


func get_trail_for_source(src: Node) -> Node2D:
	if src == null:
		return null
	var entry: Variant = _active.get(src.get_instance_id())
	if entry == null:
		return null
	return entry.get("trail") as Node2D


func _process(_delta: float) -> void:
	if not _enabled:
		return
	var tree := get_tree()
	if tree == null:
		return
	var seen: Dictionary = {}
	var follow_px := Vector2.ZERO
	var have_follow := false
	for node in tree.get_nodes_in_group(FLIGHT_GROUP):
		if node == null or not is_instance_valid(node):
			continue
		if not node is SpriteBase3D:
			continue
		var src := node as SpriteBase3D
		var id := src.get_instance_id()
		seen[id] = true
		if not _active.has(id):
			_spawn_entry(src)
		var entry: Dictionary = _active[id]
		var trail_v: Variant = entry.get("trail")
		if trail_v is Node and is_instance_valid(trail_v) and trail_v.has_method(&"track"):
			trail_v.track(src.global_position)
		var px := IsoGrid.iso_px_from_yards(src.global_position)
		if not have_follow:
			follow_px = px
			have_follow = true
		else:
			## Prefer the newest / further-along ball for follow (last in group order).
			follow_px = px
	if have_follow and _camera_controller != null:
		_camera_controller.follow_world_px(follow_px)
	## Drop entries whose source left the group / was freed.
	var stale: Array = []
	for id in _active.keys():
		if not seen.has(id):
			stale.append(id)
	for id in stale:
		_finish_entry(int(id))
	if not have_follow and _camera_controller != null and _active.is_empty():
		_camera_controller.stop_follow_soft()


func _spawn_entry(src: SpriteBase3D) -> void:
	var mirror: IsoActorMirror = IsoActorMirrorScript.new()
	mirror.name = "FlightMirror_%d" % src.get_instance_id()
	mirror.z_index = 5
	_flights_root.add_child(mirror)
	## Ball scale follows PlayerBallPlaceholder when authored on IsoView.
	var ball_ph: Node2D = null
	var iso := get_parent() as IsoView
	if iso != null and iso.actor_layer != null:
		ball_ph = IsoEditorPlaceholders.ball_node(iso.actor_layer)
	## Scale only — flight altitude uses yards→iso; placeholder pose is for tee rest.
	mirror.setup(src, false, true, ball_ph, Vector3.ZERO, false)

	var timing_tier := Balance.TimingTier.GOOD
	if src.has_meta("timing_tier"):
		timing_tier = int(src.get_meta("timing_tier"))
	var color_override := Color.TRANSPARENT
	if src.has_meta("is_golden") and bool(src.get_meta("is_golden")):
		color_override = Balance.GOLDEN_TRAIL_COLOR

	var trail: Node2D = null
	if _trails_root != null and _camera != null:
		trail = IsoBallTrailScript.begin(_trails_root, _camera, timing_tier, color_override)
		trail.track(src.global_position)

	_active[src.get_instance_id()] = {
		"mirror": mirror,
		"trail": trail,
		## Cached so finish still works after the 3D sprite is freed on land.
		"with_bounces": (
			bool(src.get_meta("with_bounces")) if src.has_meta("with_bounces") else true
		),
	}


func _finish_entry(id: int) -> void:
	if not _active.has(id):
		return
	var entry: Dictionary = _active[id]
	_active.erase(id)
	## Untyped get — typed assign of a freed Object throws before is_instance_valid.
	var trail_v: Variant = entry.get("trail")
	if trail_v is Node and is_instance_valid(trail_v) and trail_v.has_method(&"finish"):
		trail_v.finish()
	var will_litter := bool(entry.get("with_bounces", true))
	var mirror_v: Variant = entry.get("mirror")
	if mirror_v is Node and is_instance_valid(mirror_v):
		var mirror: Node = mirror_v
		if will_litter:
			mirror.queue_free()
		else:
			## Vanish: fade out so the ball does not pop at the far edge.
			var tween := mirror.create_tween()
			tween.tween_property(mirror, "modulate:a", 0.0, VANISH_FADE_SEC)
			tween.tween_callback(mirror.queue_free)


func _clear_all() -> void:
	var ids: Array = _active.keys()
	for id in ids:
		var entry: Dictionary = _active[id]
		var trail_v: Variant = entry.get("trail")
		if trail_v is Node and is_instance_valid(trail_v):
			trail_v.queue_free()
		var mirror_v: Variant = entry.get("mirror")
		if mirror_v is Node and is_instance_valid(mirror_v):
			mirror_v.queue_free()
	_active.clear()
