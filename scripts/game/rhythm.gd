class_name Rhythm
extends RefCounted
## Beat clock and timing evaluation — Workstream A expands.

var bpm: float = Balance.BPM
var beat_phase: float = 0.0
var combo: int = 0


func update(delta: float) -> void:
	var beats_per_sec := bpm / 60.0
	beat_phase = fmod(beat_phase + delta * beats_per_sec, 1.0)


func evaluate_timing(click_phase: float, stats: PlayerStats) -> int:
	var dist := absf(click_phase - _nearest_beat_center(click_phase))
	var dist_ms := dist * (60.0 / bpm) * 1000.0
	if dist_ms <= stats.timing_window_perfect_ms:
		return Balance.TimingTier.PERFECT
	if dist_ms <= stats.timing_window_good_ms:
		return Balance.TimingTier.GOOD
	if dist_ms <= stats.timing_window_good_ms * 1.5:
		return Balance.TimingTier.OK
	return Balance.TimingTier.MISS


func _nearest_beat_center(phase: float) -> float:
	if phase < 0.25 or phase > 0.75:
		return 0.0
	return 0.5
