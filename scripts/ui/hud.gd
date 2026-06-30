extends Control
## HUD: currency and swing hints.

const EDGE_PADDING := 10

@onready var _margin: MarginContainer = $Margin
@onready var currency_label: Label = $Margin/VBox/CurrencyLabel
@onready var hint_label: Label = $Margin/VBox/HintLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_pixel_fonts()
	call_deferred("_layout_top_left")
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_charge_updated.connect(_on_swing_charge_updated)
	_update_currency(GameState.currency)
	_set_idle_hint()


func _apply_pixel_fonts() -> void:
	PixelFont.apply_label(currency_label, 10)
	PixelFont.apply_label(hint_label, 8)


func _layout_top_left() -> void:
	_margin.layout_mode = 0
	_margin.position = Vector2(EDGE_PADDING, EDGE_PADDING)
	_margin.size = _margin.get_combined_minimum_size()


func _on_stats_changed(_stats: PlayerStats, currency: float) -> void:
	_update_currency(currency)


func _on_swing_resolved(_y, _tier: int, payout: float, _f) -> void:
	currency_label.text = "$%s  (+%s)" % [_format(GameState.currency), _format(payout)]
	_set_idle_hint()


func _on_swing_charging_changed(charging: bool) -> void:
	if charging:
		hint_label.visible = true
		hint_label.text = "Hold..."
		hint_label.modulate = Color(0.85, 0.9, 0.95, 1.0)
	else:
		_set_idle_hint()


func _on_swing_charge_updated(_power: float, in_release_band: bool, past_peak: bool) -> void:
	if in_release_band:
		hint_label.text = "Release!"
		hint_label.modulate = Color(1.0, 0.92, 0.45, 1.0)
	elif past_peak:
		hint_label.text = "Too late!"
		hint_label.modulate = Color(0.9, 0.55, 0.45, 1.0)
	else:
		hint_label.text = "Hold..."
		hint_label.modulate = Color(0.85, 0.9, 0.95, 1.0)


func _set_idle_hint() -> void:
	hint_label.visible = true
	hint_label.text = "Hold Space to swing"
	hint_label.modulate = Color(0.75, 0.78, 0.82, 0.85)


func _update_currency(amount: float) -> void:
	currency_label.text = "$%s" % _format(amount)


func _format(n: float) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1_000:
		return "%.2fK" % (n / 1_000.0)
	return str(int(n))
