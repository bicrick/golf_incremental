class_name FortuneEnding
extends Control
## v9 ending: you bought the range. Barley hands over the keys; a card of the
## run's numbers; keep playing if you like.

signal done

var _panel: PanelContainer
var _stats: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.06, 0.04, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", TourUi.plate(TourUi.PAPER, TourUi.INK, 8))
	_panel.position = Vector2(120, 40)
	_panel.custom_minimum_size = Vector2(240, 0)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 6)
	_panel.add_child(vb)
	var title := TourUi.label("THE RANGE IS YOURS", 16, TourUi.GREEN_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var line := TourUi.label("Barley drops the keys in your paw.\n\"Always knew you had it in you, kid.\"", 8, TourUi.INK_SOFT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_constant_override(&"line_spacing", 3)
	vb.add_child(line)
	_stats = TourUi.label("", 8, TourUi.INK)
	_stats.add_theme_constant_override(&"line_spacing", 3)
	vb.add_child(_stats)
	var keep := TourUi.button("Keep playing", TourUi.GREEN)
	keep.pressed.connect(_close)
	vb.add_child(keep)


func show_card() -> void:
	var s := Game.stats
	var mins := int(Game.play_time / 60.0)
	var secs := int(Game.play_time) % 60
	_stats.text = "Time  %d:%02d\nSwings  %d   Perfects  %d\nPIN hits  %d   Jackpots  %d\nCards  %d   Holes in one  %d\nDoubles or better  %d\nForever bonus  +%d%%" % [
		mins, secs, int(s["swings"]), int(s["perfects"]), int(s["pins"]), int(s["jackpots"]),
		int(s["cards"]), int(s["aces"]), int(s["doubles"]), int(round(Game.permanent * 100.0))]
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	Audio.play("keepsake")


func is_blocking() -> bool:
	return visible


func _close() -> void:
	visible = false
	done.emit()
