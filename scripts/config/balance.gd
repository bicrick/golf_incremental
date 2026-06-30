class_name Balance
extends RefCounted
## Tunable constants — single source for balance numbers.

const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL_SEC: float = 30.0

# Hold-to-charge swing
const CHARGE_DURATION_SEC: float = 0.5
const CHARGE_DECAY_SEC: float = 0.6
const MIN_HOLD_SEC: float = 0.05
## Past peak: no Perfect; OK caps here, then Miss (half decay window).
const POST_PEAK_OK_MAX_SEC: float = CHARGE_DECAY_SEC * 0.5
const POST_PEAK_GOOD_MS: float = 35.0

# Concentric ring visuals (outer shrinks toward fixed inner sweet spot)
const RING_OUTER_START_SCALE: float = 2.0
const RING_OUTER_ALIGN_SCALE: float = 1.0
const RING_OUTER_OVERSHOOT_SCALE: float = 0.35
const RING_INNER_SCALE: float = 1.0

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
	Color(1.0, 0.88, 0.25),
	Color(0.55, 0.85, 0.45),
	Color(0.75, 0.75, 0.75),
	Color(0.9, 0.45, 0.4),
]

const JACKPOT_PAYOUT_THRESHOLD: float = 500.0

## Fixed world-to-screen range — visual depth ignores gameplay max_yards cap.
const VISUAL_MAX_YARDS: float = 300.0
## Exponential depth scale — larger = nearer shots stay closer to tee before compressing.
const PERSPECTIVE_DEPTH_SCALE: float = 180.0
## Power on normalized depth — >1 keeps short shots near tee, compresses far yard gaps.
const PERSPECTIVE_DEPTH_EXPONENT: float = 1.4

enum TimingTier { PERFECT, GOOD, OK, MISS }
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
