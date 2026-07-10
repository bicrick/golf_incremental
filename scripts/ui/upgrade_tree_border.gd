extends Control
## Drawn circle medallion border for upgrade tree nodes — syncs phase with connectors.

const UpgradeTreeStroke = preload("res://scripts/ui/upgrade_tree_stroke.gd")

var border_color: Color = UpgradeTreeStroke.COLOR_BASE_PAY_LINE
var glow_color: Color = UpgradeTreeStroke.COLOR_BASE_PAY_GLOW
var animated := false
var with_glow := false
var _pulse_alpha := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func configure(color: Color, is_animated: bool, show_glow: bool, glow: Color) -> void:
	border_color = color
	animated = is_animated
	with_glow = show_glow
	glow_color = glow
	set_process(is_animated)
	queue_redraw()


func _process(_delta: float) -> void:
	if not animated:
		return
	var phase := UpgradeTreeStroke.get_phase()
	_pulse_alpha = 0.75 + 0.25 * sin(phase * 4.0)
	queue_redraw()


func _draw() -> void:
	var color := border_color
	if animated:
		color = Color(border_color.r, border_color.g, border_color.b, border_color.a * _pulse_alpha)
	var glow := glow_color
	if with_glow and animated:
		glow = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * _pulse_alpha)
	UpgradeTreeStroke.draw_circle_border(
		self,
		Rect2(Vector2.ZERO, size),
		color,
		UpgradeTreeStroke.BORDER_WIDTH,
		UpgradeTreeStroke.get_phase(),
		animated,
		with_glow,
		glow,
		true
	)
