extends Node
## v9 Fortune Range — boots the title over the live range, then wires the
## Tee Line (3D), the three table rooms, the top bar and the upgrade panel.
## Every room keeps earning while you're in another; the tabs just choose
## which one you're playing.

const VENUE_SONGS := {
	"barley": ["sunrise", "early-riser"], "cliffs": ["midday", "main-theme"], "mesa": ["dusk"],
	"frost": ["night", "midnight"], "edge": ["final"],
}

var backdrop: TourBackdrop
var tee: TeeLine
var overlay: TeeOverlay
var green: PuttingGreen
var cards: Scorecards
var dice: NineteenthHole
var topbar: FortuneTopBar
var panel: FortunePanel
var banner: FortuneBanner
var title: FortuneTitle
var ending: FortuneEnding
var pause: FortunePause
var hint: Label

var current := "tee"
var in_session := false
var _mouse_swing := false
var _venue := ""


func _ready() -> void:
	backdrop = TourBackdrop.new()
	add_child(backdrop)
	tee = TeeLine.new()
	tee.backdrop = backdrop
	add_child(tee)
	backdrop.set_range(tee.venue)
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 1
	add_child(overlay_layer)
	overlay = TeeOverlay.new()
	overlay_layer.add_child(overlay)
	overlay.setup(tee)

	var room_layer := CanvasLayer.new()
	room_layer.layer = 2
	add_child(room_layer)
	green = PuttingGreen.new()
	cards = Scorecards.new()
	dice = NineteenthHole.new()
	for r in [green, cards, dice]:
		room_layer.add_child(r)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	topbar = FortuneTopBar.new()
	ui.add_child(topbar)
	panel = FortunePanel.new()
	ui.add_child(panel)
	hint = TourUi.outlined(TourUi.label("", 8, TourUi.PAPER_HI), TourUi.INK, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 254)
	hint.size = Vector2(330, 10)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hint)
	banner = FortuneBanner.new()
	ui.add_child(banner)
	ending = FortuneEnding.new()
	ui.add_child(ending)
	title = FortuneTitle.new()
	ui.add_child(title)
	pause = FortunePause.new()
	ui.add_child(pause)

	topbar.room_selected.connect(select_room)
	topbar.buy_range.connect(_buy_range)
	title.play_pressed.connect(_on_play)
	pause.to_title.connect(_to_title)
	ending.done.connect(func() -> void: pass)
	tee.pin_hit.connect(_on_pin)
	Game.big_moment.connect(_on_big_moment)
	Game.room_unlocked.connect(_on_room_unlocked)
	Game.upgrades_changed.connect(_on_upgrades)
	green.jackpot.connect(func() -> void: overlay._shake = 3.0)
	dice.rolled.connect(_on_dice)

	_set_session(false)
	Audio.set_playlist(["main-theme"])
	Audio.set_ambience(tee.venue)


# --- session ---------------------------------------------------------------------------

func _set_session(on: bool) -> void:
	in_session = on
	topbar.visible = on
	panel.visible = on
	hint.visible = on
	if not on:
		for r in [green, cards, dice]:
			r.visible = false
	tee.input_enabled = on
	overlay.show_labels = on


func _on_play(new_game: bool) -> void:
	if new_game:
		Game.new_game()
	_set_session(true)
	_venue = ""
	_on_upgrades()
	select_room("tee")


func _to_title() -> void:
	_set_session(false)
	Audio.set_playlist(["main-theme"])
	title.visible = true
	title.modulate.a = 1.0
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title._cont_btn.visible = Game.has_started()


func select_room(id: String) -> void:
	if not Game.rooms.get(id, false):
		return
	current = id
	topbar.current = id
	panel.show_room(id)
	green.visible = id == "green"
	cards.visible = id == "cards"
	dice.visible = id == "dice"
	_mouse_swing = false
	if tee.charging:
		tee.release_swing()


func _on_room_unlocked(id: String) -> void:
	var r := FortuneData.room(id)
	banner.show_moment(String(r["name"]).to_upper() + " OPEN", "A new way to make money.", Color(0.6, 1.0, 0.6))


func _on_upgrades() -> void:
	## Renovations move the whole range; the music follows.
	if tee.venue != _venue:
		_venue = tee.venue
		if in_session:
			Audio.set_playlist(VENUE_SONGS.get(_venue, ["main-theme"]))
			Audio.set_ambience(_venue)
			if Game.level("tee_reno") > 0:
				var names := {"cliffs": "Saltwind Cliffs", "mesa": "Redrock Mesa", "frost": "Frostline", "edge": "The Edge"}
				banner.show_moment("RENOVATED!", "Welcome to " + String(names.get(_venue, _venue)) + ".  Tee Line x3", Color(0.7, 0.9, 1.0))
				Audio.play("travel")


func _on_pin() -> void:
	if Game.rooms.get("green", false):
		green.add_golden(1 + Game.level("tee_pin") / 2)


func _on_big_moment(kind: String, text: String) -> void:
	if kind == "permanent":
		var parts := text.split("  ")
		banner.show_moment(parts[0], parts[1] if parts.size() > 1 else "", Color(1.0, 0.85, 0.3))


func _on_dice(kind: String) -> void:
	match kind:
		"doubles":
			banner.show_moment("DOUBLES!", "x2 everything", Color(1.0, 0.9, 0.4))
		"boxcars":
			banner.show_moment("BOXCARS!", "x5 everything", Color(1.0, 0.7, 0.3))
		"triples":
			banner.show_moment("TRIPLES!", "x10 everything", Color(1.0, 0.5, 0.9))


func _buy_range() -> void:
	if Game.buy_the_range():
		banner.show_moment("SOLD!", "Fortune Range is yours.", Color(1.0, 0.85, 0.3))
		Audio.set_playlist(["final"])
		get_tree().create_timer(1.6).timeout.connect(ending.show_card)


# --- frame ---------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not in_session:
		return
	var blocked := _blocked()
	tee.input_enabled = not blocked and current == "tee"
	topbar.coin_bump = maxf(topbar.coin_bump, overlay.coin_landed)
	overlay.coin_landed = 0.0
	hint.text = _hint_text()


func _hint_text() -> String:
	match current:
		"tee":
			if int(Game.stats["swings"]) < 6:
				return "Hold SPACE (or click), let go when the ring closes"
			if Game.frenzy > 0.0:
				return "FRENZY!  Double-speed swings"
	return ""


func _blocked() -> bool:
	return ending.is_blocking() or pause.is_blocking() or title.visible


# --- input ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not in_session or _blocked():
		return
	if event is InputEventKey and not event.echo:
		var k: InputEventKey = event
		if k.pressed:
			match k.physical_keycode:
				KEY_1:
					_tab(0)
					return
				KEY_2:
					_tab(1)
					return
				KEY_3:
					_tab(2)
					return
				KEY_4:
					_tab(3)
					return
				KEY_ESCAPE:
					pause.open()
					return
		if k.physical_keycode in [KEY_SPACE, KEY_ENTER]:
			get_viewport().set_input_as_handled()
			match current:
				"tee":
					if k.pressed:
						tee.begin_swing()
					else:
						tee.release_swing()
				"green":
					if k.pressed:
						green.key_drop()
				"cards":
					if k.pressed:
						cards.key_action()
				"dice":
					if k.pressed:
						dice.key_action()
			return
	if current == "tee" and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_swing = true
				tee.begin_swing()
			elif _mouse_swing:
				_mouse_swing = false
				tee.release_swing()


func _tab(i: int) -> void:
	var r: Dictionary = FortuneData.ROOMS[i]
	if Game.rooms.get(r["id"], false):
		select_room(r["id"])
		Audio.play("ui_tick")
	else:
		topbar._click_tab(i)
