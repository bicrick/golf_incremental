extends CanvasLayer
## HUD: currency and combo — Workstream C expands.

@onready var currency_label: Label = $Margin/VBox/CurrencyLabel
@onready var combo_label: Label = $Margin/VBox/ComboLabel


func _ready() -> void:
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	_update_currency(GameState.currency)


func _on_stats_changed(_stats: PlayerStats, currency: float) -> void:
	_update_currency(currency)


func _on_swing_resolved(_y, _t, payout: float, _f, combo: int) -> void:
	combo_label.text = "Combo: %d" % combo
	# Floating payout hint
	currency_label.text = "$%s  (+%s)" % [_format(GameState.currency), _format(payout)]


func _update_currency(amount: float) -> void:
	currency_label.text = "$%s" % _format(amount)


func _format(n: float) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1_000:
		return "%.2fK" % (n / 1_000.0)
	return str(int(n))
