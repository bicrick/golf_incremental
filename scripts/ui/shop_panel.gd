extends Control
## Full-screen Pro Shop — ball upgrades and Ratina hire.

const ITEM_CARD_SCENE := preload("res://scenes/ui/shop_item_card.tscn")

@onready var items_root: VBoxContainer = $Content/Items
@onready var title_label: Label = $Content/Header/Title
@onready var currency_label: Label = $Content/Header/CurrencyLabel
@onready var back_button: Button = $Content/Header/BackButton
@onready var _ratina_card: PanelContainer = $Content/Items/RatinaCard
@onready var _ratina_name: Label = $Content/Items/RatinaCard/Margin/Row/Info/NameLabel
@onready var _ratina_desc: Label = $Content/Items/RatinaCard/Margin/Row/Info/DescLabel
@onready var _ratina_level: Label = $Content/Items/RatinaCard/Margin/Row/Info/LevelLabel
@onready var _ratina_buy: Button = $Content/Items/RatinaCard/Margin/Row/BuyButton

var _is_open := false
var _item_cards: Dictionary = {}


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.shop_item_purchased.connect(_on_shop_item_purchased)
	_apply_fonts()
	_style_back_button()
	_style_ratina_card()
	_build_items()
	_ratina_buy.pressed.connect(_on_ratina_buy_pressed)
	_refresh_all()


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_close_other_panels()
	_is_open = true
	visible = true
	_refresh_all()
	_notify_icon_bar(true)
	EventBus.ui_panel_toggled.emit("shop", true)


func close() -> void:
	_is_open = false
	visible = false
	_notify_icon_bar(false)
	EventBus.ui_panel_toggled.emit("shop", false)


func _notify_icon_bar(is_open: bool) -> void:
	var icon_bar := get_parent().get_node_or_null("IconBar")
	if icon_bar and icon_bar.has_method("set_shop_open"):
		icon_bar.set_shop_open(is_open)


func _close_other_panels() -> void:
	var upgrade_panel := get_parent().get_node_or_null("UpgradePanel")
	if upgrade_panel and upgrade_panel.has_method("is_open") and upgrade_panel.is_open():
		upgrade_panel.close()
	var main := get_tree().root.get_node_or_null("Main")
	if main:
		var settings_panel := main.get_node_or_null("SettingsLayer/SettingsPanel")
		if settings_panel and settings_panel.has_method("is_open") and settings_panel.is_open():
			settings_panel.close()


func _build_items() -> void:
	for def in ShopDefinitions.all():
		var card: PanelContainer = ITEM_CARD_SCENE.instantiate()
		items_root.add_child(card)
		items_root.move_child(card, items_root.get_child_count() - 2)
		card.setup(def)
		card.purchase_requested.connect(_on_purchase_requested)
		_item_cards[def["id"]] = card


func _refresh_all() -> void:
	currency_label.text = "$%s" % _format_currency(GameState.currency)
	for id in _item_cards:
		var card: PanelContainer = _item_cards[id]
		card.refresh()
	_refresh_ratina_card()


func _refresh_ratina_card() -> void:
	_ratina_name.text = "Ratina"
	_ratina_desc.text = "Hire the range star. Unlocks her upgrade tab (passive income coming soon)."
	if GameState.ratina_unlocked:
		_ratina_level.text = "Hired"
		_ratina_buy.text = "HIRED"
		_ratina_buy.disabled = true
	else:
		_ratina_level.text = "$20/min once implemented"
		var affordable := GameState.currency >= Balance.RATINA_UNLOCK_COST
		_ratina_buy.text = "$%d" % int(Balance.RATINA_UNLOCK_COST)
		_ratina_buy.disabled = not affordable or not GameState.shop_unlocked


func _on_purchase_requested(id: String) -> void:
	if not GameState.purchase_shop_item(id):
		return
	_refresh_all()


func _on_ratina_buy_pressed() -> void:
	if not GameState.try_unlock_ratina():
		return
	_refresh_all()


func _on_stats_changed(_stats: PlayerStats, currency: float) -> void:
	if not _is_open:
		return
	currency_label.text = "$%s" % _format_currency(currency)
	for id in _item_cards:
		var card: PanelContainer = _item_cards[id]
		card.refresh()
	_refresh_ratina_card()


func _on_shop_item_purchased(_id: String, _level: int) -> void:
	if _is_open:
		_refresh_all()


func _apply_fonts() -> void:
	PixelFont.apply_label(title_label, 10)
	PixelFont.apply_label(currency_label, 8)
	PixelFont.apply_label(_ratina_name, 8)
	PixelFont.apply_label(_ratina_desc, 6)
	PixelFont.apply_label(_ratina_level, 6)
	_ratina_buy.add_theme_font_override(&"font", PixelFont.font_for_size(7))
	_ratina_buy.add_theme_font_size_override(&"font_size", 7)


func _style_back_button() -> void:
	back_button.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	back_button.add_theme_font_size_override(&"font_size", 8)
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
	back_button.add_theme_stylebox_override(&"normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.92, 0.82, 0.58, 0.95)
	back_button.add_theme_stylebox_override(&"hover", hover)
	back_button.add_theme_stylebox_override(&"pressed", hover)


func _style_ratina_card() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.12, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.55, 0.45, 0.28, 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	_ratina_card.add_theme_stylebox_override(&"panel", style)
	_ratina_name.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.45, 1))
	_ratina_desc.add_theme_color_override(&"font_color", Color(0.92, 0.86, 0.72, 1))
	_ratina_level.add_theme_color_override(&"font_color", Color(0.55, 0.5, 0.42, 1))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.82, 0.72, 0.48, 0.92)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.18, 0.52, 0.48, 1)
	btn_style.corner_radius_top_left = 2
	btn_style.corner_radius_top_right = 2
	btn_style.corner_radius_bottom_left = 2
	btn_style.corner_radius_bottom_right = 2
	btn_style.content_margin_left = 6
	btn_style.content_margin_right = 6
	btn_style.content_margin_top = 2
	btn_style.content_margin_bottom = 2
	_ratina_buy.add_theme_stylebox_override(&"normal", btn_style)
	var hover := btn_style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.92, 0.82, 0.58, 0.95)
	_ratina_buy.add_theme_stylebox_override(&"hover", hover)
	_ratina_buy.add_theme_stylebox_override(&"pressed", hover)
	_ratina_buy.custom_minimum_size = Vector2(52, 22)


func _format_currency(n: float) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1_000:
		return "%.2fK" % (n / 1_000.0)
	return str(int(n))
