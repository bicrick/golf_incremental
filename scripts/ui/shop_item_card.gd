extends PanelContainer
## Single Pro Shop purchase row — name, effect readout, buy button.

signal purchase_requested(item_id: String)

const COLOR_BG := Color(0.18, 0.15, 0.12, 0.92)
const COLOR_BORDER := Color(0.55, 0.45, 0.28, 1)
const COLOR_BORDER_AFFORD := Color(0.95, 0.82, 0.35, 1)
const COLOR_TEXT := Color(0.92, 0.86, 0.72, 1)
const COLOR_TEXT_GOLD := Color(1.0, 0.9, 0.45, 1)
const COLOR_TEXT_DIM := Color(0.55, 0.5, 0.42, 1)

var item_id: String = ""

@onready var _name_label: Label = $Margin/Row/Info/NameLabel
@onready var _desc_label: Label = $Margin/Row/Info/DescLabel
@onready var _level_label: Label = $Margin/Row/Info/LevelLabel
@onready var _buy_button: Button = $Margin/Row/BuyButton


func _ready() -> void:
	_style_panel()
	_style_buy_button()
	_buy_button.pressed.connect(_on_buy_pressed)
	PixelFont.apply_label(_name_label, 8)
	PixelFont.apply_label(_desc_label, 6)
	PixelFont.apply_label(_level_label, 6)
	_buy_button.add_theme_font_override(&"font", PixelFont.font_for_size(7))
	_buy_button.add_theme_font_size_override(&"font_size", 7)


func setup(def: Dictionary) -> void:
	item_id = def.get("id", "")
	_name_label.text = def.get("display_name", "")
	_desc_label.text = def.get("description", "")
	refresh()


func refresh() -> void:
	if item_id.is_empty():
		return
	var def: Dictionary = ShopDefinitions.get_def(item_id)
	if def.is_empty():
		return
	var level := GameState.get_shop_item_level(item_id)
	var max_level := int(def["max_level"])
	var maxed := level >= max_level
	var cost := GameState.get_shop_item_cost(item_id)
	var affordable := not maxed and GameState.currency >= cost

	if maxed:
		_level_label.text = "Lv %d/%d  MAX" % [level, max_level]
		_buy_button.text = "MAX"
		_buy_button.disabled = true
	elif level <= 0 and item_id == "golden_ball":
		_level_label.text = "Unlock: 5% golden chance"
		_buy_button.text = "$%s" % _format_cost(cost)
		_buy_button.disabled = not affordable
	elif item_id == "ball_count":
		var cap := GameState.get_bucket_capacity()
		_level_label.text = "Bucket: %d balls  Lv %d/%d" % [cap, level, max_level]
		_buy_button.text = "$%s" % _format_cost(cost)
		_buy_button.disabled = not affordable
	elif item_id == "golden_ball":
		var chance_pct := GameState.stats.golden_ball_chance * 100.0
		_level_label.text = "Golden chance: %.0f%%  Lv %d/%d" % [chance_pct, level, max_level]
		_buy_button.text = "$%s" % _format_cost(cost)
		_buy_button.disabled = not affordable
	else:
		_level_label.text = "Lv %d/%d" % [level, max_level]
		_buy_button.text = "$%s" % _format_cost(cost)
		_buy_button.disabled = not affordable

	var border := COLOR_BORDER_AFFORD if affordable else COLOR_BORDER
	_style_panel(border)


func _on_buy_pressed() -> void:
	if item_id.is_empty():
		return
	purchase_requested.emit(item_id)


func _style_panel(border_color: Color = COLOR_BORDER) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	add_theme_stylebox_override(&"panel", style)
	_name_label.add_theme_color_override(&"font_color", COLOR_TEXT_GOLD)
	_desc_label.add_theme_color_override(&"font_color", COLOR_TEXT)
	_level_label.add_theme_color_override(&"font_color", COLOR_TEXT_DIM)


func _style_buy_button() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.72, 0.48, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.18, 0.52, 0.48, 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_buy_button.add_theme_stylebox_override(&"normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.92, 0.82, 0.58, 0.95)
	_buy_button.add_theme_stylebox_override(&"hover", hover)
	_buy_button.add_theme_stylebox_override(&"pressed", hover)
	_buy_button.custom_minimum_size = Vector2(52, 22)


func _format_cost(n: float) -> String:
	if n >= 1_000:
		return "%.0fK" % (n / 1_000.0)
	return str(int(n))
