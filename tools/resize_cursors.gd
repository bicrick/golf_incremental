extends SceneTree
## One-off: downscale Light cursor pack sources into assets/cursors/.

const JOBS: Array[Dictionary] = [
	{
		"src": "res://Light/Arrows/Arrow2.png",
		"dst": "res://assets/cursors/cursor_arrow.png",
		"scale": 0.5,
	},
	{
		"src": "res://Light/Hands/Hand1.png",
		"dst": "res://assets/cursors/cursor_hand.png",
		"scale": 0.5,
	},
	{
		"src": "res://Light/Hands/Hand_Drag2.png",
		"dst": "res://assets/cursors/cursor_grab.png",
		"scale": 0.5,
	},
]


func _initialize() -> void:
	var ok := true
	for job in JOBS:
		ok = _resize_one(job) and ok
	quit(0 if ok else 1)


func _resize_one(job: Dictionary) -> bool:
	var image := Image.load_from_file(job["src"])
	if image == null:
		push_error("Failed to load cursor source: %s" % job["src"])
		return false
	var scale: float = job["scale"]
	var new_size := Vector2i(
		maxi(1, int(image.get_width() * scale)),
		maxi(1, int(image.get_height() * scale))
	)
	image.resize(new_size.x, new_size.y, Image.INTERPOLATE_NEAREST)
	var err := image.save_png(job["dst"])
	if err != OK:
		push_error("Failed to save cursor: %s (err %s)" % [job["dst"], err])
		return false
	print("Saved %s (%dx%d)" % [job["dst"], new_size.x, new_size.y])
	return true
