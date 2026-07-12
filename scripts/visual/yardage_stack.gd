class_name YardageStack
extends Node2D
## Flight-synced yardage counter stack (max 2). Newest sits at the base
## anchor; older entries bump upward when a new strike begins.
## Yards count with one decimal in a fixed-width slot so "yds" never shifts.

const MAX_ENTRIES := 2
const BUMP_STEP_Y := -24.0
const BUMP_DURATION_SEC := 0.15
const HOLD_SEC := 0.35
const FADE_SEC := 1.0
## Higher in the frame so text clears the tree line / fairway stripes.
const BASE_TEXT_OFFSET := Vector2(0.0, -72.0)
const OLDER_DIM := 0.78
const TIER_FONT_SIZE := 7
const YARDS_FONT_SIZE := 10
const TIER_COLOR_DIM := 0.88
const OUTLINE_COLOR := Color(0.2, 0.15, 0.1, 0.85)
const OUTLINE_SIZE := 1
## Soft lift while the ball travels (negative Y = up).
const RISE_PX := -8.0
const SETTLE_SCALE := 1.1
const SETTLE_UP_SEC := 0.06
const SETTLE_DOWN_SEC := 0.1
const META_LIFE_TWEEN := &"life_tween"
const META_BUMP_TWEEN := &"bump_tween"
const META_SETTLE_TWEEN := &"settle_tween"

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
	var t := clampf(progress, 0.0, 1.0)
	var yards: float = float(entry["final_yards"])
	_write_yards(entry, yards * t)
	entry["rise_y"] = RISE_PX * t
	_sync_root_y(entry, false)


func finish(id: int) -> void:
	var entry := _find_entry(id)
	if entry.is_empty():
		return
	if entry.get("finished", false):
		return
	entry["finished"] = true
	_write_yards(entry, float(entry["final_yards"]))
	entry["rise_y"] = RISE_PX
	_sync_root_y(entry, false)
	_play_settle_then_life(entry)


static func format_yards(yards: float) -> String:
	return "%.1f" % yards


func _make_entry(id: int, tier: int, final_yards: float) -> Dictionary:
	var root := Node2D.new()
	root.z_as_relative = false
	root.z_index = 2
	add_child(root)

	var tier_name := Balance.TIER_NAMES[tier]
	var color: Color = Balance.TIER_COLORS[tier]
	var tier_color := Color(
		color.r * TIER_COLOR_DIM,
		color.g * TIER_COLOR_DIM,
		color.b * TIER_COLOR_DIM,
		color.a
	)
	var final_str := format_yards(final_yards)

	var tier_label := _make_styled_label(
		tier_name, tier_color, HORIZONTAL_ALIGNMENT_CENTER, TIER_FONT_SIZE
	)
	var yards_label := _make_styled_label(
		final_str, color, HORIZONTAL_ALIGNMENT_RIGHT, YARDS_FONT_SIZE
	)
	yards_label.reset_size()
	var num_width := yards_label.get_minimum_size().x
	yards_label.custom_minimum_size = Vector2(num_width, 0)
	yards_label.size = Vector2(num_width, yards_label.get_minimum_size().y)
	yards_label.text = format_yards(0.0)

	var unit_label := _make_styled_label(
		" yds", color, HORIZONTAL_ALIGNMENT_LEFT, YARDS_FONT_SIZE
	)

	root.add_child(tier_label)
	root.add_child(yards_label)
	root.add_child(unit_label)
	_layout_entry(tier_label, yards_label, unit_label, num_width)

	return {
		"id": id,
		"root": root,
		"tier_label": tier_label,
		"yards_label": yards_label,
		"unit_label": unit_label,
		"tier": tier,
		"final_yards": final_yards,
		"finished": false,
		"base_y": 0.0,
		"rise_y": 0.0,
	}


func _make_styled_label(
	text: String,
	color: Color,
	align: HorizontalAlignment,
	font_size: int
) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelFont.apply_label(label, font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override(&"outline_size", OUTLINE_SIZE)
	return label


func _layout_entry(
	tier_label: Label,
	yards_label: Label,
	unit_label: Label,
	num_width: float
) -> void:
	tier_label.reset_size()
	yards_label.reset_size()
	unit_label.reset_size()
	var tier_size := tier_label.get_minimum_size()
	var yards_size := yards_label.get_minimum_size()
	var unit_size := unit_label.get_minimum_size()
	var row_w := num_width + unit_size.x
	var row_h := maxf(yards_size.y, unit_size.y)
	var total_h := tier_size.y + row_h
	var top_y := BASE_TEXT_OFFSET.y - total_h

	tier_label.position = Vector2(BASE_TEXT_OFFSET.x - tier_size.x * 0.5, top_y)
	var row_x := BASE_TEXT_OFFSET.x - row_w * 0.5
	var row_y := top_y + tier_size.y
	yards_label.position = Vector2(row_x, row_y)
	unit_label.position = Vector2(row_x + num_width, row_y)


func _write_yards(entry: Dictionary, shown_yards: float) -> void:
	var yards_label: Label = entry.get("yards_label")
	if yards_label == null or not is_instance_valid(yards_label):
		return
	yards_label.text = format_yards(shown_yards)
	var slot_w := yards_label.custom_minimum_size.x
	if slot_w > 0.0:
		yards_label.size = Vector2(slot_w, yards_label.get_minimum_size().y)


func _sync_root_y(entry: Dictionary, animate: bool) -> void:
	var root: Node2D = entry.get("root")
	if root == null or not is_instance_valid(root):
		return
	var target_y := float(entry.get("base_y", 0.0)) + float(entry.get("rise_y", 0.0))
	_kill_bump(root)
	if not animate:
		root.position.y = target_y
		return
	var tween := create_tween()
	root.set_meta(META_BUMP_TWEEN, tween)
	tween.tween_property(root, "position:y", target_y, BUMP_DURATION_SEC)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _bump_existing() -> void:
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		entry["base_y"] = float(entry.get("base_y", 0.0)) + BUMP_STEP_Y
		_sync_root_y(entry, true)


func _trim_overflow() -> void:
	while _entries.size() >= MAX_ENTRIES:
		var oldest: Dictionary = _entries[_entries.size() - 1]
		_discard_entry(oldest)


func _refresh_dimming() -> void:
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		var root: Node2D = entry.get("root")
		if root == null or not is_instance_valid(root):
			continue
		var dim := 1.0 if i == 0 else OLDER_DIM
		root.modulate = Color(dim, dim, dim, root.modulate.a)


func _play_settle_then_life(entry: Dictionary) -> void:
	var root: Node2D = entry.get("root")
	if root == null or not is_instance_valid(root):
		_discard_entry(entry)
		return
	_kill_settle(root)
	_kill_life(root)
	var tween := create_tween()
	root.set_meta(META_SETTLE_TWEEN, tween)
	tween.tween_property(root, "scale", Vector2(SETTLE_SCALE, SETTLE_SCALE), SETTLE_UP_SEC)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "scale", Vector2.ONE, SETTLE_DOWN_SEC)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_play_life.bind(entry))


func _play_life(entry: Dictionary) -> void:
	var root: Node2D = entry.get("root")
	if root == null or not is_instance_valid(root):
		_discard_entry(entry)
		return
	_kill_life(root)
	var tween := create_tween()
	root.set_meta(META_LIFE_TWEEN, tween)
	tween.tween_interval(HOLD_SEC)
	tween.tween_property(root, "modulate:a", 0.0, FADE_SEC)\
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
	_kill_settle(root)
	if root.get_parent() == self:
		remove_child(root)
	root.queue_free()


func _find_entry(id: int) -> Dictionary:
	for entry in _entries:
		if int(entry.get("id", -1)) == id:
			return entry
	return {}


func _kill_life(root: Node) -> void:
	_kill_meta_tween(root, META_LIFE_TWEEN)


func _kill_bump(root: Node) -> void:
	_kill_meta_tween(root, META_BUMP_TWEEN)


func _kill_settle(root: Node) -> void:
	_kill_meta_tween(root, META_SETTLE_TWEEN)


func _kill_meta_tween(root: Node, meta: StringName) -> void:
	if root == null or not root.has_meta(meta):
		return
	var tw: Variant = root.get_meta(meta)
	root.remove_meta(meta)
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
