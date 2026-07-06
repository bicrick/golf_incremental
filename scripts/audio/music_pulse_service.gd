extends Node
## Smooth, music-synced backdrop sway — sine phase from playback tempo + live beat locking.

const MusicTrackRhythmRes := preload("res://scripts/audio/music_track_rhythm.gd")
const BASS_MIN_HZ := 60.0
const BASS_MAX_HZ := 200.0
const ENERGY_SMOOTH := 0.88
const FLUX_THRESHOLD := 1.6
const ONSET_COOLDOWN_SEC := 0.18
const MIN_BEAT_SEC := 0.35
const MAX_BEAT_SEC := 1.25
const BEAT_LOCK_BLEND := 0.42
const BEAT_PERIOD_BLEND := 0.28
const ENVELOPE_FADE := 8.0
## One full left-right sway cycle every two beats (gentler than per-beat).
const SWAY_CYCLES_PER_BEAT := 0.5

var _smoothed_energy := 0.0
var _prev_energy := 0.0
var _cooldown := 0.0
var _beat_sec: float = 60.0 / 112.0
var _sync_offset_sec := 0.0
var _phase := 0.0
var _envelope := 0.0
var _sway_current := 0.0
var _last_track_path := ""
var _last_onset_playback := -1.0


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var fade := 1.0 - exp(-ENVELOPE_FADE * delta)

	if not SfxManager.is_music_active():
		_envelope = lerpf(0.0, _envelope, fade)
		_sway_current = sin(_phase * TAU * SWAY_CYCLES_PER_BEAT) * _envelope
		_reset_spectrum_tracking()
		return

	_check_track_change()
	_lock_to_bass_onsets()
	_update_phase_from_playback()
	_envelope = lerpf(1.0, _envelope, fade)
	_sway_current = sin(_phase * TAU * SWAY_CYCLES_PER_BEAT) * _envelope


func is_active() -> bool:
	return SfxManager.is_music_active()


func get_sway_amount() -> float:
	if not SfxManager.is_music_active():
		return 0.0
	return _sway_current


func get_pulse_strength() -> float:
	return absf(get_sway_amount())


func debug_trigger_pulse() -> void:
	_phase = 0.25
	_envelope = 1.0
	_sway_current = sin(_phase * TAU * SWAY_CYCLES_PER_BEAT)


func _update_phase_from_playback() -> void:
	var playback := SfxManager.get_music_playback_position()
	var elapsed := playback - _sync_offset_sec
	if elapsed < 0.0:
		elapsed = 0.0
	_phase = fposmod(elapsed / _beat_sec, 1.0)


func _lock_to_bass_onsets() -> void:
	var spectrum := SfxManager.get_music_spectrum_instance()
	if spectrum == null:
		return

	var mag := spectrum.get_magnitude_for_frequency_range(BASS_MIN_HZ, BASS_MAX_HZ)
	var energy := mag.length()
	var flux := maxf(energy - _prev_energy, 0.0)
	_prev_energy = energy

	if _smoothed_energy <= 0.0001:
		_smoothed_energy = energy
	else:
		_smoothed_energy = lerpf(energy, _smoothed_energy, ENERGY_SMOOTH)

	var threshold := maxf(_smoothed_energy * FLUX_THRESHOLD, 0.0005)
	if flux < threshold or _cooldown > 0.0:
		return

	_cooldown = ONSET_COOLDOWN_SEC
	var playback := SfxManager.get_music_playback_position()
	_apply_beat_lock(playback)


func _apply_beat_lock(playback: float) -> void:
	if _last_onset_playback >= 0.0:
		var measured := playback - _last_onset_playback
		if measured >= MIN_BEAT_SEC and measured <= MAX_BEAT_SEC:
			_beat_sec = lerpf(measured, _beat_sec, BEAT_PERIOD_BLEND)
	_last_onset_playback = playback

	var elapsed := playback - _sync_offset_sec
	if elapsed < 0.0:
		return

	var beat_index := roundf(elapsed / _beat_sec)
	var expected: float = _sync_offset_sec + beat_index * _beat_sec
	var error: float = playback - expected
	_sync_offset_sec += error * BEAT_LOCK_BLEND


func _check_track_change() -> void:
	var path := SfxManager.get_current_music_track_path()
	if path.is_empty() or path == _last_track_path:
		return
	_last_track_path = path
	_beat_sec = MusicTrackRhythmRes.beat_duration_sec(path)
	_sync_offset_sec = MusicTrackRhythmRes.get_offset_sec(path)
	_phase = 0.0
	_envelope = 0.0
	_sway_current = 0.0
	_last_onset_playback = -1.0
	_reset_spectrum_tracking()


func _reset_spectrum_tracking() -> void:
	_smoothed_energy = 0.0
	_prev_energy = 0.0
