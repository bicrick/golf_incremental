class_name TourHud
extends Control
## v8 HUD: money, reach vs. Ratina's flag, aim, bucket, wind, toasts, buttons.

signal shop_pressed
signal journal_pressed
signal map_pressed
signal pause_pressed

const TOUR := "res://assets/sprites/tour/"

var world: TourWorld
var _money_label: Label
var _shown_money := 0.0
var _money_plate: PanelContainer
var _bump := 0.0
var _goal_plate: Control
var _aim_plate: PanelContainer
var _aim_label: Label
var _hint_label: Label
var _bucket_label: Label
var _shop_btn: Button
var _map_btn: Button
var _journal_btn: Button
var _toasts: VBoxContainer
var _badge_t := 0.0
var _range_chip: Label
var _sweep_plate: PanelContainer
var _sweep_label: Label


func setup(w: TourWorld) -> void:
	world = w
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Tour.money_changed.connect(func(_m: float) -> void: _bump = 1.0)
	world.aim_changed.connect(_refresh_aim)
	Tour.upgrades_changed.connect(_refresh_aim)
	world.sweep_started.connect(func() -> void: _set_sweep(true))
	world.sweep_finished.connect(func(_c: int, _t: float) -> void: _set_sweep(false))
	_shown_money = Tour.money
	_bucket_label.text = "%d/%d" % [Tour.bucket_remaining, Tour.bucket_size()]


func _build() -> void:
	## Money, top-left.
	_money_plate = PanelContainer.new()
	_money_plate.add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER, TourUi.INK, 3))
	_money_plate.position = Vector2(6, 6)
	_money_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_money_plate)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override(&"separation", 3)
	_money_plate.add_child(mrow)
	var coin := TextureRect.new()
	coin.texture = load(TOUR + "i_coin.png")
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mrow.add_child(coin)
	_money_label = TourUi.label("$0", 8, TourUi.INK)
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mrow.add_child(_money_label)

	## Goal: reach vs. Ratina's flag (custom-drawn), under the money.
	_goal_plate = Control.new()
	_goal_plate.position = Vector2(6, 27)
	_goal_plate.size = Vector2(118, 22)
	_goal_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_plate.draw.connect(_draw_goal)
	add_child(_goal_plate)

	## Range chip, top-centre (fades after arrival).
	_range_chip = TourUi.outlined(TourUi.label("", 8, TourUi.PAPER_HI), TourUi.INK, 3)
	_range_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_chip.position = Vector2(140, 8)
	_range_chip.size = Vector2(200, 12)
	_range_chip.modulate.a = 0.0
	add_child(_range_chip)

	## Buttons, top-right.
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override(&"separation", 3)
	btns.position = Vector2(480 - 6 - 4 * 23, 6)
	add_child(btns)
	_map_btn = TourUi.icon_button(load(TOUR + "i_map.png"), "Map (M)")
	_map_btn.pressed.connect(func() -> void: map_pressed.emit())
	btns.add_child(_map_btn)
	_journal_btn = TourUi.icon_button(load(TOUR + "i_book.png"), "Journal (J)")
	_journal_btn.pressed.connect(func() -> void: journal_pressed.emit())
	btns.add_child(_journal_btn)
	_shop_btn = TourUi.icon_button(load(TOUR + "i_bag.png"), "Pro Shop (Tab)")
	_shop_btn.pressed.connect(func() -> void: shop_pressed.emit())
	btns.add_child(_shop_btn)
	var pause := TourUi.icon_button(load(TOUR + "i_gear.png"), "Pause (Esc)")
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	btns.add_child(pause)
	for b in btns.get_children():
		(b as Control).custom_minimum_size = Vector2(20, 20)
	_shop_btn.draw.connect(_draw_shop_badge)

	## Aim chip, bottom-left.
	_aim_plate = PanelContainer.new()
	_aim_plate.add_theme_stylebox_override(&"panel", TourUi.plate(Color(TourUi.PAPER, 0.92), TourUi.INK, 3))
	_aim_plate.position = Vector2(6, 270 - 6 - 30)
	_aim_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aim_plate)
	var avb := VBoxContainer.new()
	avb.add_theme_constant_override(&"separation", 2)
	_aim_plate.add_child(avb)
	_aim_label = TourUi.label("", 8, TourUi.INK)
	avb.add_child(_aim_label)
	_hint_label = TourUi.label("", 8, TourUi.INK_SOFT)
	_hint_label.add_theme_font_size_override(&"font_size", 8)
	avb.add_child(_hint_label)

	## Bucket, bottom-right.
	var bplate := PanelContainer.new()
	bplate.add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER, TourUi.INK, 3))
	bplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bplate)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override(&"separation", 3)
	bplate.add_child(brow)
	var bi := TextureRect.new()
	bi.texture = load(TOUR + "i_ball.png")
	bi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	brow.add_child(bi)
	_bucket_label = TourUi.label("0/0", 8, TourUi.INK)
	_bucket_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brow.add_child(_bucket_label)
	bplate.resized.connect(func() -> void: bplate.position = Vector2(480 - 6 - bplate.size.x, 270 - 6 - bplate.size.y))

	## Sweep status, bottom-centre.
	_sweep_plate = PanelContainer.new()
	_sweep_plate.add_theme_stylebox_override(&"panel", TourUi.plate(Color(TourUi.PAPER, 0.95), TourUi.INK, 3))
	_sweep_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep_plate.visible = false
	add_child(_sweep_plate)
	_sweep_label = TourUi.label("", 8, TourUi.INK)
	_sweep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sweep_plate.add_child(_sweep_label)
	_sweep_plate.resized.connect(func() -> void: _sweep_plate.position = Vector2(240 - _sweep_plate.size.x * 0.5, 270 - 8 - _sweep_plate.size.y))

	## Toasts, top-centre stack.
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(120, 34)
	_toasts.size = Vector2(240, 0)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override(&"separation", 3)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


func show_range_chip(text: String) -> void:
	_range_chip.text = text
	var tw := create_tween()
	_range_chip.modulate.a = 0.0
	tw.tween_property(_range_chip, "modulate:a", 1.0, 0.6)
	tw.tween_interval(3.5)
	tw.tween_property(_range_chip, "modulate:a", 0.0, 1.2)


func toast(text: String, color: Color = TourUi.INK, icon: String = "") -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER, TourUi.INK, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	p.add_child(row)
	if icon != "":
		var ti := TextureRect.new()
		ti.texture = load(TOUR + icon + ".png")
		ti.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(ti)
	var l := TourUi.label(text, 8, color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _set_sweep(on: bool) -> void:
	_sweep_plate.visible = on
	_aim_plate.visible = not on


func _refresh_aim() -> void:
	if world == null or world.range_def.is_empty():
		return
	var o := world.current_aim_option()
	if o.is_empty():
		return
	var text := ""
	if o["id"] == "drive":
		text = "Long drive · %sy" % TourFormat.yards(Tour.reach())
	else:
		var g: Dictionary = o["green"]
		text = "%s · %sy" % [g["name"], TourFormat.yards(float(g["z"]))]
		if Tour.stars.get(g["id"], false):
			text += " *"
	_aim_label.text = text
	_hint_label.text = "A/D aim  Hold Space"
	_hint_label.add_theme_color_override(&"font_color", TourUi.INK_SOFT)


func _process(delta: float) -> void:
	if world == null:
		return
	_shown_money = lerpf(_shown_money, Tour.money, clampf(delta * 10.0, 0.0, 1.0))
	if absf(_shown_money - Tour.money) < 0.01:
		_shown_money = Tour.money
	_money_label.text = "$" + TourFormat.money(_shown_money)
	_bump = maxf(_bump - delta * 5.0, 0.0)
	_money_plate.scale = Vector2.ONE * (1.0 + 0.08 * _bump)
	_bucket_label.text = "%d/%d" % [Tour.bucket_remaining, Tour.bucket_size()]
	_badge_t += delta
	_shop_btn.queue_redraw()
	_goal_plate.queue_redraw()
	_map_btn.visible = Tour.unlocked_range > 0 or Tour.story_complete
	if world.mode == TourWorld.Mode.SWEEP:
		var left := world.resting.size()
		_sweep_label.text = "Sweep! %d left  ·  Space: done" % left
		if world.chain > 1:
			_sweep_label.text = "Chain x%d  ·  %d left" % [world.chain, left]
	queue_redraw()


func _any_affordable() -> bool:
	for u in TourData.UPGRADES:
		if Tour.can_buy(u["id"]):
			return true
	return false


func _draw_shop_badge() -> void:
	if not _any_affordable():
		return
	var pulse := 0.5 + 0.5 * sin(_badge_t * 5.0)
	_shop_btn.draw_rect(Rect2(Vector2(14, -2), Vector2(7, 7)), TourUi.INK)
	_shop_btn.draw_rect(Rect2(Vector2(15, -1), Vector2(5, 5)), TourUi.GOLD.lerp(Color.WHITE, pulse * 0.4))


func _draw_goal() -> void:
	var r := world.range_def
	if r.is_empty():
		return
	var flag := TourData.flag_green(r)
	var gp := _goal_plate
	var need := world.landing_for(Vector2(flag.get("x", 0.0), flag.get("z", 1.0)), flag).length() - float(flag.get("r", 0.0)) * 0.5
	var reach := Tour.reach()
	var frac := clampf(reach / maxf(need, 1.0), 0.0, 1.0)
	var done: bool = Tour.cleared.get(r["id"], false)
	gp.draw_rect(Rect2(0, 0, 118, 22), TourUi.INK)
	gp.draw_rect(Rect2(1, 1, 116, 20), TourUi.PAPER)
	var title := "Reach %sy" % TourFormat.yards(reach)
	TinyText.draw(gp, Vector2(5, 4), title.to_upper(), TourUi.INK)
	var flag_txt := ("FLAG %sy" % TourFormat.yards(float(flag.get("z", 0)))) if not done else "CLEARED"
	if r.get("mechanic", "") == "dark" and not world.green_visible(flag) and not done:
		flag_txt = "LIGHT %d/%d" % [Tour.lit_count(r), int(flag.get("needs_lit", 0))]
	TinyText.draw(gp, Vector2(113 - TinyText.width(flag_txt), 4), flag_txt, TourUi.PINK.darkened(0.2))
	## Bar.
	var bar := Rect2(5, 12, 108, 6)
	gp.draw_rect(bar, TourUi.INK)
	gp.draw_rect(bar.grow(-1), TourUi.PAPER_DIM)
	var fill := bar.grow(-1)
	fill.size.x *= frac
	var col := TourUi.GREEN if frac < 1.0 else TourUi.GOLD
	if frac >= 1.0 and int(_badge_t * 3.0) % 2 == 0 and not done:
		col = col.lightened(0.3)
	gp.draw_rect(fill, col)
	gp.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1)), col.lightened(0.35))


func _draw() -> void:
	if world == null or world.range_def.get("mechanic", "") != "wind" or world.mode != TourWorld.Mode.PLAY:
		return
	## Windsock, under the buttons.
	var c := Vector2(454, 44)
	draw_rect(Rect2(c + Vector2(-22, -10), Vector2(44, 30)), TourUi.INK)
	draw_rect(Rect2(c + Vector2(-21, -9), Vector2(42, 28)), TourUi.PAPER)
	var w := world.wind
	var dir := Vector2(w.x / 7.0, -w.y / 0.16)
	var strength := clampf(dir.length(), 0.0, 1.0)
	if dir.length() > 0.01:
		dir = dir.normalized()
	var tip := c + dir * 8.0
	draw_line(c, tip, TourUi.RED, 2.0)
	var side := Vector2(-dir.y, dir.x)
	draw_line(tip, tip - dir * 3.0 + side * 3.0, TourUi.RED, 1.0)
	draw_line(tip, tip - dir * 3.0 - side * 3.0, TourUi.RED, 1.0)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), TourUi.INK)
	var mph := int(round(strength * 18.0))
	var label := "%d MPH" % mph
	var kind := "TAIL" if w.y > 0.04 else ("HEAD" if w.y < -0.04 else "CROSS")
	TinyText.draw(self, c + Vector2(-TinyText.width(label) * 0.5, 11), label, TourUi.INK)
	TinyText.draw(self, c + Vector2(-19, -8), kind, TourUi.INK_SOFT)
