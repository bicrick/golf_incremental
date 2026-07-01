class_name GolfHitSfx
extends RefCounted
## Golf swing impact WAV pools — trimmed Mixkit clips under assets/audio/sfx/golf/.

const GOLF_SFX_DIR := "res://assets/audio/sfx/golf/"

const NORMAL_FILES: Array[String] = [
	"mixkit-golf-ball-hit-2105.wav",
	"mixkit-quick-golf-hit-2121.wav",
	"mixkit-quick-shot-golf-2125.wav",
	"mixkit-short-golf-shot-2127.wav",
]

const POWER_FILES: Array[String] = [
	"mixkit-golf-ball-hard-hit-2120.wav",
	"mixkit-hard-golf-swing-2119.wav",
	"mixkit-powerful-golf-shot-2126.wav",
	"mixkit-sharp-golf-hit-2122.wav",
	"mixkit-golf-metal-shot-2123.wav",
]


static func normal_paths() -> Array[String]:
	return _paths_for(NORMAL_FILES)


static func power_paths() -> Array[String]:
	return _paths_for(POWER_FILES)


static func is_big_hit(timing_tier: int, feedback_tier: int) -> bool:
	return feedback_tier == Balance.FeedbackTier.JACKPOT \
		or timing_tier == Balance.TimingTier.PERFECT


static func volume_db_for(timing_tier: int, is_big: bool) -> float:
	if is_big:
		if timing_tier == Balance.TimingTier.PERFECT:
			return -1.0
		return -2.0
	match timing_tier:
		Balance.TimingTier.GREAT:
			return -2.5
		Balance.TimingTier.GOOD:
			return -3.0
		Balance.TimingTier.OKAY:
			return -4.0
		Balance.TimingTier.BAD:
			return -4.5
		_:
			return -5.0


static func _paths_for(files: Array[String]) -> Array[String]:
	var paths: Array[String] = []
	for file_name in files:
		paths.append(GOLF_SFX_DIR.path_join(file_name))
	return paths
