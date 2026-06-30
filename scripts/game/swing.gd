class_name Swing
extends RefCounted
## Orchestrates hold-to-charge swing attempts — Workstream A + B integrate economy.

enum Phase { IDLE, CHARGING }

var charge := ChargeSwing.new()
var phase: Phase = Phase.IDLE
var charge_power: float = 0.0
var _last_swing_msec: int = 0
var _charge_start_msec: int = 0


func update(_delta: float) -> void:
	if phase != Phase.CHARGING:
		return
	var elapsed := charge_elapsed_sec()
	charge_power = charge.power_at(elapsed)
	var in_band := charge.is_in_release_band(elapsed, GameState.stats)
	var past_peak := charge.overshoot_fraction(elapsed) > 0.0
	EventBus.swing_charge_updated.emit(charge_power, in_band, past_peak)


func is_charging() -> bool:
	return phase == Phase.CHARGING


func can_swing(stats: PlayerStats) -> bool:
	var now := Time.get_ticks_msec()
	return now - _last_swing_msec >= int(stats.swing_cooldown_ms)


func start_charge() -> void:
	if phase != Phase.IDLE:
		return
	if not can_swing(GameState.stats):
		return
	phase = Phase.CHARGING
	_charge_start_msec = Time.get_ticks_msec()
	charge_power = 0.0
	EventBus.swing_charging_changed.emit(true)


func release_strike() -> void:
	if phase != Phase.CHARGING:
		return
	var hold_sec := charge_elapsed_sec()
	var tier := charge.evaluate_timing(hold_sec, GameState.stats)
	var quality := charge.timing_quality(hold_sec, GameState.stats)
	_resolve_swing(tier, quality)


func charge_elapsed_sec() -> float:
	if phase != Phase.CHARGING:
		return 0.0
	return (Time.get_ticks_msec() - _charge_start_msec) / 1000.0


func _resolve_swing(tier: int, timing_quality: float) -> void:
	_last_swing_msec = Time.get_ticks_msec()
	phase = Phase.IDLE
	charge_power = 0.0
	EventBus.swing_charging_changed.emit(false)

	if tier == Balance.TimingTier.PERFECT:
		GameState.lifetime["perfect_count"] = GameState.lifetime.get("perfect_count", 0) + 1

	var result := Economy.resolve_payout(tier, GameState.stats, timing_quality)
	var yards: float = result.yards
	var payout: float = result.payout

	GameState.add_currency(payout)
	GameState.lifetime["total_swings"] = GameState.lifetime.get("total_swings", 0) + 1
	GameState.lifetime["lifetime_yards"] = GameState.lifetime.get("lifetime_yards", 0.0) + yards

	var feedback := _feedback_for(tier, payout)
	EventBus.swing_resolved.emit(yards, tier, payout, feedback)


static func _feedback_for(tier: int, payout: float) -> int:
	if payout >= Balance.JACKPOT_PAYOUT_THRESHOLD:
		return Balance.FeedbackTier.JACKPOT
	if tier == Balance.TimingTier.PERFECT:
		return Balance.FeedbackTier.WARM
	return Balance.FeedbackTier.WHISPER
