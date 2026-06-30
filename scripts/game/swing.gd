class_name Swing
extends RefCounted
## Orchestrates swing attempts — Workstream A + B integrate economy.

var rhythm := Rhythm.new()
var _last_swing_msec: int = 0


func update(delta: float) -> void:
	rhythm.update(delta)


func can_swing(stats: PlayerStats) -> bool:
	var now := Time.get_ticks_msec()
	return now - _last_swing_msec >= int(stats.swing_cooldown_ms)


func attempt_swing() -> void:
	if not can_swing(GameState.stats):
		return
	var tier := rhythm.evaluate_timing(rhythm.beat_phase, GameState.stats)
	_last_swing_msec = Time.get_ticks_msec()
	# Economy.resolve_payout — Workstream B
	var yards: float = min(
		GameState.stats.base_yards * GameState.stats.yard_multiplier,
		GameState.stats.max_yards
	)
	var payout: float = yards * GameState.stats.dollars_per_yard * Balance.TIER_MULTS[tier]
	GameState.add_currency(payout)
	GameState.lifetime["total_swings"] = GameState.lifetime.get("total_swings", 0) + 1
	var feedback := Balance.FeedbackTier.WHISPER
	if tier == Balance.TimingTier.PERFECT:
		feedback = Balance.FeedbackTier.WARM
		rhythm.combo += 1
	elif tier == Balance.TimingTier.MISS:
		EventBus.combo_broken.emit(rhythm.combo)
		rhythm.combo = 0
	EventBus.swing_resolved.emit(yards, tier, payout, feedback, rhythm.combo)
