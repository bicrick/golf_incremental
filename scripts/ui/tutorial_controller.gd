extends Control
## First-run dialogue tutorial — guided welcome through first bucket, harvest, upgrades, keep-going.
## Returning players get a one-shot welcome-back line on each Play from title.

const ThoughtBoxScript = preload("res://scripts/ui/tutorial_thought_box.gd")
const TutorialCopyScript = preload("res://scripts/ui/tutorial_copy.gd")

var _box: Control
var _active_beat := -1
var _showing_welcome_back := false
var _awaiting_first_swing := false
var _awaiting_empty_bucket := false
var _awaiting_harvest_enter := false
var _awaiting_harvest_pick := false
var _awaiting_harvest_return := false
var _awaiting_keep_going := false
var _upgrade_bought_for_tip := false
var _icon_bar: Node = null
var _pending_first_tier: int = Balance.TimingTier.OKAY


func _ready() -> void:
	add_to_group(&"tutorial_overlay")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_box = ThoughtBoxScript.new()
	_box.name = "ThoughtBox"
	add_child(_box)
	_box.dismissed.connect(_on_box_dismissed)
	if _box.has_signal("nudge_requested"):
		_box.nudge_requested.connect(_on_box_nudge_requested)
	if not EventBus.swing_resolved.is_connected(_on_swing_resolved):
		EventBus.swing_resolved.connect(_on_swing_resolved)
	if not EventBus.bucket_changed.is_connected(_on_bucket_changed):
		EventBus.bucket_changed.connect(_on_bucket_changed)
	if not EventBus.phase_changed.is_connected(_on_phase_changed):
		EventBus.phase_changed.connect(_on_phase_changed)
	if not EventBus.upgrade_purchased.is_connected(_on_upgrade_purchased):
		EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	if not EventBus.ui_panel_toggled.is_connected(_on_ui_panel_toggled):
		EventBus.ui_panel_toggled.connect(_on_ui_panel_toggled)
	if not EventBus.ball_collected.is_connected(_on_ball_collected):
		EventBus.ball_collected.connect(_on_ball_collected)
	call_deferred("_resolve_icon_bar")


func is_blocking_input() -> bool:
	if _box == null or not _box.has_method("is_open") or not _box.is_open():
		return false
	if _box.has_method("blocks_world_input"):
		return _box.blocks_world_input()
	return true


func begin_if_needed() -> void:
	if GameState.tutorial_completed:
		_show_welcome_back()
		return
	var progress: int = GameState.tutorial_progress
	if progress <= 0:
		_show_beat(TutorialCopyScript.Beat.WELCOME)
	elif progress == TutorialCopyScript.Beat.HOLD:
		_awaiting_first_swing = true
	elif progress == TutorialCopyScript.Beat.FIRST_BUCKET:
		_awaiting_empty_bucket = true
		if GameState.bucket_remaining <= 0 and not GameState.is_harvest_phase():
			_show_beat(TutorialCopyScript.Beat.OUT_OF_BALLS)
	elif progress == TutorialCopyScript.Beat.HARVEST_ENTER:
		_awaiting_harvest_enter = true
		if GameState.is_harvest_phase():
			_show_beat(TutorialCopyScript.Beat.HARVEST_PICK)
	elif progress == TutorialCopyScript.Beat.HARVEST_RETURN:
		_awaiting_harvest_return = true
		if not GameState.is_harvest_phase():
			call_deferred("_show_upgrades_beat")
	elif progress == TutorialCopyScript.Beat.UPGRADES:
		# Upgrades tip already dismissed — wait for first buy + panel close.
		_arm_keep_going_gate()
	elif progress >= TutorialCopyScript.Beat.KEEP_GOING:
		call_deferred("_try_show_keep_going")


func _show_welcome_back() -> void:
	## One-shot pane per Play press; does not touch tutorial_completed / progress.
	if _showing_welcome_back:
		return
	if _box != null and _box.is_open():
		return
	_showing_welcome_back = true
	_active_beat = -1
	var line: String = TutorialCopyScript.pick_welcome_back_line()
	_box.show_thought(line, false, TutorialUiPreviews.Kind.NONE)


func apply_viewport_layout() -> void:
	if _box != null and _box.has_method("apply_viewport_layout"):
		_box.apply_viewport_layout()


func _resolve_icon_bar() -> void:
	var chrome := get_parent().get_node_or_null("GameplayChrome") if get_parent() != null else null
	if chrome != null:
		_icon_bar = chrome.get_node_or_null("IconBar")
	else:
		_icon_bar = get_parent().get_node_or_null("IconBar")


func _show_beat(beat: int, text_override: String = "", force: bool = false) -> void:
	if GameState.tutorial_completed:
		return
	if not force and _box != null and _box.is_open():
		return
	_active_beat = beat
	var is_menu_tip := TutorialCopyScript.is_upgrades_menu_beat(beat)
	if not is_menu_tip:
		_awaiting_first_swing = false
		_awaiting_empty_bucket = false
		_awaiting_harvest_enter = false
		_awaiting_harvest_pick = false
		_awaiting_harvest_return = false
		if beat != TutorialCopyScript.Beat.KEEP_GOING:
			_awaiting_keep_going = false
	var line: String = text_override
	if line.is_empty():
		line = TutorialCopyScript.line_for(beat)
	var preview_kind: int = TutorialCopyScript.preview_kind_for(beat)
	var options := {}
	if beat == TutorialCopyScript.Beat.HARVEST_PICK:
		_awaiting_harvest_pick = true
		options["advance_on_input"] = false
	_box.show_thought(line, false, preview_kind, options)
	if beat == TutorialCopyScript.Beat.UPGRADES:
		_pulse_upgrades()


func _on_box_dismissed() -> void:
	if _showing_welcome_back:
		_showing_welcome_back = false
		_active_beat = -1
		return
	var beat := _active_beat
	_active_beat = -1
	_awaiting_harvest_pick = false
	match beat:
		TutorialCopyScript.Beat.WELCOME:
			call_deferred("_show_beat", TutorialCopyScript.Beat.HOLD)
		TutorialCopyScript.Beat.HOLD:
			_advance_progress(TutorialCopyScript.Beat.HOLD)
			_awaiting_first_swing = true
		TutorialCopyScript.Beat.SHOT_REACTION:
			call_deferred("_show_beat", TutorialCopyScript.Beat.FIRST_BUCKET)
		TutorialCopyScript.Beat.FIRST_BUCKET:
			_advance_progress(TutorialCopyScript.Beat.FIRST_BUCKET)
			_awaiting_empty_bucket = true
			if GameState.bucket_remaining <= 0:
				call_deferred("_maybe_show_out_of_balls")
		TutorialCopyScript.Beat.OUT_OF_BALLS:
			call_deferred("_show_beat", TutorialCopyScript.Beat.HARVEST_ENTER)
		TutorialCopyScript.Beat.HARVEST_ENTER:
			_advance_progress(TutorialCopyScript.Beat.HARVEST_ENTER)
			_awaiting_harvest_enter = true
			if GameState.is_harvest_phase():
				call_deferred("_show_beat", TutorialCopyScript.Beat.HARVEST_PICK)
		TutorialCopyScript.Beat.HARVEST_PICK, TutorialCopyScript.Beat.HARVEST_FIND_HINT:
			call_deferred("_show_beat", TutorialCopyScript.Beat.HARVEST_DONE)
		TutorialCopyScript.Beat.HARVEST_DONE:
			call_deferred("_show_beat", TutorialCopyScript.Beat.HARVEST_RETURN)
		TutorialCopyScript.Beat.HARVEST_RETURN:
			_advance_progress(TutorialCopyScript.Beat.HARVEST_RETURN)
			_awaiting_harvest_return = true
			if not GameState.is_harvest_phase():
				call_deferred("_show_upgrades_beat")
		TutorialCopyScript.Beat.UPGRADES_STUCK:
			call_deferred("_show_beat", TutorialCopyScript.Beat.UPGRADES_SPEND)
		TutorialCopyScript.Beat.UPGRADES_SPEND:
			call_deferred("_show_beat", TutorialCopyScript.Beat.UPGRADES)
		TutorialCopyScript.Beat.UPGRADES:
			_advance_progress(TutorialCopyScript.Beat.UPGRADES)
			_arm_keep_going_gate()
		TutorialCopyScript.Beat.UPGRADES_MENU_BROKE:
			call_deferred("_show_beat", TutorialCopyScript.Beat.UPGRADES_MENU_CLICK)
		TutorialCopyScript.Beat.UPGRADES_MENU_CLICK:
			_mark_upgrade_menu_seen()
		TutorialCopyScript.Beat.KEEP_GOING:
			_advance_progress(TutorialCopyScript.Beat.KEEP_GOING)
			_complete_tutorial()


func _advance_progress(beat: int) -> void:
	if beat > GameState.tutorial_progress:
		GameState.tutorial_progress = beat
		SaveManager.save_game()


func _mark_upgrade_menu_seen() -> void:
	if GameState.tutorial_upgrade_menu_seen:
		return
	GameState.tutorial_upgrade_menu_seen = true
	# Interrupted range story before durable UPGRADES checkpoint: still arm keep-going.
	if GameState.tutorial_progress < TutorialCopyScript.Beat.UPGRADES:
		_advance_progress(TutorialCopyScript.Beat.UPGRADES)
		_arm_keep_going_gate()
	else:
		SaveManager.save_game()


func _complete_tutorial() -> void:
	GameState.tutorial_completed = true
	GameState.tutorial_progress = TutorialCopyScript.Beat.KEEP_GOING
	GameState.tutorial_upgrade_menu_seen = true
	_awaiting_first_swing = false
	_awaiting_empty_bucket = false
	_awaiting_harvest_enter = false
	_awaiting_harvest_pick = false
	_awaiting_harvest_return = false
	_awaiting_keep_going = false
	_upgrade_bought_for_tip = false
	SaveManager.save_game()


func _on_swing_resolved(
	_yards: float,
	timing_tier: int,
	_payout: float,
	_feedback_tier: int
) -> void:
	if GameState.tutorial_completed:
		return
	if not _awaiting_first_swing:
		return
	if GameState.tutorial_progress < TutorialCopyScript.Beat.HOLD:
		return
	_awaiting_first_swing = false
	_pending_first_tier = timing_tier
	get_tree().create_timer(0.35).timeout.connect(_show_first_shot_reaction, CONNECT_ONE_SHOT)


func _show_first_shot_reaction() -> void:
	if GameState.tutorial_completed:
		return
	if GameState.tutorial_progress != TutorialCopyScript.Beat.HOLD:
		return
	var line: String = TutorialCopyScript.shot_reaction_line(_pending_first_tier)
	_show_beat(TutorialCopyScript.Beat.SHOT_REACTION, line)


func _on_bucket_changed(count: int, _capacity: int) -> void:
	if GameState.tutorial_completed:
		return
	if count > 0:
		return
	if GameState.tutorial_progress < TutorialCopyScript.Beat.FIRST_BUCKET:
		return
	if GameState.tutorial_progress >= TutorialCopyScript.Beat.HARVEST_ENTER:
		return
	_maybe_show_out_of_balls()


func _maybe_show_out_of_balls() -> void:
	if GameState.tutorial_completed:
		return
	if _box != null and _box.is_open():
		return
	if GameState.bucket_remaining > 0:
		return
	if GameState.is_harvest_phase():
		return
	if GameState.tutorial_progress < TutorialCopyScript.Beat.FIRST_BUCKET:
		return
	if GameState.tutorial_progress >= TutorialCopyScript.Beat.HARVEST_ENTER:
		return
	_show_beat(TutorialCopyScript.Beat.OUT_OF_BALLS)


func _on_phase_changed(phase: String) -> void:
	if GameState.tutorial_completed:
		return
	if phase == "harvest":
		if (
			_awaiting_harvest_enter
			or GameState.tutorial_progress == TutorialCopyScript.Beat.HARVEST_ENTER
		):
			_awaiting_harvest_enter = false
			call_deferred("_show_harvest_pick_if_needed")
		return
	if phase != "strike":
		return
	# Upgrades after harvest return tip was dismissed (progress == HARVEST_RETURN).
	if GameState.tutorial_progress != TutorialCopyScript.Beat.HARVEST_RETURN:
		return
	_awaiting_harvest_return = false
	call_deferred("_show_upgrades_beat")


func _show_harvest_pick_if_needed() -> void:
	if GameState.tutorial_completed:
		return
	if not GameState.is_harvest_phase():
		return
	if GameState.tutorial_progress < TutorialCopyScript.Beat.HARVEST_ENTER:
		return
	if GameState.tutorial_progress >= TutorialCopyScript.Beat.HARVEST_RETURN:
		return
	_show_beat(TutorialCopyScript.Beat.HARVEST_PICK)


func _on_ball_collected(_world_pos: Vector3, _combo: int) -> void:
	## HARVEST_PICK / FIND_HINT wait for first successful pickup before advancing.
	if GameState.tutorial_completed:
		return
	if not _awaiting_harvest_pick:
		return
	if (
		_active_beat != TutorialCopyScript.Beat.HARVEST_PICK
		and _active_beat != TutorialCopyScript.Beat.HARVEST_FIND_HINT
	):
		return
	_awaiting_harvest_pick = false
	if _box != null and _box.has_method("dismiss_for_event"):
		_box.dismiss_for_event()


func _on_box_nudge_requested() -> void:
	## Space / Enter / tap-on-box while waiting for first pickup → soft SFX + find hint.
	if GameState.tutorial_completed:
		return
	if not _awaiting_harvest_pick:
		return
	if (
		_active_beat != TutorialCopyScript.Beat.HARVEST_PICK
		and _active_beat != TutorialCopyScript.Beat.HARVEST_FIND_HINT
	):
		return
	SfxManager.play_ui_error()
	if _active_beat == TutorialCopyScript.Beat.HARVEST_FIND_HINT:
		return
	_show_harvest_find_hint()


func _show_harvest_find_hint() -> void:
	## Replace pick tip with find/zoom nudge; stay in wait-for-pickup (passthrough).
	if GameState.tutorial_completed:
		return
	if not _awaiting_harvest_pick:
		return
	if _box == null:
		return
	_active_beat = TutorialCopyScript.Beat.HARVEST_FIND_HINT
	var line: String = TutorialCopyScript.line_for(TutorialCopyScript.Beat.HARVEST_FIND_HINT)
	var options := {"advance_on_input": false}
	_box.show_thought(line, false, TutorialUiPreviews.Kind.NONE, options)


func _show_upgrades_beat() -> void:
	if GameState.tutorial_completed:
		return
	if GameState.tutorial_progress < TutorialCopyScript.Beat.HARVEST_RETURN:
		return
	if GameState.tutorial_progress >= TutorialCopyScript.Beat.UPGRADES:
		return
	_show_beat(TutorialCopyScript.Beat.UPGRADES_STUCK)


func _maybe_show_upgrade_menu_intro() -> void:
	if GameState.tutorial_completed:
		return
	if GameState.tutorial_upgrade_menu_seen:
		return
	var in_story := TutorialCopyScript.is_upgrades_story_beat(_active_beat)
	if GameState.tutorial_progress < TutorialCopyScript.Beat.UPGRADES and not in_story:
		return
	_show_beat(TutorialCopyScript.Beat.UPGRADES_MENU_BROKE, "", true)


func _arm_keep_going_gate() -> void:
	if GameState.tutorial_completed:
		return
	if GameState.tutorial_progress < TutorialCopyScript.Beat.UPGRADES:
		return
	_awaiting_keep_going = true
	if _has_any_play_upgrade():
		_upgrade_bought_for_tip = true
		call_deferred("_try_show_keep_going")


func _on_upgrade_purchased(_id: String, _level: int, _branch: int) -> void:
	if GameState.tutorial_completed:
		return
	if not _awaiting_keep_going:
		return
	if GameState.tutorial_progress < TutorialCopyScript.Beat.UPGRADES:
		return
	_upgrade_bought_for_tip = true
	# Show only after upgrades panel closes (back on the range).


func _on_ui_panel_toggled(panel_id: String, is_open: bool) -> void:
	if panel_id != "upgrades":
		return
	if is_open:
		_maybe_show_upgrade_menu_intro()
		return
	if GameState.tutorial_completed:
		return
	if not _awaiting_keep_going or not _upgrade_bought_for_tip:
		return
	call_deferred("_try_show_keep_going")


func _try_show_keep_going() -> void:
	if GameState.tutorial_completed:
		return
	if not _awaiting_keep_going:
		return
	if not _upgrade_bought_for_tip and not _has_any_play_upgrade():
		return
	if _is_upgrades_panel_open():
		return
	_upgrade_bought_for_tip = true
	_show_beat(TutorialCopyScript.Beat.KEEP_GOING)


func _has_any_play_upgrade() -> bool:
	for level in GameState.upgrade_levels.values():
		if int(level) > 0:
			return true
	return false


func _is_upgrades_panel_open() -> bool:
	var ui_root := get_parent()
	if ui_root == null:
		return false
	var panel := ui_root.get_node_or_null("UpgradePanel")
	if panel == null:
		panel = ui_root.get_node_or_null("../UpgradePanel")
	if panel != null and panel.has_method("is_open"):
		return bool(panel.is_open())
	return false


func _pulse_upgrades() -> void:
	if _icon_bar == null:
		_resolve_icon_bar()
	if _icon_bar != null and _icon_bar.has_method("pulse_upgrades_hint"):
		_icon_bar.pulse_upgrades_hint()
