extends Node
## v8 — boots title → range, wires world / overlay / backdrop / UI, routes
## input, and directs the story (tips, arrivals, flags, travel, the ending).

var backdrop: TourBackdrop
var world: TourWorld
var overlay: TourOverlay
var ui_layer: CanvasLayer
var hud: TourHud
var shop: TourShop
var dialogue: TourDialogue
var map: TourMap
var ending: TourEnding
var title: TourTitle
var pause: TourPause
var journal: TourJournal

var _mouse_swing := false
var _in_session := false
var _pending_flag := {}
var _range_swings_at_start := 0


func _ready() -> void:
	backdrop = TourBackdrop.new()
	add_child(backdrop)
	world = TourWorld.new()
	add_child(world)
	world.backdrop = backdrop
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 1
	add_child(overlay_layer)
	overlay = TourOverlay.new()
	overlay_layer.add_child(overlay)
	overlay.setup(world)
	world.overlay = overlay

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = TourHud.new()
	ui_layer.add_child(hud)
	hud.setup(world)
	shop = TourShop.new()
	ui_layer.add_child(shop)
	map = TourMap.new()
	ui_layer.add_child(map)
	ending = TourEnding.new()
	ui_layer.add_child(ending)
	dialogue = TourDialogue.new()
	ui_layer.add_child(dialogue)
	journal = TourJournal.new()
	ui_layer.add_child(journal)
	title = TourTitle.new()
	ui_layer.add_child(title)
	pause = TourPause.new()
	ui_layer.add_child(pause)

	hud.shop_pressed.connect(shop.toggle)
	hud.journal_pressed.connect(journal.open)
	hud.map_pressed.connect(_open_map)
	hud.pause_pressed.connect(pause.open)
	pause.to_title.connect(_to_title)
	title.play_pressed.connect(_on_play)
	map.travel_done.connect(_on_travel_done)
	map.closed.connect(func() -> void: pass)
	dialogue.finished.connect(_on_beat_finished)
	ending.done.connect(_on_ending_done)

	world.bucket_emptied.connect(_on_bucket_emptied)
	world.new_star.connect(_on_new_star)
	world.flag_reached.connect(_on_flag_reached)
	world.keepsake_picked.connect(_on_keepsake)
	world.ball_came_to_rest.connect(_on_ball_rest)
	world.sweep_finished.connect(_on_sweep_finished)

	start_range(Tour.range_index)
	hud.visible = false
	Audio.set_playlist(["main-theme"])


# --- session flow ---------------------------------------------------------------

func _on_play(new_game: bool) -> void:
	if new_game:
		Tour.new_game()
		start_range(0)
	_in_session = true
	hud.visible = true
	Audio.set_playlist(world.range_def["songs"])
	if not Tour.seen.get("intro", false):
		Tour.mark_seen("intro")
		dialogue.play("intro")
	else:
		_arrival()


func _to_title() -> void:
	_in_session = false
	hud.visible = false
	if shop.is_open():
		shop.toggle()
	Audio.set_playlist(["main-theme"])
	title.visible = true
	title.modulate.a = 1.0
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title._cont_btn.visible = Tour.has_started()


func start_range(index: int) -> void:
	world.load_range(index)
	overlay.set_weather(TourLooks.look(world.range_def["id"])["weather"])
	Audio.set_playlist(world.range_def["songs"])
	Audio.set_ambience(world.range_def["id"])


func _arrival() -> void:
	var r := world.range_def
	hud.show_range_chip("%s  %s" % [r["numeral"], r["name"]])
	var beat := "arrive_" + String(r["id"])
	if Tour.mark_seen(beat):
		dialogue.play(beat)


func _on_beat_finished(beat: String) -> void:
	match beat:
		"intro":
			hud.show_range_chip("I  Barley's Range")
			if Tour.mark_seen("tip_swing"):
				dialogue.play("tip_swing")
		"tip_sweep":
			world.begin_sweep()
		"ending":
			ending.show_card()
	if beat.begins_with("flag_") and not _pending_flag.is_empty():
		_finish_flag()


# --- world events ---------------------------------------------------------------

func _on_bucket_emptied() -> void:
	if world.mode != TourWorld.Mode.PLAY or dialogue.is_blocking():
		return
	world.input_enabled = false
	if Tour.mark_seen("tip_sweep"):
		dialogue.play("tip_sweep")
		return
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if world.mode == TourWorld.Mode.PLAY and Tour.bucket_remaining <= 0 and world.flying.is_empty():
			world.begin_sweep()
	)


func _on_sweep_finished(collected: int, tips: float) -> void:
	if collected > 2 and tips > 0.0:
		hud.toast("Swept %d  ·  tips $%s" % [collected, TourFormat.money(tips)], TourUi.GREEN_DARK, "i_ball")


func _on_new_star(green: Dictionary, bonus: float) -> void:
	if green.get("lantern", false):
		hud.toast("%s lit!  +$%s" % [green["name"], TourFormat.money(bonus)], TourUi.GOLD.darkened(0.4), "i_star")
		Audio.play("lantern")
		if Tour.lit_count(world.range_def) >= 4 and Tour.mark_seen("frost_path"):
			dialogue.play("frost_path")
	elif not green.get("ratina", false):
		hud.toast("New green: %s  +$%s" % [green["name"], TourFormat.money(bonus)], TourUi.GREEN_DARK, "i_star")
		Audio.play("star")
	overlay.shake(1.5)


func _on_flag_reached(green: Dictionary, _result: Dictionary) -> void:
	var r := world.range_def
	if r["mechanic"] == "finale":
		if Tour.story_complete:
			return
		_start_ending()
		return
	if Tour.cleared.get(r["id"], false):
		return
	Audio.play("flag")
	overlay.shake(3.0)
	world.mode = TourWorld.Mode.LOCKED
	_pending_flag = {"index": Tour.range_index, "green": green}
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		dialogue.play("flag_" + String(r["id"]))
	)


func _finish_flag() -> void:
	var index: int = _pending_flag["index"]
	_pending_flag = {}
	Tour.clear_range(index)
	var rw: Dictionary = TourData.get_range(index)["reward"]
	if not rw.is_empty():
		hud.toast(TourStory.REWARD_TEXT.get(rw["id"], rw["name"]), TourUi.PINK.darkened(0.3), "i_star")
	world.mode = TourWorld.Mode.PLAY
	if index + 1 < TourData.range_count():
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			map.travel(index, index + 1)
		)


func _on_travel_done(index: int) -> void:
	Tour.travel_to(index)
	start_range(index)
	_arrival()


func _open_map() -> void:
	if world.mode != TourWorld.Mode.PLAY or dialogue.is_blocking():
		return
	map.browse()


func _on_keepsake(k: Dictionary) -> void:
	dialogue.play("keepsake", [{
		"who": "keepsake",
		"title": k["name"],
		"icon": "res://assets/sprites/tour/%s.png" % k["id"],
		"text": "%s  (%s)" % [k["line"], TourStory.bonus_text(k["bonus"])],
	}])


func _on_ball_rest(result: Dictionary) -> void:
	var r := world.range_def
	if r.get("mechanic", "") == "finale" and not Tour.story_complete:
		var aim := world.current_aim_option()
		if aim.get("green", {}).get("ratina", false) and result.get("green", "") != "e_flag":
			if Tour.mark_seen("edge_miss"):
				dialogue.play("edge_miss")


# --- the ending -----------------------------------------------------------------

func _start_ending() -> void:
	world.mode = TourWorld.Mode.LOCKED
	if shop.is_open():
		shop.toggle()
	Audio.set_playlist(["sunrise"], 2.5)
	Audio.play("flag")
	overlay.shake(4.0)
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		ending.sunrise(4.0)
		Tour.complete_story()
		dialogue.play("ending")
	)


func _on_ending_done() -> void:
	world.mode = TourWorld.Mode.PLAY
	dialogue.play("postgame")
	Audio.set_playlist(["sunrise"] + world.range_def["songs"])


# --- per-frame story checks ----------------------------------------------------

func _process(_delta: float) -> void:
	var blocked := _blocked()
	world.input_enabled = _in_session and not blocked
	if not _in_session or blocked or world.mode != TourWorld.Mode.PLAY:
		return
	var r := world.range_def
	if Tour.range_index == 0 and int(Tour.stats["swings"]) >= 4 and Tour.mark_seen("tip_aim"):
		dialogue.play("tip_aim")
	elif hud._any_affordable() and Tour.mark_seen("tip_shop"):
		dialogue.play("tip_shop")
	elif r.get("mechanic", "") == "finale" and not Tour.story_complete:
		var flag := TourData.flag_green(r)
		if Vector2(flag["x"], flag["z"]).length() <= Tour.reach() + 0.5 and Tour.mark_seen("edge_ready"):
			dialogue.play("edge_ready")


func _blocked() -> bool:
	return (dialogue.is_blocking() or map.is_blocking() or ending.is_blocking() or pause.is_blocking()
		or journal.is_blocking() or title.visible)


# --- input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _in_session or _blocked():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_TAB, KEY_E:
				shop.toggle()
				get_viewport().set_input_as_handled()
				return
			KEY_J:
				journal.open()
				return
			KEY_M:
				if Tour.unlocked_range > 0:
					_open_map()
				return
			KEY_ESCAPE:
				if shop.is_open():
					shop.toggle()
				else:
					pause.open()
				return
	if world.mode == TourWorld.Mode.SWEEP:
		_sweep_input(event)
		return
	if world.mode != TourWorld.Mode.PLAY:
		return
	if event is InputEventKey and not event.echo:
		var k: InputEventKey = event
		match k.physical_keycode:
			KEY_SPACE, KEY_ENTER:
				if k.pressed:
					world.begin_swing()
				else:
					world.release_swing()
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_A:
				if k.pressed:
					world.cycle_aim(-1)
			KEY_RIGHT, KEY_D:
				if k.pressed:
					world.cycle_aim(1)
			KEY_UP, KEY_W:
				if k.pressed:
					world.aim_nudge.y += 3.0
					world.aim_changed.emit()
			KEY_DOWN, KEY_S:
				if k.pressed:
					world.aim_nudge.y -= 3.0
					world.aim_changed.emit()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var flag := _flag_at(mb.position)
				if flag >= 0:
					world.select_aim(flag)
				else:
					_mouse_swing = true
					world.begin_swing()
			elif _mouse_swing:
				_mouse_swing = false
				world.release_swing()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			world.cycle_aim(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			world.cycle_aim(-1)
	elif event is InputEventMouseMotion:
		world.hovered_option = _flag_at((event as InputEventMouseMotion).position)


func _sweep_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		world.set_cart_target_screen((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		world.set_cart_target_screen((event as InputEventMouseButton).position)
	elif event is InputEventKey and not event.echo:
		var k: InputEventKey = event
		if k.pressed and k.physical_keycode in [KEY_SPACE, KEY_ENTER]:
			world.finish_sweep()
		var v := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			v.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			v.x += 1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			v.y += 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			v.y -= 1
		world.set_keys_move(v)


## Index into world.aim_options of a flag under the pointer, or -1.
func _flag_at(screen: Vector2) -> int:
	var best := -1
	var best_d := 12.0
	for i in world.aim_options.size():
		var o: Dictionary = world.aim_options[i]
		if o["id"] == "drive":
			continue
		var p := Vector3(o["point"].x, 0, -o["point"].y)
		if world.camera.is_position_behind(p):
			continue
		var sp := world.camera.unproject_position(p) + Vector2(2, -12)
		var d := sp.distance_to(screen)
		if d < best_d:
			best_d = d
			best = i
	return best
