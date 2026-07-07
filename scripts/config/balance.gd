class_name Balance
extends RefCounted
## Tunable constants — single source for balance numbers.

const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL_SEC: float = 30.0

## v2 Phase C — balls per strike burst before harvest.
const BUCKET_CAPACITY_DEFAULT: int = 6
## Pro Shop More Balls ceiling (default + max shop levels).
const BUCKET_CAPACITY_MAX: int = 30

## v2 Phase D — pickup mini-game economy.
const BUCKET_COMPLETE_BONUS: float = 5.0
const COMBO_WINDOW_SEC: float = 0.8
const COMBO_MULT_PER_TIER: float = 0.10

## Harvest range picker — world-radius circle on the fairway (yards).
const RANGE_PICKER_BASE_RADIUS_YARDS: float = 0.19
## Linear stat increment per upgrade level (maps to curve below).
const RANGE_PICKER_RADIUS_PER_LEVEL: float = 0.04
const RANGE_PICKER_MAX_LEVEL: int = 10
## Max harvest circle at full upgrade (3× former 0.59 yd cap).
const RANGE_PICKER_MAX_RADIUS_YARDS: float = 1.77
## Ease-in exponent — modest early gains, stronger radius growth at high levels.
const RANGE_PICKER_RADIUS_CURVE_EXP: float = 1.5
## Extra world slack so balls near the ring edge register as hits.
const RANGE_PICKER_HIT_SLACK_YARDS: float = 0.03

# v2 Phase E — contact swing (release at frame-8 contact, not hold-to-peak)
const CONTACT_WINDUP_SEC: float = 0.5
const CONTACT_DECAY_SEC: float = 0.6
const MIN_HOLD_SEC: float = 0.05
## Legacy aliases — same values as contact timing.
const CHARGE_DURATION_SEC: float = CONTACT_WINDUP_SEC
const CHARGE_DECAY_SEC: float = CONTACT_DECAY_SEC
## Past peak: no Perfect; ladder degrades Great → Good → Okay → Bad, then Miss (half decay window).
const POST_PEAK_GREAT_MS: float = 15.0
const POST_PEAK_GOOD_MS: float = 35.0
const POST_PEAK_OKAY_MS: float = 90.0
const POST_PEAK_BAD_MAX_SEC: float = CHARGE_DECAY_SEC * 0.5

# Concentric ring visuals — inner rhombus expands into outer target (shared base polygon)
const RING_INNER_START_FRAC: float = 0.20
const RING_INNER_CONTACT_FRAC: float = 1.0
const RING_INNER_OVERSHOOT_FRAC: float = 1.05
## Outer target size scales with distance/power upgrades (noob → maxed).
const RING_OUTER_MIN_SCALE: float = 0.55
const RING_OUTER_MAX_SCALE: float = 1.35

const TIER_MULTS: Dictionary = {
	0: 1.0,   # PERFECT
	1: 0.8,   # GREAT
	2: 0.6,   # GOOD
	3: 0.4,   # OKAY
	4: 0.2,   # BAD
	5: 0.1,   # MISS pity
}

# Continuous yard curve — tiers stay discrete for labels / payout mult only.
const YARD_QUALITY_FLOOR: float = 0.08
## Late release cannot reach dead-center quality (no Perfect tier past peak).
const YARD_QUALITY_LATE_PEAK: float = 0.92

const TIER_NAMES: Array[String] = ["Perfect!", "Great!", "Good", "Okay", "Bad", "Miss"]

## Timing tier (PERFECT..MISS) -> payout quality integer (6..1).
const QUALITY_FOR_TIER: Array[int] = [6, 5, 4, 3, 2, 1]

const TIER_COLORS: Array[Color] = [
	Color(0.35, 0.85, 0.42),  # PERFECT — green
	Color(0.62, 0.85, 0.30),  # GREAT — yellow-green
	Color(1.0, 0.88, 0.25),   # GOOD — yellow
	Color(0.95, 0.58, 0.22),  # OKAY — orange
	Color(0.92, 0.42, 0.24),  # BAD — red-orange
	Color(0.78, 0.22, 0.22),  # MISS — deep red
]

const JACKPOT_PAYOUT_THRESHOLD: float = 500.0

## Fixed world-to-screen range — perspective mapping only (not gameplay carry).
const VISUAL_MAX_YARDS: float = 300.0
## Exponential depth scale — larger = nearer shots stay closer to tee before compressing.
const PERSPECTIVE_DEPTH_SCALE: float = 180.0
## Power on normalized depth — >1 keeps short shots near tee, compresses far yard gaps.
const PERSPECTIVE_DEPTH_EXPONENT: float = 1.4

## v2 Phase B — visual carry floor (gameplay yards unchanged; flight path only).
## First fairway depth band (~50yd marker) for OK+ contact tiers.
const VISUAL_FLOOR_Y: float = 170.0
## Minimum perspective p for OK+ — matches VISUAL_FLOOR_Y on default tee/far segment.
const VISUAL_FLOOR_P: float = 0.356
## Cap whiff/miss depth near tee (dribble).
const WHIFF_MAX_P: float = 0.06
## OK+ minimum arc so short carries never read as ground skids.
const VISUAL_ARC_MIN_PX: float = 36.0
## Max tee-to-landing travel (px) for whiff acceptance tests.
const VISUAL_DRIBBLE_MAX_PX: float = 14.0

## --- Real 3D flight (scripts/range/ball_flight_3d.gd) ---
## World unit = 1 yard. Tee at world origin, ball flies down -Z, side scatter on X, arc on Y.
const WORLD_UNITS_PER_YARD: float = 1.0
## Tuned "arcade" gravity (world units/s^2) — not real-world g, chosen for snappy arcs.
const FLIGHT_GRAVITY: float = 60.0
## Apex height as a fraction of visual travel distance, by contact flavor.
const FLIGHT_APEX_RATIO: Dictionary = {
	0: 0.30,  # PURE
	1: 0.17,  # SLIGHTLY_FAT
	2: 0.045, # THIN — low skid
	3: 0.07,  # CHUNK — short fat hop
}
const FLIGHT_MIN_APEX_YARDS: float = 0.15
## Lateral scatter on landing (world yards), scaled by depth fraction of VISUAL_MAX_YARDS.
const LANDING_SCATTER_YARDS: float = 3.0
## Fairway corridor half-width in yards — used for ground stripes, fence placement, bounds.
const FAIRWAY_HALF_WIDTH_YARDS: float = 15.0
## Flight duration clamp (seconds) — arcade pacing, independent of raw physics extremes.
const FLIGHT_TIME_MIN_SEC: float = 0.30
const FLIGHT_TIME_MAX_SEC: float = 3.2

## Screen-space ball flight trail (scripts/visual/ball_flight_trail.gd).
const FLIGHT_TRAIL_MAX_POINTS := 14
const FLIGHT_TRAIL_MIN_SAMPLE_PX := 2.0
const FLIGHT_TRAIL_WIDTH := 2.25
const FLIGHT_TRAIL_HEAD_ALPHA := 0.55

enum TimingTier { PERFECT, GREAT, GOOD, OKAY, BAD, MISS }
enum ContactFlavor { PURE, SLIGHTLY_FAT, THIN, CHUNK }
enum FeedbackTier { WHISPER, WARM, JACKPOT, MILESTONE }
enum UpgradeBranch { BASE_PAY, POWER, QUALITY, PICKUP }

## One-time cost to unlock the upgrade tree from the icon bar.
const UPGRADES_UNLOCK_COST: float = 1.50
## One-time cost to unlock the Pro Shop from the icon bar.
const SHOP_UNLOCK_COST: float = 50.0
## One-time cost to hire Ratina (placeholder tab only for now).
const RATINA_UNLOCK_COST: float = 100.0
## One-time cost to unlock Rattlings in the shop.
const RATTLING_UNLOCK_COST: float = 10.0
## Per-level cost escalation — each successive upgrade costs more than pure exponential.
const UPGRADE_COST_LEVEL_STRETCH: float = 0.165

## Pro Shop — golden ball chance and payout.
const GOLDEN_BALL_BASE_CHANCE: float = 0.05
const GOLDEN_BALL_CHANCE_PER_LEVEL: float = 0.02
const GOLDEN_BALL_PAYOUT_MULTIPLIER: float = 2.0
const GOLDEN_BALL_TINT := Color(1.0, 0.78, 0.12, 1.0)
const GOLDEN_TRAIL_COLOR := Color(1.0, 0.82, 0.18, 1.0)
const GOLDEN_SPARKLE_COLOR := Color(1.0, 0.92, 0.45, 1.0)
const GOLDEN_TRAIL_WIDTH_MULT: float = 1.35
## Extra balls per bucket per More Balls shop level.
const BALL_COUNT_BONUS_PER_LEVEL: float = 1.0

## Short-shot litter cutoff — shots beyond this visual distance vanish instead of littering.
const VANISH_DISTANCE_YARDS: float = 220.0

## Ratina — autonomous second golfer.
const RATINA_BALL_DESPAWN_SEC: float = 6.0
const RATINA_HOME_OFFSET := Vector3(2.6, -0.22, 0.31)
const RATINA_BALL_OFFSET := Vector3(-0.416, -1.253, -0.271)
## Screen-space offset from projected Ratina ball contact for strike tier text.
const RATINA_STRIKE_TEXT_OFFSET := Vector2(-27.0, -20.0)
## Idle at the tee before each autonomous swing (remainder of swing_cooldown_ms).
const RATINA_ADDRESS_PREP_SEC: float = 0.75

## Rattlings — forest-edge gnome-rats that fetch littered balls.
const RATTLING_PIXEL_SIZE: float = 0.015
## World-space ground height Rattlings walk along, calibrated in-editor
## against the RattlingPlaceholder node in range_view.tscn (Foreground).
const RATTLING_GROUND_Y: float = 0.42861152
const RATTLING_SPAWN_STAGGER_SEC: float = 0.6
const RATTLING_FADE_SEC: float = 0.5
## More Rattlings upgrade — extra active agent per level (level 0 = 1 owned).
const RATTLING_COUNT_BONUS_PER_LEVEL: float = 1.0


static func default_stats() -> PlayerStats:
	var stats := PlayerStats.new()
	stats.timing_window_perfect_ms = 15.0
	stats.timing_window_great_ms = 40.0
	stats.timing_window_good_ms = 80.0
	stats.timing_window_okay_ms = 140.0
	stats.timing_window_bad_ms = 220.0
	stats.timing_window_late_great_ms = POST_PEAK_GREAT_MS
	stats.timing_window_late_good_ms = POST_PEAK_GOOD_MS
	stats.timing_window_late_okay_ms = POST_PEAK_OKAY_MS
	stats.timing_window_late_bad_max_sec = POST_PEAK_BAD_MAX_SEC
	stats.swing_cooldown_ms = 1800.0
	stats.yard_quality_floor = YARD_QUALITY_FLOOR
	stats.yard_quality_late_peak = YARD_QUALITY_LATE_PEAK
	stats.base_yards = 30.0
	stats.carry_multiplier = 1.0
	stats.base_amount = 0.25
	stats.pay_per_yard = 0.02
	stats.quality_multiplier = 1.0
	stats.yardage_term_unlocked = 0.0
	stats.quality_term_unlocked = 0.0
	stats.pickup_bonus_unlocked = 0.0
	stats.pickup_multiplier = 1.0
	stats.pickup_flat_bonus = 0.0
	stats.combo_mult_per_tier = 0.0
	stats.combo_window_bonus_sec = 0.0
	stats.range_picker_radius_bonus = 0.0
	stats.golden_ball_chance = 0.0
	stats.golden_ball_payout_multiplier = GOLDEN_BALL_PAYOUT_MULTIPLIER
	return stats


static func range_picker_radius_yards(stats: PlayerStats) -> float:
	var max_linear_bonus := RANGE_PICKER_RADIUS_PER_LEVEL * float(RANGE_PICKER_MAX_LEVEL)
	if max_linear_bonus <= 0.0:
		return RANGE_PICKER_BASE_RADIUS_YARDS
	var t := clampf(stats.range_picker_radius_bonus / max_linear_bonus, 0.0, 1.0)
	var curved_t := pow(t, RANGE_PICKER_RADIUS_CURVE_EXP)
	var max_bonus := RANGE_PICKER_MAX_RADIUS_YARDS - RANGE_PICKER_BASE_RADIUS_YARDS
	return RANGE_PICKER_BASE_RADIUS_YARDS + max_bonus * curved_t


static func default_ratina_stats() -> PlayerStats:
	var stats := PlayerStats.new()
	stats.base_yards = 22.0
	stats.carry_multiplier = 1.0
	stats.yard_quality_floor = 0.15
	stats.base_amount = 0.12
	stats.pay_per_yard = 0.012
	stats.quality_multiplier = 1.0
	stats.swing_cooldown_ms = 10000.0
	stats.consistency = 0.0
	return stats


## Rattlings don't have an economy of their own — they inherit the exact
## payout the ball's original owner (player or Ratina) would have earned,
## using that owner's own stats/upgrades. These fields are purely the
## Rattling tree's own mechanical/bonus knobs layered on top of delivery.
static func default_rattling_stats() -> PlayerStats:
	var stats := PlayerStats.new()
	stats.rattling_count = 1.0
	stats.rattling_walk_speed = 3.2
	stats.rattling_pickup_speed_multiplier = 1.0
	stats.rattling_golden_bonus_chance = 0.0
	stats.rattling_payout_multiplier = 1.0
	return stats
