class_name GoldenBallAura
extends Node2D
## Brief gold pixel burst when a golden ball is collected.

const PARTICLE_COUNT := 5
const DURATION_SEC := 0.32

var _camera: Camera3D
var _world_pos: Vector3
var _reference_ortho_size: float = 0.0
var _rng := RandomNumberGenerator.new()


static func spawn_pickup(
	parent: Node2D,
	camera: Camera3D,
	world_pos: Vector3,
	reference_ortho_size: float = 0.0
) -> void:
	var fx: Node2D = load("res://scripts/visual/golden_ball_aura.gd").new()
	fx._camera = camera
	fx._world_pos = world_pos
	fx._reference_ortho_size = reference_ortho_size if reference_ortho_size > 0.0 else camera.size
	parent.add_child(fx)
	fx.z_index = 4
	fx.z_as_relative = false
	fx._rng.randomize()
	fx.set_process(true)
	fx._update_anchor()
	fx._play()


func _process(_delta: float) -> void:
	_update_anchor()


func _update_anchor() -> void:
	if _camera == null:
		return
	position = _project_to_local(_world_pos)
	var zoom := ScreenFxScale.compensation(_camera, _reference_ortho_size)
	scale = Vector2.ONE * zoom


func _project_to_local(world_pos: Vector3) -> Vector2:
	var screen := _camera.unproject_position(world_pos)
	if get_parent() is Node2D:
		return get_parent().to_local(screen)
	return screen


func _play() -> void:
	for _i in PARTICLE_COUNT:
		var dot := Polygon2D.new()
		dot.color = Balance.GOLDEN_SPARKLE_COLOR
		dot.polygon = PackedVector2Array([
			Vector2(-0.5, -0.5), Vector2(0.5, -0.5),
			Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
		])
		dot.scale = Vector2.ZERO
		dot.modulate.a = 0.0
		add_child(dot)

		var angle := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(2.0, 6.0)
		var drift := Vector2(cos(angle), sin(angle)) * dist
		var target_scale := Vector2.ONE * _rng.randf_range(0.45, 0.75)

		var tween := create_tween()
		tween.tween_property(dot, "scale", target_scale, 0.05)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(dot, "modulate:a", 0.85, 0.04)
		tween.chain().tween_property(dot, "position", drift, 0.18)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(dot, "modulate:a", 0.0, 0.18)
		tween.parallel().tween_property(dot, "scale", target_scale * 0.35, 0.18)

	var cleanup := create_tween()
	cleanup.tween_interval(DURATION_SEC)
	cleanup.tween_callback(queue_free)
