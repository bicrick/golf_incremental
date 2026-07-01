class_name Balance
extends RefCounted
## Tunable constants — single source for balance numbers.

const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL_SEC: float = 30.0

## v2 Phase C — balls per strike burst before harvest.
const BUCKET_CAPACITY_DEFAULT: int = 6

## v2 Phase D — pickup mini-game economy.
const PICKUP_PER_BALL: float = 0.50
const BUCKET_COMPLETE_BONUS: float = 5.0
const COMBO_WINDOW_SEC: float = 0.8
const COMBO_MULT_PER_TIER: float = 0.10

# v2 Phase E — contact swing (release at frame-8 contact, not hold-to-peak)
const CONTACT_WINDUP_SEC: float = 0.5
const CONTACT_DECAY_SEC: float = 0.6
const MIN_HOLD_SEC: float = 0.05
## Legacy aliases — same values as contact timing.
const CHARGE_DURATION_SEC: float = CONTACT_WINDUP_SEC
const CHARGE_DECAY_SEC: float = CONTACT_DECAY_SEC
## Past peak: no Perfect; OK caps here, then Miss (half decay window).
const POST_PEAK_OK_MAX_SEC: float = CHARGE_DECAY_SEC * 0.5
const POST_PEAK_GOOD_MS: float = 35.0

# Concentric ring visuals — inner rhombus expands into outer target (shared base polygon)
const RING_INNER_START_FRAC: float = 0.20
const RING_INNER_CONTACT_FRAC: float = 1.0
const RING_INNER_OVERSHOOT_FRAC: float = 1.05
## Outer target size scales with distance/power upgrades (noob → maxed).
const RING_OUTER_MIN_SCALE: float = 0.55
const RING_OUTER_MAX_SCALE: float = 1.35

const TIER_MULTS: Dictionary = {
	0: 1.0,   # PERFECT
	1: 0.7,   # GOOD
	2: 0.4,   # OK
	3: 0.1,   # MISS pity
}

# Continuous yard curve — tiers stay discrete for labels / payout mult only.
const YARD_QUALITY_FLOOR: float = 0.1
## Late release cannot reach dead-center quality (no Perfect tier past peak).
const YARD_QUALITY_LATE_PEAK: float = 0.92

const TIER_NAMES: Array[String] = ["Perfect!", "Good", "OK", "Miss"]

const TIER_COLORS: Array[Color] = [
	Color(0.35, 0.85, 0.42),  # PERFECT — green
	Color(1.0, 0.88, 0.25),   # GOOD — yellow
	Color(0.95, 0.58, 0.22),  # OK — orange (between good and miss)
	Color(0.92, 0.32, 0.28),  # MISS — red
]

const JACKPOT_PAYOUT_THRESHOLD: float = 500.0

## Fixed world-to-screen range — visual depth ignores gameplay max_yards cap.
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
## Visual carry floor / whiff cap, now expressed directly in world-space yards.
const VISUAL_FLOOR_YARDS: float = 50.0
const WHIFF_MAX_YARDS: float = 4.0
## Lateral scatter on landing (world yards), scaled by depth fraction of VISUAL_MAX_YARDS.
const LANDING_SCATTER_YARDS: float = 3.0
## Fairway corridor half-width in yards — used for ground stripes, fence placement, bounds.
const FAIRWAY_HALF_WIDTH_YARDS: float = 15.0
## Flight duration clamp (seconds) — arcade pacing, independent of raw physics extremes.
const FLIGHT_TIME_MIN_SEC: float = 0.30
const FLIGHT_TIME_MAX_SEC: float = 3.2

enum TimingTier { PERFECT, GOOD, OK, MISS }
enum ContactFlavor { PURE, SLIGHTLY_FAT, THIN, CHUNK }
enum FeedbackTier { WHISPER, WARM, JACKPOT, MILESTONE }
enum UpgradeBranch { RHYTHM, DISTANCE, CLUBS, BALLS, RANGE, OUTFITS, ECONOMY, FRIENDS }


static func default_stats() -> PlayerStats:
	var stats := PlayerStats.new()
	stats.timing_window_perfect_ms = 50.0
	stats.timing_window_good_ms = 100.0
	stats.swing_cooldown_ms = 1800.0
	stats.base_yards = 30.0
	stats.max_yards = 45.0
	stats.dollars_per_yard = 1.0
	return stats
