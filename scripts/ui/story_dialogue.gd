extends Control
## v5 story dialogue — queues speaker lines through the rat thought box.
## Owns: find-claim lines, target hints, "the mist pulled back" announcements,
## the first-mist intro, and the hand-off into the finale.

const ThoughtBoxScript = preload("res://scripts/ui/tutorial_thought_box.gd")

var _box: Control
var _queue: Array = [] # of [speaker, text]
var _on_done: Array[Callable] = []
var _playing := false
var _director: Node = null


func _ready() -> void:
	add_to_group(&"story_dialogue")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_box = ThoughtBoxScript.new()
	_box.name = "StoryThoughtBox"
	add_child(_box)
	_box.dismissed.connect(_on_box_dismissed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.story_find_triggered.connect(_on_find_triggered)
	call_deferred("_bind_director")


func _bind_director() -> void:
	var range_view := get_tree().root.get_node_or_null("Main/RangeView")
	if range_view == null:
		return
	_director = range_view.get_node_or_null("Foreground/StoryFinds")
	if _director != null and not _director.find_clicked.is_connected(_on_find_clicked):
		_director.find_clicked.connect(_on_find_clicked)


func apply_viewport_layout() -> void:
	if _box != null and _box.has_method("apply_viewport_layout"):
		_box.apply_viewport_layout()


func is_blocking_input() -> bool:
	return _playing and _box != null and _box.is_open() and _box.blocks_world_input()


func is_busy() -> bool:
	return _playing


## Queue lines. Each entry is [speaker, text]; speaker "note" takes a note key.
func play(lines: Array, on_done: Callable = Callable()) -> void:
	for line in lines:
		var speaker := String(line[0])
		var text := String(line[1])
		if speaker == "note":
			text = StoryScript.note_text(text)
		_queue.append([speaker, text])
	if on_done.is_valid():
		_on_done.append(on_done)
	if not _playing:
		_next()


func say(text: String, speaker: String = "rat") -> void:
	play([[speaker, text]])


func _tutorial_box_open() -> bool:
	var overlay := get_tree().get_first_node_in_group(&"tutorial_overlay")
	if overlay == null:
		return false
	var box: Node = overlay.get_node_or_null("ThoughtBox")
	return box != null and box.has_method("is_open") and box.is_open()


func _next() -> void:
	if _queue.is_empty():
		_playing = false
		var callbacks := _on_done.duplicate()
		_on_done.clear()
		for cb in callbacks:
			if cb.is_valid():
				cb.call()
		return
	if _tutorial_box_open():
		## Wait for the tutorial/welcome line to clear before speaking.
		_playing = true
		get_tree().create_timer(0.4).timeout.connect(_next)
		return
	_playing = true
	var line: Array = _queue.pop_front()
	_box.show_thought(String(line[1]), false, TutorialUiPreviews.Kind.NONE, {"speaker": line[0]})


func _on_box_dismissed() -> void:
	_box.hide_thought()
	_next()


# --- story beats -----------------------------------------------------------------


func _on_find_clicked(id: String, claimable: bool) -> void:
	if _playing:
		return
	if not claimable:
		var hint := StoryScript.hint_lines_for(id)
		if not hint.is_empty():
			play(hint)
		return
	if not GameState.discover_find(id):
		return
	var sfx := get_node_or_null("/root/SfxManager")
	if sfx != null and sfx.has_method("play_story_discover"):
		sfx.play_story_discover()
	var lines := StoryScript.lines_for_find(id, GameState.ratina_unlocked)
	var reward := StoryFinds.reward_text(id)
	if not reward.is_empty() and id != "first_green":
		lines.append(["rat", "(%s)" % reward])
	var done := Callable()
	if id == "first_green":
		done = _arm_last_ball
	play(lines, done)


func _arm_last_ball() -> void:
	## Back to the tee with one ball — the harvest leftovers stay put.
	if GameState.is_harvest_phase():
		GameState.exit_harvest_early()
	if GameState.bucket_remaining <= 0:
		GameState.bucket_remaining = 1
		EventBus.bucket_changed.emit(GameState.bucket_remaining, GameState.bucket_capacity)
	say(StoryScript.FINALE_ARMED_LINE)


func _on_find_triggered(id: String) -> void:
	var line := String(StoryScript.TARGET_TRIGGERED.get(id, ""))
	if line.is_empty():
		return
	say(line)


func _on_phase_changed(phase: String) -> void:
	if phase != "harvest":
		return
	if not GameState.tutorial_completed or GameState.story_complete:
		return
	## Let the view dissolve into harvest before speaking.
	get_tree().create_timer(0.45).timeout.connect(_announce_on_harvest)


func _announce_on_harvest() -> void:
	if not GameState.is_harvest_phase() or _playing:
		return
	if not GameState.story_intro_seen and GameState.max_carry_yards() >= 20.0:
		GameState.story_intro_seen = true
		play(StoryScript.FIRST_MIST_LINES)
		return
	var fresh := GameState.unannounced_revealed_finds()
	if fresh.is_empty():
		return
	for id in fresh:
		GameState.mark_find_announced(id)
	var nearest := fresh[0]
	var yards := float(StoryFinds.get_def(nearest).get("yards", 0.0))
	say(StoryScript.reveal_hint(yards))
