extends Control
## HUD: currency display in a wood panel (top-left).

const FloatCashTextScript := preload("res://scripts/visual/float_cash_text.gd")
const EDGE_PADDING := 10
const RATTLING_INCOME_HOLD_SEC := 0.7
const RATTLING_INCOME_FADE_SEC := 0.5

@onready var _margin: MarginContainer = $Margin
@onready var _currency_panel: PanelContainer = $Margin/VBox/CurrencyPanel
@onready var currency_label: Label = $Margin/VBox/CurrencyPanel/CurrencyLabel
@onready var _rattling_income_label: Label = $Margin/VBox/RattlingIncomeLabel

var _rattling_income_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply_wood_panel(_currency_panel)
	PixelFont.apply_label(currency_label, 12)
	UiTheme.apply_panel_label(currency_label)
	PixelFont.apply_label(_rattling_income_label, 10)
	_rattling_income_label.modulate.a = 0.0
	call_deferred("_layout_top_left")
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.rattling_ball_collected.connect(_on_rattling_ball_collected)
	EventBus.ratina_ball_collected.connect(_on_ratina_ball_collected)
	_update_currency(GameState.currency)


func _layout_top_left() -> void:
	_margin.layout_mode = 0
	_margin.position = Vector2(EDGE_PADDING, EDGE_PADDING)
	_margin.size = _margin.get_combined_minimum_size()


func _on_stats_changed(_stats: PlayerStats, currency: float) -> void:
	_update_currency(currency)


func _on_rattling_ball_collected(amount: float) -> void:
	_show_collection_income(amount)


func _on_ratina_ball_collected(amount: float) -> void:
	_show_collection_income(amount)


func _show_collection_income(amount: float) -> void:
	SfxManager.play_pickup_plink(1)
	_rattling_income_label.text = "+$%s" % _format(amount)
	if _rattling_income_tween and _rattling_income_tween.is_valid():
		_rattling_income_tween.kill()
	_rattling_income_label.modulate.a = 1.0
	_rattling_income_tween = create_tween()
	_rattling_income_tween.tween_interval(RATTLING_INCOME_HOLD_SEC)
	_rattling_income_tween.tween_property(
		_rattling_income_label, "modulate:a", 0.0, RATTLING_INCOME_FADE_SEC
	)


func _update_currency(amount: float) -> void:
	currency_label.text = "$%s" % _format(amount)


func _format(n: float) -> String:
	return FloatCashTextScript.format_amount(n)
