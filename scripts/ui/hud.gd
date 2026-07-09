extends Control
## HUD: currency display in a wood panel (top-left) with slot-reel count-up
## and a newest-on-top income stack under the bank.

const FloatCashTextScript := preload("res://scripts/visual/float_cash_text.gd")
const CurrencyReelScript := preload("res://scripts/ui/currency_reel.gd")
const EDGE_PADDING := 10

@onready var _margin: MarginContainer = $Margin
@onready var _currency_panel: PanelContainer = $Margin/VBox/TopRow/CurrencyPanel
@onready var currency_label: Label = $Margin/VBox/TopRow/CurrencyPanel/CurrencyLabel
@onready var _income_stack: VBoxContainer = $Margin/VBox/IncomeStack

var _reel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply_wood_panel(_currency_panel)
	PixelFont.apply_label(currency_label, 12)
	UiTheme.apply_panel_label(currency_label)
	call_deferred("_layout_top_left")
	_reel = CurrencyReelScript.new()
	_reel.setup(self, currency_label, Callable(self, "_format"), GameState.currency)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.rattling_ball_collected.connect(_on_income_amount)
	EventBus.ratina_ball_collected.connect(_on_income_amount)
	EventBus.pickup_payout.connect(_on_pickup_payout)


func _layout_top_left() -> void:
	_margin.layout_mode = 0
	_margin.position = Vector2(EDGE_PADDING, EDGE_PADDING)
	_margin.size = _margin.get_combined_minimum_size()


func _on_currency_changed(currency: float) -> void:
	_reel.set_target(currency)
	call_deferred("_layout_top_left")


func _on_stats_changed(_stats: PlayerStats, currency: float) -> void:
	_reel.set_target(currency)


func _on_income_amount(amount: float) -> void:
	# Crew collects previously played plink on the HUD flash; keep that.
	if amount > 0.0:
		SfxManager.play_pickup_plink(1)
	_push_income(amount)


func _on_pickup_payout(amount: float, _combo: int) -> void:
	# Player pickup / vanish / bucket bonus — SFX already played at collect site.
	_push_income(amount)


func _push_income(amount: float) -> void:
	if amount <= 0.0:
		return
	_income_stack.push_amount(amount)
	call_deferred("_layout_top_left")


func _format(n: float) -> String:
	return FloatCashTextScript.format_amount(n)
