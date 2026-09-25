class_name Swing
extends RefCounted
## Orchestrates contact-timing swing attempts — release at wind-up contact.

enum Phase { IDLE, CHARGING }

var charge := ChargeSwing.new()
var phase: Phase = Phase.IDLE
var windup_progress: float = 0.0
var last_contact_flavor: int = Balance.ContactFlavor.PURE
var last_hold_sec: float = 0.0
var _last_swing_msec: int = 0
var _charge_start_msec: int = 0


## Carry forced on the story's last ball (the first green's cup sits at 382 yd).
const FINALE_CARRY_YARDS := 380.0


func update(_delta: float) -> void:
	if phase != Phase.CHARGING:
		return
	var elapsed := charge_elapsed_sec()
	windup_progress = charge.windup_progress(elapsed)
	var in_band := charge.is_in_contact_band(elapsed, GameState.stats)
	var past_contact := charge.past_contact(elapsed)
	EventBus.swing_charge_updated.emit(windup_progress, in_band, past_contact)


func is_charging() -> bool:
	return phase == Phase.CHARGING


func can_swing(stats: PlayerStats) -> bool:
	var now := Time.get_ticks_msec()
	return now - _last_swing_msec >= int(stats.swing_cooldown_ms)


func start_charge() -> void:
	if phase != Phase.IDLE:
		return
	if GameState.is_harvest_phase():
		return
	if not GameState.has_bucket_balls():
		return
	if not can_swing(GameState.stats):
		return
	phase = Phase.CHARGING
	_charge_start_msec = Time.get_ticks_msec()
	windup_progress = 0.0
	EventBus.swing_charging_changed.emit(true)


## Drop an in-progress charge without resolving a hit. Used when harvest
## resumes strike while the same finger/mouse is still down.
func cancel_charge() -> void:
	if phase != Phase.CHARGING:
		return
	phase = Phase.IDLE
	windup_progress = 0.0


func release_strike() -> void:
	if phase != Phase.CHARGING:
		return
	var hold_sec := charge_elapsed_sec()
	last_hold_sec = hold_sec
	var tier := charge.evaluate_timing(hold_sec, GameState.stats)
	var quality := charge.timing_quality(hold_sec, GameState.stats)
	last_contact_flavor = charge.contact_flavor(tier, hold_sec, GameState.stats)
	_resolve_swing(tier, quality)


func charge_elapsed_sec() -> float:
	if phase != Phase.CHARGING:
		return 0.0
	return (Time.get_ticks_msec() - _charge_start_msec) / 1000.0


func _resolve_swing(tier: int, timing_quality: float) -> void:
	_last_swing_msec = Time.get_ticks_msec()
	phase = Phase.IDLE
	windup_progress = 0.0
	EventBus.swing_charging_changed.emit(false)

	if tier == Balance.TimingTier.PERFECT:
		GameState.lifetime["perfect_count"] = GameState.lifetime.get("perfect_count", 0) + 1

	## v5 finale — the last ball always reaches the first green.
	var last_ball := GameState.story_finale_armed
	if last_ball:
		tier = mini(tier, Balance.TimingTier.GREAT)
		timing_quality = maxf(timing_quality, 0.9)

	var result := Economy.resolve_payout(tier, GameState.stats, timing_quality)
	var yards: float = result.yards
	if last_ball:
		yards = maxf(yards, FINALE_CARRY_YARDS)

	GameState.lifetime["total_swings"] = GameState.lifetime.get("total_swings", 0) + 1
	GameState.lifetime["lifetime_yards"] = GameState.lifetime.get("lifetime_yards", 0.0) + yards
	GameState.record_carry(yards)

	var feedback := _feedback_for(tier)
	EventBus.swing_resolved.emit(yards, tier, 0.0, feedback)
	GameState.consume_bucket_ball()
	if last_ball:
		GameState.consume_finale_ball()


static func _feedback_for(tier: int) -> int:
	if tier == Balance.TimingTier.PERFECT:
		return Balance.FeedbackTier.WARM
	return Balance.FeedbackTier.WHISPER
