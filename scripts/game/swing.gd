class_name Swing
extends RefCounted
## Orchestrates hold-to-charge swing attempts — Workstream A + B integrate economy.

enum Phase { IDLE, CHARGING, CHAIN_WINDOW, CHAIN_CHARGING }

var charge := ChargeSwing.new()
var phase: Phase = Phase.IDLE
var charge_power: float = 0.0
var _last_swing_msec: int = 0
var _charge_start_msec: int = 0
var _chain_window_start_msec: int = 0
var _first_perfect_combo_applied: bool = false


func update(_delta: float) -> void:
	match phase:
		Phase.CHARGING, Phase.CHAIN_CHARGING:
			var elapsed := charge_elapsed_sec()
			charge_power = charge.power_at(elapsed)
			var in_band := charge.is_in_release_band(elapsed, GameState.stats)
			var past_peak := charge.overshoot_fraction(elapsed) > 0.0
			EventBus.swing_charge_updated.emit(charge_power, in_band, past_peak)
		Phase.CHAIN_WINDOW:
			if chain_window_elapsed_sec() >= Balance.CHAIN_WINDOW_SEC:
				EventBus.swing_chain_window_expired.emit()
				_resolve_swing(Balance.TimingTier.PERFECT, 1)


func is_charging() -> bool:
	return phase == Phase.CHARGING or phase == Phase.CHAIN_CHARGING


func is_chain_window() -> bool:
	return phase == Phase.CHAIN_WINDOW


func is_chain_charging() -> bool:
	return phase == Phase.CHAIN_CHARGING


func chain_window_remaining_sec() -> float:
	if phase != Phase.CHAIN_WINDOW:
		return 0.0
	return maxf(Balance.CHAIN_WINDOW_SEC - chain_window_elapsed_sec(), 0.0)


func chain_window_elapsed_sec() -> float:
	if phase != Phase.CHAIN_WINDOW:
		return 0.0
	return (Time.get_ticks_msec() - _chain_window_start_msec) / 1000.0


func can_swing(stats: PlayerStats) -> bool:
	var now := Time.get_ticks_msec()
	return now - _last_swing_msec >= int(stats.swing_cooldown_ms)


func start_charge() -> void:
	match phase:
		Phase.IDLE:
			if not can_swing(GameState.stats):
				return
			charge.chain_mode = false
			phase = Phase.CHARGING
			_charge_start_msec = Time.get_ticks_msec()
			charge_power = 0.0
			EventBus.swing_charging_changed.emit(true)
		Phase.CHAIN_WINDOW:
			if not Balance.CHAIN_ENABLED:
				return
			phase = Phase.CHAIN_CHARGING
			charge.chain_mode = true
			_charge_start_msec = Time.get_ticks_msec()
			charge_power = 0.0
			EventBus.swing_chain_charging_started.emit()
			EventBus.swing_chain_state_changed.emit(true, 2)
			EventBus.swing_charging_changed.emit(true)


func release_strike() -> void:
	match phase:
		Phase.CHARGING:
			var hold_sec := charge_elapsed_sec()
			var tier := charge.evaluate_timing(hold_sec, GameState.stats)
			if tier == Balance.TimingTier.PERFECT and Balance.CHAIN_ENABLED:
				_enter_chain_window()
				return
			_resolve_swing(tier, 1)
		Phase.CHAIN_CHARGING:
			var hold_sec := charge_elapsed_sec()
			var tier := charge.evaluate_timing(hold_sec, GameState.stats)
			var chain_level := 2 if tier == Balance.TimingTier.PERFECT else 1
			_resolve_swing(tier, chain_level)
		_:
			pass


func charge_elapsed_sec() -> float:
	if phase != Phase.CHARGING and phase != Phase.CHAIN_CHARGING:
		return 0.0
	return (Time.get_ticks_msec() - _charge_start_msec) / 1000.0


func _enter_chain_window() -> void:
	phase = Phase.CHAIN_WINDOW
	_chain_window_start_msec = Time.get_ticks_msec()
	_first_perfect_combo_applied = true
	charge.combo += 1
	GameState.lifetime["perfect_count"] = GameState.lifetime.get("perfect_count", 0) + 1
	var best: int = GameState.lifetime.get("best_combo", 0)
	if charge.combo > best:
		GameState.lifetime["best_combo"] = charge.combo
	EventBus.swing_chain_window_started.emit()
	EventBus.swing_chain_state_changed.emit(true, 1)


func _resolve_swing(tier: int, chain_level: int) -> void:
	_last_swing_msec = Time.get_ticks_msec()
	phase = Phase.IDLE
	charge.chain_mode = false
	charge_power = 0.0
	EventBus.swing_charging_changed.emit(false)
	EventBus.swing_chain_state_changed.emit(false, chain_level)

	if tier == Balance.TimingTier.PERFECT:
		if chain_level >= 2:
			charge.combo += 1
			GameState.lifetime["perfect_count"] = GameState.lifetime.get("perfect_count", 0) + 1
			var best_chain: int = GameState.lifetime.get("best_combo", 0)
			if charge.combo > best_chain:
				GameState.lifetime["best_combo"] = charge.combo
		elif not _first_perfect_combo_applied:
			charge.combo += 1
			GameState.lifetime["perfect_count"] = GameState.lifetime.get("perfect_count", 0) + 1
			var best: int = GameState.lifetime.get("best_combo", 0)
			if charge.combo > best:
				GameState.lifetime["best_combo"] = charge.combo
	elif tier == Balance.TimingTier.GOOD and GameState.stats.good_counts_for_combo:
		charge.combo += 1
	elif tier == Balance.TimingTier.MISS:
		if charge.combo > 0:
			EventBus.combo_broken.emit(charge.combo)
		charge.combo = 0

	_first_perfect_combo_applied = false

	var result := Economy.resolve_payout(tier, charge.combo, GameState.stats, chain_level)
	var yards: float = result.yards
	var payout: float = result.payout

	GameState.add_currency(payout)
	GameState.lifetime["total_swings"] = GameState.lifetime.get("total_swings", 0) + 1
	GameState.lifetime["lifetime_yards"] = GameState.lifetime.get("lifetime_yards", 0.0) + yards

	var feedback := _feedback_for(tier, payout, charge.combo, chain_level)
	EventBus.swing_resolved.emit(yards, tier, payout, feedback, charge.combo, chain_level)


static func _feedback_for(tier: int, payout: float, combo: int, chain_level: int) -> int:
	if chain_level >= 2 and tier == Balance.TimingTier.PERFECT:
		return Balance.FeedbackTier.JACKPOT
	if payout >= Balance.JACKPOT_PAYOUT_THRESHOLD:
		return Balance.FeedbackTier.JACKPOT
	if tier == Balance.TimingTier.PERFECT and combo > 0 and combo % 5 == 0:
		return Balance.FeedbackTier.JACKPOT
	if tier == Balance.TimingTier.PERFECT:
		return Balance.FeedbackTier.WARM
	return Balance.FeedbackTier.WHISPER
