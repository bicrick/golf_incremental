extends Node
## Procedural placeholder SFX + BGM from assets/audio/music/.

const POOL_SIZE := 3
const MIX_RATE := 22050
const MUSIC_DIR := "res://assets/audio/music/"
const BGM_VOLUME_DB := -9.0
const MUSIC_EXTENSIONS := ["mp3", "ogg", "wav", "flac"]

var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _streams: Dictionary = {}
var _golf_hit_normal: Array[AudioStream] = []
var _golf_hit_power: Array[AudioStream] = []
var _ambient_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_tracks: Array[String] = []
var _rotation_index := 0
var _is_title_mode := false
var _sfx_enabled := true
var _music_enabled := true
var _sfx_volume := 1.0
var _music_volume := 1.0


func _ready() -> void:
	_sfx_enabled = SaveManager.sfx_enabled
	_music_enabled = SaveManager.music_enabled
	_sfx_volume = SaveManager.sfx_volume
	_music_volume = SaveManager.music_volume
	_build_streams()
	_load_golf_hit_streams()
	_build_pool()
	_refresh_music_tracks()
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.ui_panel_toggled.connect(_on_ui_panel_toggled)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)


func get_music_tracks() -> Array[String]:
	_refresh_music_tracks()
	return _music_tracks.duplicate()


func is_sfx_enabled() -> bool:
	return _sfx_enabled


func is_music_enabled() -> bool:
	return _music_enabled


func get_sfx_volume() -> float:
	return _sfx_volume


func get_music_volume() -> float:
	return _music_volume


func set_sfx_volume(volume: float) -> void:
	_sfx_volume = clampf(volume, 0.0, 1.0)
	SaveManager.sfx_volume = _sfx_volume
	SaveManager.save_settings()


func set_music_volume(volume: float) -> void:
	_music_volume = clampf(volume, 0.0, 1.0)
	SaveManager.music_volume = _music_volume
	SaveManager.save_settings()
	_apply_music_volume()


func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled
	SaveManager.sfx_enabled = enabled
	SaveManager.save_settings()


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	SaveManager.music_enabled = enabled
	SaveManager.save_settings()
	_apply_music_enabled()


func play_title_bgm() -> void:
	if not _music_enabled:
		return
	if _music_player != null or _ambient_player != null:
		return
	_refresh_music_tracks()
	if _music_tracks.is_empty():
		return
	_is_title_mode = true
	_rotation_index = _random_track_index()
	_play_track_at_path(_music_tracks[_rotation_index], false)


func start_bgm() -> void:
	if not _music_enabled:
		return
	if _ambient_player != null:
		return
	if _music_player != null and not _is_title_mode:
		return
	_refresh_music_tracks()
	if _music_tracks.is_empty():
		if _music_player == null:
			_start_ambient()
		return
	# Title track already playing — finish this track, then rotate through the playlist.
	if _music_player != null and _is_title_mode and _music_player.playing:
		_is_title_mode = false
		if _music_player.stream != null:
			_set_stream_loop(_music_player.stream, false)
		if not _music_player.finished.is_connected(_on_music_finished):
			_music_player.finished.connect(_on_music_finished)
		return
	_is_title_mode = false
	if _music_player != null and _music_player.finished.is_connected(_on_music_finished):
		_music_player.finished.disconnect(_on_music_finished)
	_rotation_index = _random_track_index()
	_start_rotation_at(_rotation_index)


func play_start() -> void:
	_play("play_whoosh", -8.0, 0.95)
	_play("play_fanfare", -4.0)


func _refresh_music_tracks() -> void:
	_music_tracks = _discover_music_tracks()


func _discover_music_tracks() -> Array[String]:
	var candidates: Array[String] = []
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return candidates
	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() in MUSIC_EXTENSIONS:
			candidates.append(MUSIC_DIR.path_join(file_name))
	candidates.sort()
	return candidates


func _random_track_index() -> int:
	return randi() % _music_tracks.size()


func _start_rotation_at(index: int) -> void:
	_rotation_index = index
	_play_track_at_path(_music_tracks[_rotation_index], false)


func _play_track_at_path(path: String, loop: bool) -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("SfxManager: failed to load BGM at %s" % path)
		if _music_player == null and not _is_title_mode:
			_start_ambient()
		return
	_set_stream_loop(stream, loop)
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "BackgroundMusic"
		_music_player.volume_db = _effective_music_db(BGM_VOLUME_DB)
		_music_player.autoplay = false
		add_child(_music_player)
	if _music_player.finished.is_connected(_on_music_finished):
		_music_player.finished.disconnect(_on_music_finished)
	_music_player.stream = stream
	if not loop:
		_music_player.finished.connect(_on_music_finished)
	_apply_music_volume()
	_music_player.play()


func _on_music_finished() -> void:
	if _music_tracks.is_empty():
		return
	_rotation_index = (_rotation_index + 1) % _music_tracks.size()
	_play_track_at_path(_music_tracks[_rotation_index], false)


func _start_ambient() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientWind"
	_ambient_player.stream = _streams["ambient_wind"]
	_ambient_player.volume_db = _effective_music_db(-28.0)
	_ambient_player.autoplay = false
	add_child(_ambient_player)
	_ambient_player.play()


func _set_stream_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamMP3:
		stream.loop = loop
	elif stream is AudioStreamOggVorbis:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = (
			AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		)


func _apply_music_enabled() -> void:
	_apply_music_volume()
	if not _music_enabled:
		return
	if _music_player == null and _ambient_player == null:
		play_title_bgm()


func _apply_music_volume() -> void:
	_set_music_volume(_effective_music_db(BGM_VOLUME_DB))
	if _ambient_player != null:
		_ambient_player.volume_db = _effective_music_db(-28.0)


func _effective_music_db(base_db: float) -> float:
	if not _music_enabled or _music_volume <= 0.0:
		return -80.0
	return base_db + linear_to_db(_music_volume)


func _effective_sfx_db(base_db: float) -> float:
	if not _sfx_enabled or _sfx_volume <= 0.0:
		return -80.0
	return base_db + linear_to_db(_sfx_volume)


func _set_music_volume(volume_db: float) -> void:
	if _music_player != null:
		_music_player.volume_db = volume_db


func _play(stream_key: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _streams.has(stream_key):
		return
	_play_stream(_streams[stream_key], volume_db, pitch_scale)


func _play_stream(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _sfx_enabled or _sfx_volume <= 0.0:
		return
	if stream == null:
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = _effective_sfx_db(volume_db)
	player.pitch_scale = pitch_scale
	player.play()


func _play_golf_hit(timing_tier: int, feedback_tier: int) -> void:
	var is_big := GolfHitSfx.is_big_hit(timing_tier, feedback_tier)
	var pool := _golf_hit_power if is_big else _golf_hit_normal
	if pool.is_empty():
		return
	var stream := pool[randi() % pool.size()]
	var volume_db := GolfHitSfx.volume_db_for(timing_tier, is_big)
	var pitch := randf_range(0.97, 1.03)
	_play_stream(stream, volume_db, pitch)


func _on_swing_charging_changed(charging: bool) -> void:
	if charging:
		_play("charge_start", -6.0)


func _on_swing_resolved(
	_yards: float,
	timing_tier: int,
	payout: float,
	_feedback_tier: int
) -> void:
	_play_golf_hit(timing_tier, _feedback_tier)
	if timing_tier == Balance.TimingTier.PERFECT:
		_play("perfect_chime", -4.0, 1.0)

	if payout >= 25.0:
		var cash_pitch := clampf(1.0 + log(maxf(payout, 1.0)) / log(500.0) * 0.35, 1.0, 1.45)
		_play("cash_register", -4.0, cash_pitch)


func _on_ui_panel_toggled(panel_id: String, is_open: bool) -> void:
	if panel_id == "upgrades" or panel_id == "settings":
		if is_open:
			_play("menu_open_pop", -12.0)
			_play("menu_open", -6.0)
		else:
			_play("menu_close", -7.0)
		return
	_play("ui_click", -8.0)


func _on_upgrade_purchased(_id: String, level: int, _branch: int) -> void:
	var pitch := clampf(0.95 + float(level - 1) * 0.035, 0.95, 1.4)
	_play("upgrade_tap", -12.0, pitch)
	_play("upgrade_purchase", -2.0, pitch)


func _build_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = &"Master"
		add_child(player)
		_pool.append(player)


func _build_streams() -> void:
	_streams["charge_start"] = _make_click(620.0, 0.05, 0.32)
	_streams["perfect_chime"] = _make_chime([880.0, 1320.0], 0.22, 0.3)
	_streams["cash_register"] = _make_chime([660.0, 880.0, 1108.0, 1320.0], 0.18, 0.32)
	_streams["ui_click"] = _make_click(980.0, 0.035, 0.28)
	_streams["menu_open_pop"] = _make_click(660.0, 0.028, 0.34)
	_streams["menu_open"] = _make_arpeggio([523.0, 659.0, 784.0, 988.0], 0.045, 0.3)
	_streams["menu_close"] = _make_arpeggio([880.0, 698.0, 554.0, 440.0], 0.04, 0.24)
	_streams["upgrade_tap"] = _make_click(740.0, 0.022, 0.3)
	_streams["upgrade_purchase"] = _make_arpeggio(
		[698.0, 880.0, 1047.0, 1319.0, 1568.0], 0.032, 0.36
	)
	_streams["play_whoosh"] = _make_thwack(150.0, 0.14, 0.2, 0.5)
	_streams["play_fanfare"] = _make_chime([440.0, 554.0, 659.0, 880.0, 1108.0], 0.38, 0.24)
	_streams["ambient_wind"] = _make_wind_loop(2.5, 0.06)


func _load_golf_hit_streams() -> void:
	_golf_hit_normal.clear()
	_golf_hit_power.clear()
	for path in GolfHitSfx.normal_paths():
		var stream: AudioStream = load(path)
		if stream == null:
			push_warning("SfxManager: failed to load golf hit at %s" % path)
			continue
		_golf_hit_normal.append(stream)
	for path in GolfHitSfx.power_paths():
		var stream: AudioStream = load(path)
		if stream == null:
			push_warning("SfxManager: failed to load golf power hit at %s" % path)
			continue
		_golf_hit_power.append(stream)


func _make_click(freq_hz: float, duration_sec: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(duration_sec * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / MIX_RATE
		var env := exp(-18.0 * t / duration_sec)
		var sample := sin(TAU * freq_hz * t) * volume * env
		_write_sample(data, i, sample)
	return _pack_wav(data)


func _make_thwack(
	tone_hz: float,
	duration_sec: float,
	volume: float,
	noise_mix: float
) -> AudioStreamWAV:
	var sample_count := int(duration_sec * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tone_hz * 1000.0)
	for i in sample_count:
		var t := float(i) / MIX_RATE
		var env := exp(-5.5 * t / duration_sec)
		var tone := sin(TAU * tone_hz * t) * (1.0 - noise_mix)
		var noise := rng.randf_range(-1.0, 1.0) * noise_mix
		var sample := (tone + noise) * volume * env
		_write_sample(data, i, sample)
	return _pack_wav(data)


func _make_arpeggio(freqs: Array, note_duration_sec: float, volume: float) -> AudioStreamWAV:
	var total_duration := note_duration_sec * freqs.size()
	var sample_count := int(total_duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / MIX_RATE
		var note_index := mini(int(t / note_duration_sec), freqs.size() - 1)
		var note_t := fmod(t, note_duration_sec)
		var freq := float(freqs[note_index])
		var env := exp(-8.0 * note_t / note_duration_sec)
		var sample := sin(TAU * freq * note_t) * volume * env
		_write_sample(data, i, sample)
	return _pack_wav(data)


func _make_chime(freqs: Array, duration_sec: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(duration_sec * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / MIX_RATE
		var env := exp(-3.5 * t / duration_sec)
		var sample := 0.0
		for freq in freqs:
			sample += sin(TAU * float(freq) * t)
		sample = sample / float(freqs.size()) * volume * env
		_write_sample(data, i, sample)
	return _pack_wav(data)


func _make_wind_loop(duration_sec: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(duration_sec * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var smoothed := 0.0
	for i in sample_count:
		var raw := rng.randf_range(-1.0, 1.0)
		smoothed = lerpf(smoothed, raw, 0.02)
		var sample := smoothed * volume
		_write_sample(data, i, sample)
	var stream := _pack_wav(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _write_sample(data: PackedByteArray, index: int, sample: float) -> void:
	var int_sample := int(clampf(sample, -1.0, 1.0) * 32767.0)
	data[index * 2] = int_sample & 0xFF
	data[index * 2 + 1] = (int_sample >> 8) & 0xFF


func _pack_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
