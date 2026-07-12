class_name YardageStack
extends Node2D
## Flight-synced yardage counter stack (max 2). Newest sits at the base
## anchor; older entries bump upward when a new strike begins.

const MAX_ENTRIES := 2
const BUMP_STEP_Y := -20.0
const BUMP_DURATION_SEC := 0.15
const HOLD_SEC := 0.35
const FADE_SEC := 1.0
const BASE_TEXT_OFFSET := Vector2(0.0, -38.0)
const OLDER_DIM := 0.78
const META_LIFE_TWEEN := &"life_tween"
const META_BUMP_TWEEN := &"bump_tween"

var _next_id: int = 1
## Newest-first: index 0 is the active/base entry.
var _entries: Array[Dictionary] = []


func begin(tier: int, final_yards: float) -> int:
	_bump_existing()
	_trim_overflow()
	var id := _next_id
	_next_id += 1
	var entry := _make_entry(id, tier, final_yards)
	_entries.push_front(entry)
	_refresh_dimming()
	return id


func set_progress(id: int, progress: float) -> void:
	var entry := _find_entry(id)
	if entry.is_empty():
		return
	if entry.get("finished", false):
		return
	var yards: float = float(entry["final_yards"])
	var shown := int(round(yards * clampf(progress, 0.0, 1.0)))
	_write_yards(entry, shown)


func finish(id: int) -> void:
	var entry := _find_entry(id)
	if entry.is_empty():
		return
	if entry.get("finished", false):
		return
	entry["finished"] = true
	_write_yards(entry, int(round(float(entry["final_yards"]))))
	_play_life(entry)


func _make_entry(id: int, tier: int, final_yards: float) -> Dictionary:
	var root := Node2D.new()
	root.z_as_relative = false
	root.z_index = 2
	add_child(root)

	var tier_name := Balance.TIER_NAMES[tier]
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelFont.apply_label(label, 8)
	label.modulate = Balance.TIER_COLORS[tier]
	label.text = "%s\n%d yds" % [tier_name, 0]
	root.add_child(label)
	label.reset_size()
	var size := label.get_minimum_size()
	label.position = Vector2(
		BASE_TEXT_OFFSET.x - size.x * 0.5,
		BASE_TEXT_OFFSET.y - size.y
	)

	var entry := {
		"id": id,
		"root": root,
		"label": label,
		"tier": tier,
		"tier_name": tier_name,
		"final_yards": final_yards,
		"finished": false,
		"base_y": 0.0,
	}
	return entry


func _write_yards(entry: Dictionary, shown_yards: int) -> void:
	var label: Label = entry["label"]
	if label == null or not is_instance_valid(label):
		return
	label.text = "%s\n%d yds" % [String(entry["tier_name"]), shown_yards]
	label.reset_size()
	var size := label.get_minimum_size()
	# Keep centered as digit width changes.
	label.position.x = BASE_TEXT_OFFSET.x - size.x * 0.5
	label.position.y = BASE_TEXT_OFFSET.y - size.y


func _bump_existing() -> void:
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		var root: Node2D = entry.get("root")
		if root == null or not is_instance_valid(root):
			continue
		var target_y := float(entry.get("base_y", 0.0)) + BUMP_STEP_Y
		entry["base_y"] = target_y
		_kill_bump(root)
		var tween := create_tween()
		root.set_meta(META_BUMP_TWEEN, tween)
		tween.tween_property(root, "position:y", target_y, BUMP_DURATION_SEC)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _trim_overflow() -> void:
	while _entries.size() >= MAX_ENTRIES:
		var oldest: Dictionary = _entries[_entries.size() - 1]
		_discard_entry(oldest)


func _refresh_dimming() -> void:
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		var label: Label = entry.get("label")
		if label == null or not is_instance_valid(label):
			continue
		var dim := 1.0 if i == 0 else OLDER_DIM
		var color: Color = Balance.TIER_COLORS[int(entry["tier"])]
		label.modulate = Color(color.r * dim, color.g * dim, color.b * dim, label.modulate.a)


func _play_life(entry: Dictionary) -> void:
	var root: Node2D = entry.get("root")
	var label: Label = entry.get("label")
	if root == null or not is_instance_valid(root) or label == null or not is_instance_valid(label):
		_discard_entry(entry)
		return
	_kill_life(root)
	var tween := create_tween()
	root.set_meta(META_LIFE_TWEEN, tween)
	tween.tween_interval(HOLD_SEC)
	tween.tween_property(label, "modulate:a", 0.0, FADE_SEC)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_life_finished.bind(entry))


func _on_life_finished(entry: Dictionary) -> void:
	_discard_entry(entry)


func _discard_entry(entry: Dictionary) -> void:
	var idx := _entries.find(entry)
	if idx >= 0:
		_entries.remove_at(idx)
	var root: Node2D = entry.get("root")
	if root == null or not is_instance_valid(root):
		return
	_kill_life(root)
	_kill_bump(root)
	if root.get_parent() == self:
		remove_child(root)
	root.queue_free()


func _find_entry(id: int) -> Dictionary:
	for entry in _entries:
		if int(entry.get("id", -1)) == id:
			return entry
	return {}


func _kill_life(root: Node) -> void:
	if root == null or not root.has_meta(META_LIFE_TWEEN):
		return
	var life: Variant = root.get_meta(META_LIFE_TWEEN)
	root.remove_meta(META_LIFE_TWEEN)
	if life is Tween and (life as Tween).is_valid():
		(life as Tween).kill()


func _kill_bump(root: Node) -> void:
	if root == null or not root.has_meta(META_BUMP_TWEEN):
		return
	var bump: Variant = root.get_meta(META_BUMP_TWEEN)
	root.remove_meta(META_BUMP_TWEEN)
	if bump is Tween and (bump as Tween).is_valid():
		(bump as Tween).kill()
