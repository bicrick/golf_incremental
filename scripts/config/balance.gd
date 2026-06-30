class_name Balance
extends RefCounted
## Tunable constants — single source for balance numbers.

const SAVE_VERSION: int = 1
const BPM: float = 66.0
const AUTOSAVE_INTERVAL_SEC: float = 30.0

const TIER_MULTS: Dictionary = {
	0: 1.0,   # PERFECT
	1: 0.7,   # GOOD
	2: 0.4,   # OK
	3: 0.1,   # MISS pity
}

const COMBO_BONUS_PER_STACK: float = 0.1
const JACKPOT_PAYOUT_THRESHOLD: float = 500.0

enum TimingTier { PERFECT, GOOD, OK, MISS }
enum FeedbackTier { WHISPER, WARM, JACKPOT, MILESTONE }
enum UpgradeBranch { RHYTHM, DISTANCE, CLUBS, BALLS, RANGE, OUTFITS, ECONOMY, FRIENDS }


static func default_stats() -> PlayerStats:
	var stats := PlayerStats.new()
	stats.timing_window_perfect_ms = 50.0
	stats.timing_window_good_ms = 100.0
	stats.swing_cooldown_ms = 800.0
	stats.base_yards = 10.0
	stats.max_yards = 50.0
	stats.dollars_per_yard = 1.0
	return stats
