extends Node
## Procedural placeholder SFX — subscribes to EventBus; no binary assets required.

const POOL_SIZE := 3
const MIX_RATE := 22050

var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _streams: Dictionary = {}
var _ambient_player: AudioStreamPlayer


func _ready() -> void:
	_build_streams()
	_build_pool()
	_start_ambient()
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.combo_broken.connect(_on_combo_broken)
	EventBus.ui_panel_toggled.connect(_on_ui_panel_toggled)
	EventBus.swing_chain_window_started.connect(_on_chain_window_started)
	EventBus.swing_chain_charging_started.connect(_on_chain_charging_started)


func _build_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = &"Master"
		add_child(player)
		_pool.append(player)


func _build_streams() -> void:
	_streams["charge_start"] = _make_click(620.0, 0.05, 0.32)
	_streams["thwack_miss"] = _make_thwack(90.0, 0.14, 0.45, 0.25)
	_streams["thwack_ok"] = _make_thwack(130.0, 0.12, 0.5, 0.35)
	_streams["thwack_good"] = _make_thwack(210.0, 0.1, 0.55, 0.55)
	_streams["thwack_perfect"] = _make_thwack(320.0, 0.09, 0.6, 0.75)
	_streams["perfect_chime"] = _make_chime([880.0, 1320.0], 0.22, 0.3)
	_streams["chain_window_tick"] = _make_click(1040.0, 0.04, 0.22)
	_streams["chain_perfect_chime"] = _make_chime([988.0, 1480.0, 1976.0], 0.28, 0.38)
	_streams["combo_break"] = _make_descending_blip(420.0, 180.0, 0.16, 0.4)
	_streams["ui_click"] = _make_click(980.0, 0.035, 0.28)
	_streams["ambient_wind"] = _make_wind_loop(2.5, 0.06)


func _start_ambient() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientWind"
	_ambient_player.stream = _streams["ambient_wind"]
	_ambient_player.volume_db = -28.0
	_ambient_player.autoplay = true
	add_child(_ambient_player)


func _play(stream_key: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _streams.has(stream_key):
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = _streams[stream_key]
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func _on_swing_charging_changed(charging: bool) -> void:
	if charging:
		_play("charge_start", -6.0)


func _on_chain_window_started() -> void:
	_play("perfect_chime", -4.0, 1.0)
	_play("chain_window_tick", -10.0, 1.05)


func _on_chain_charging_started() -> void:
	_play("charge_start", -4.0, 1.25)


func _on_swing_resolved(
	_yards: float,
	timing_tier: int,
	_payout: float,
	_feedback_tier: int,
	_combo: int,
	chain_level: int
) -> void:
	match timing_tier:
		Balance.TimingTier.PERFECT:
			_play("thwack_perfect", -2.0)
			if chain_level >= 2:
				_play("chain_perfect_chime", -1.0, 1.0)
			elif not Balance.CHAIN_ENABLED:
				_play("perfect_chime", -4.0, 1.0)
		Balance.TimingTier.GOOD:
			_play("thwack_good", -3.0)
		Balance.TimingTier.OK:
			_play("thwack_ok", -5.0)
		_:
			_play("thwack_miss", -6.0, 0.95)


func _on_combo_broken(_previous_combo: int) -> void:
	_play("combo_break", -4.0)


func _on_ui_panel_toggled(_panel_id: String, _is_open: bool) -> void:
	_play("ui_click", -8.0)


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


func _make_descending_blip(
	start_hz: float,
	end_hz: float,
	duration_sec: float,
	volume: float
) -> AudioStreamWAV:
	var sample_count := int(duration_sec * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var progress := float(i) / maxf(float(sample_count - 1), 1.0)
		var t := float(i) / MIX_RATE
		var freq := lerpf(start_hz, end_hz, progress)
		var env := (1.0 - progress) * (1.0 - progress)
		var sample := sin(TAU * freq * t) * volume * env
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
