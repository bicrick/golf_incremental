extends SceneTree
## Temporary probe — not a permanent verify script. Prints screen-space
## projection of golfer feet/head/ball for camera framing tuning.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/range/range_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var camera: Camera3D = scene.get_node("Camera3D")
	var golfer: Node3D = scene.get_node("Foreground/Golfer")
	var ball: Node3D = scene.get_node("Foreground/Ball")

	var viewport_size := root.get_viewport().get_visible_rect().size
	print("viewport_size=", viewport_size)
	print("content_scale_size=", root.content_scale_size, " stretch=", root.content_scale_mode)

	# Simulate a wider real window (canvas_items stretch keeps 3D rendering at
	# actual window pixels, not the base 480x270 content_scale_size).
	root.size = Vector2i(1920, 1080)
	await process_frame
	print("--- after resizing root window to 1920x1080 ---")
	print("viewport_size now=", root.get_viewport().get_visible_rect().size)
	print("camera keep_aspect=", camera.keep_aspect, " fov=", camera.fov)
	print("camera global_pos=", camera.global_position, " rot_deg=", camera.rotation_degrees)
	print("golfer pos=", golfer.global_position, " offset=", golfer.offset, " pixel_size=", golfer.pixel_size)
	print("ball pos=", ball.global_position, " pixel_size=", ball.pixel_size)

	var feet_screen: Vector2 = camera.unproject_position(golfer.global_position)
	print("golfer feet screen=", feet_screen, " behind_cam=", camera.is_position_behind(golfer.global_position))

	var head_world: Vector3 = golfer.global_position + Vector3(0, 52.0 * golfer.pixel_size, 0)
	var head_screen: Vector2 = camera.unproject_position(head_world)
	print("golfer head screen=", head_screen)

	var ball_screen: Vector2 = camera.unproject_position(ball.global_position)
	print("ball screen=", ball_screen)

	var feet_screen2: Vector2 = camera.unproject_position(golfer.global_position)
	var head_screen2: Vector2 = camera.unproject_position(head_world)
	print("golfer feet screen (1920x1080)=", feet_screen2, " frac=", feet_screen2.y / 1080.0)
	print("golfer head screen (1920x1080)=", head_screen2, " frac=", head_screen2.y / 1080.0)

	var aabb: AABB = golfer.get_aabb()
	print("golfer LOCAL aabb=", aabb, " -> world y range=", golfer.global_position.y + aabb.position.y, " to ", golfer.global_position.y + aabb.position.y + aabb.size.y)
	var ball_aabb: AABB = ball.get_aabb()
	print("ball LOCAL aabb=", ball_aabb)
	var ground: MeshInstance3D = scene.get_node("Ground")
	print("ground aabb=", ground.get_aabb() if ground.mesh else "no mesh")

	quit(0)
