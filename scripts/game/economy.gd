class_name Economy
extends RefCounted
## Payout and purchase logic.


static func upgrade_cost(base: float, growth: float, level: int) -> float:
	var stretch := 1.0 + float(level) * Balance.UPGRADE_COST_LEVEL_STRETCH
	return floor(base * pow(growth, level) * stretch * 100.0 + 0.0001) / 100.0


static func resolve_payout(
	_timing_tier: int,
	stats: PlayerStats,
	timing_quality: float = 1.0
) -> Dictionary:
	var yards: float = yards_from_quality(timing_quality, stats)
	return { "yards": yards }


## Gameplay carry — base yards × contact power × Perfect Pop (no quality $).
static func yards_from_quality(strike_quality: float, stats: PlayerStats) -> float:
	var q := clampf(strike_quality, stats.yard_quality_floor, 1.0)
	q = apply_sweet_spot(q, stats)
	return stats.base_yards * q * perfect_power_mult(q, stats) * maxf(stats.carry_multiplier, 0.01)


## Pull high contact toward Perfect when Sweet Spot is unlocked.
static func apply_sweet_spot(contact: float, stats: PlayerStats) -> float:
	if stats.sweet_spot_unlocked <= 0.0 or stats.sweet_spot_bonus <= 0.0:
		return contact
	var pull := clampf(stats.sweet_spot_bonus, 0.0, 0.95)
	return clampf(
		contact + (1.0 - contact) * pull * contact,
		stats.yard_quality_floor,
		1.0
	)


## Perfect Pop ramps from Great band up to full bonus at Perfect contact.
static func perfect_power_mult(contact: float, stats: PlayerStats) -> float:
	var bonus := maxf(stats.perfect_power_bonus, 1.0)
	if bonus <= 1.0:
		return 1.0
	var start := Balance.PERFECT_POWER_RAMP_START
	var t := clampf((contact - start) / maxf(1.0 - start, 0.001), 0.0, 1.0)
	return lerpf(1.0, bonus, t * t)


static func quality_for_tier(timing_tier: int) -> int:
	if timing_tier < 0 or timing_tier >= Balance.QUALITY_FOR_TIER.size():
		return 1
	return Balance.QUALITY_FOR_TIER[timing_tier]


static func resolve_pickup_ball_payout(
	_quality: int,
	yardage: float,
	combo_tier: int,
	stats: PlayerStats
) -> float:
	var shot_value := _shot_value(yardage, stats)
	shot_value = _apply_pickup_layer(shot_value, stats)
	return shot_value * combo_multiplier(combo_tier, stats)


static func _shot_value(yardage: float, stats: PlayerStats) -> float:
	var payout := stats.base_amount
	if stats.yardage_term_unlocked > 0.0:
		payout += stats.base_amount * stats.pay_per_yard * maxf(yardage, 0.0)
	return payout


static func _apply_pickup_layer(shot_value: float, stats: PlayerStats) -> float:
	if stats.pickup_bonus_unlocked <= 0.0:
		return shot_value
	return shot_value * stats.pickup_multiplier + stats.pickup_flat_bonus


## Golden bird harvest click — always ≥ early floor, and ≥ N golden-equivalent balls.
static func resolve_golden_bird_payout(stats: PlayerStats) -> float:
	var floor_amt := Balance.GOLDEN_BIRD_BASE_REWARD * maxf(stats.pickup_multiplier, 1.0)
	var yards := maxf(stats.base_yards, 0.0)
	var ball := resolve_pickup_ball_payout(1, yards, 1, stats)
	var scaled := (
		ball
		* Balance.GOLDEN_BIRD_BALL_EQUIVALENT
		* maxf(stats.golden_ball_payout_multiplier, 1.0)
	)
	return maxf(floor_amt, scaled)


## Ball flight depth on the range fairway (0 at tee → 1.0 at VISUAL_MAX_YARDS).
static func visual_depth_t(yards: float, _stats: PlayerStats) -> float:
	var y := maxf(yards, 0.0)
	var scale := Balance.PERSPECTIVE_DEPTH_SCALE
	var max_y := Balance.VISUAL_MAX_YARDS
	var denom := 1.0 - exp(-max_y / scale)
	if denom < 0.0001:
		return clampf(y / max_y, 0.0, 1.0)
	var normalized := (1.0 - exp(-y / scale)) / denom
	return clampf(pow(normalized, Balance.PERSPECTIVE_DEPTH_EXPONENT), 0.0, 1.0)


static func visual_landing_y(
	yards: float,
	tee_y: float,
	horizon_y: float,
	stats: PlayerStats
) -> float:
	return lerpf(tee_y, horizon_y, visual_depth_t(yards, stats))


static func combo_multiplier(combo_tier: int, stats: PlayerStats) -> float:
	if stats.combo_mult_per_tier <= 0.0:
		return 1.0
	var tier := maxi(combo_tier, 1)
	return 1.0 + stats.combo_mult_per_tier * float(tier - 1)


static func combo_window_sec(stats: PlayerStats) -> float:
	return Balance.COMBO_WINDOW_SEC + stats.combo_window_bonus_sec
