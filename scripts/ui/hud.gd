extends CanvasLayer
## HUD: currency and combo — Workstream C expands.

@onready var currency_label: Label = $Margin/VBox/CurrencyLabel
@onready var combo_label: Label = $Margin/VBox/ComboLabel
@onready var hint_label: Label = $Margin/VBox/HintLabel

var _chain_hint_active: bool = false


func _ready() -> void:
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.combo_broken.connect(_on_combo_broken)
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_charge_updated.connect(_on_swing_charge_updated)
	EventBus.swing_chain_window_started.connect(_on_chain_window_started)
	EventBus.swing_chain_charging_started.connect(_on_chain_charging_started)
	EventBus.swing_chain_state_changed.connect(_on_chain_state_changed)
	_update_currency(GameState.currency)
	_set_idle_hint()


func _on_stats_changed(_stats: PlayerStats, currency: float) -> void:
	_update_currency(currency)


func _on_swing_resolved(_y, tier: int, payout: float, _f, combo: int, chain_level: int) -> void:
	combo_label.text = "Combo: %d" % combo
	if chain_level >= 2 and tier == Balance.TimingTier.PERFECT:
		combo_label.modulate = Balance.CHAIN_RING_COLOR
	elif combo == 0:
		combo_label.modulate = Balance.TIER_COLORS[tier]
	else:
		combo_label.modulate = Color(1, 0.88, 0.35)
	currency_label.text = "$%s  (+%s)" % [_format(GameState.currency), _format(payout)]
	_set_idle_hint()


func _on_combo_broken(_previous: int) -> void:
	combo_label.text = "Combo: 0"
	combo_label.modulate = Balance.TIER_COLORS[Balance.TimingTier.MISS]


func _on_swing_charging_changed(charging: bool) -> void:
	if charging and not _chain_hint_active:
		hint_label.visible = true
		hint_label.text = "Hold..."
		hint_label.modulate = Color(0.85, 0.9, 0.95, 1.0)
	elif not _chain_hint_active:
		_set_idle_hint()


func _on_swing_charge_updated(_power: float, in_release_band: bool, past_peak: bool) -> void:
	if _chain_hint_active:
		return
	if in_release_band:
		hint_label.text = "Release!"
		hint_label.modulate = Color(1.0, 0.92, 0.45, 1.0)
	elif past_peak:
		hint_label.text = "Too late!"
		hint_label.modulate = Color(0.9, 0.55, 0.45, 1.0)
	else:
		hint_label.text = "Hold..."
		hint_label.modulate = Color(0.85, 0.9, 0.95, 1.0)


func _on_chain_window_started() -> void:
	_chain_hint_active = true
	hint_label.visible = true
	hint_label.text = Balance.CHAIN_LABEL_WINDOW
	hint_label.modulate = Balance.CHAIN_RING_COLOR


func _on_chain_charging_started() -> void:
	_chain_hint_active = true
	hint_label.visible = true
	hint_label.text = Balance.CHAIN_LABEL_CHARGE
	hint_label.modulate = Balance.CHAIN_RING_COLOR


func _on_chain_state_changed(active: bool, _chain_level: int) -> void:
	if not active:
		_chain_hint_active = false
		_set_idle_hint()


func _set_idle_hint() -> void:
	hint_label.visible = true
	hint_label.text = "Hold to swing"
	hint_label.modulate = Color(0.75, 0.78, 0.82, 0.85)


func _update_currency(amount: float) -> void:
	currency_label.text = "$%s" % _format(amount)


func _format(n: float) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1_000:
		return "%.2fK" % (n / 1_000.0)
	return str(int(n))
