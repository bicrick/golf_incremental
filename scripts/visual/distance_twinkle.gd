class_name DistanceTwinkle
extends Node2D
## Pokemon-style sparkle burst when a ball vanishes over the horizon.

const STAR_TEX := preload(
	"res://assets/imported/dinky_tiny_golf/Dinky_Tiny_Golf_Free/Singles/Star.png"
)
const SPARK_COUNT := 6
const DURATION_SEC := 0.6


static func spawn(parent: Node2D, world_pos: Vector2) -> void:
	var fx := DistanceTwinkle.new()
	parent.add_child(fx)
	fx.position = world_pos
	fx.z_index = 4
	fx.z_as_relative = false
	fx._play()


func _play() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var flash := Polygon2D.new()
	flash.color = Color(1.0, 0.98, 0.82, 0.85)
	flash.polygon = PackedVector2Array([
		Vector2(-3, 0), Vector2(0, -3), Vector2(3, 0), Vector2(0, 3),
	])
	add_child(flash)

	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(2.2, 2.2), 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.28)

	for i in SPARK_COUNT:
		var star := Sprite2D.new()
		star.texture = STAR_TEX
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.centered = true
		var angle := TAU * float(i) / float(SPARK_COUNT) + rng.randf_range(-0.25, 0.25)
		var dist := rng.randf_range(3.0, 10.0)
		star.position = Vector2(cos(angle), sin(angle)) * dist
		star.scale = Vector2.ZERO
		star.modulate = Color(1.0, 0.92, 0.45, 0.0)
		add_child(star)

		var delay := rng.randf_range(0.0, 0.06)
		var pop := create_tween()
		pop.tween_interval(delay)
		pop.tween_property(star, "scale", Vector2(0.9, 0.9), 0.1)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.parallel().tween_property(star, "modulate", Color(1.0, 0.98, 0.72, 1.0), 0.08)
		pop.chain().tween_property(star, "modulate:a", 0.0, 0.32)
		pop.parallel().tween_property(star, "scale", Vector2(0.15, 0.15), 0.32)

	var cleanup := create_tween()
	cleanup.tween_interval(DURATION_SEC)
	cleanup.tween_callback(queue_free)
