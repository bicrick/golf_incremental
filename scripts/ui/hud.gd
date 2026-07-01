extends Control
## HUD: currency display in a wood panel (top-left).

const FloatCashTextScript := preload("res://scripts/visual/float_cash_text.gd")
const EDGE_PADDING := 10

@onready var _margin: MarginContainer = $Margin
@onready var _currency_panel: PanelContainer = $Margin/CurrencyPanel
@onready var currency_label: Label = $Margin/CurrencyPanel/CurrencyLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply_wood_panel(_currency_panel)
	PixelFont.apply_label(currency_label, 12)
	call_deferred("_layout_top_left")
	EventBus.stats_changed.connect(_on_stats_changed)
	_update_currency(GameState.currency)


func _layout_top_left() -> void:
	_margin.layout_mode = 0
	_margin.position = Vector2(EDGE_PADDING, EDGE_PADDING)
	_margin.size = _margin.get_combined_minimum_size()


func _on_stats_changed(_stats: PlayerStats, currency: float) -> void:
	_update_currency(currency)


func _update_currency(amount: float) -> void:
	currency_label.text = "$%s" % _format(amount)


func _format(n: float) -> String:
	return FloatCashTextScript.format_amount(n)
