extends SceneTree
## Temporary probe — headless capture test for the 3D range view camera framing.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var scene: Node = load("res://scenes/range/range_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	var err: Error = await scene.capture_plate("res://captures/_probe_current.png", 24.0)
	print("capture err=", err)
	quit(0)
