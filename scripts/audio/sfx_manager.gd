extends Node
## Game SFX (Cuelume UI cues + Mixkit golf hits) and BGM from assets/audio/music/.

const UiHoverTickScript = preload("res://scripts/audio/ui_hover_tick.gd")

signal music_track_changed(path: String)

const POOL_SIZE := 8
## Procedural SFX sample rate — match AudioServer at runtime (web often 48000).
## A fixed 22050 rate can sound muddy/wrong when HTML5 resampling mis-handles mix_rate.
const MUSIC_DIR := "res://assets/audio/music/"
## Web export serves BGM as same-origin static files (not packed in the PCK).
## Root-relative so HTTPRequest resolves correctly from any page URL.
const WEB_MUSIC_URL_PREFIX := "/audio/"
const WEB_MUSIC_BASENAMES := [
	"dusk",
	"early-riser",
	"final",
	"main-theme",
	"midday",
	"midnight",
	"night",
	"sunrise",
]
const PICKUP_PLINK_PATH := "res://assets/audio/sfx/pickup/throwing-a-coin-into-a-piggy-bank.mp3"
const CUELUME_DIR := "res://assets/audio/sfx/ui/cuelume/"
## Cuelume recipes peak very soft; +24 dB ≈ 16× amplitude so UI cues read clearly over BGM.
const CUELUME_GAIN_DB := 24.0
const BGM_VOLUME_DB := -9.0
const MUSIC_EXTENSIONS := ["mp3", "ogg", "wav", "flac"]
## Prefer OGG when the same basename exists as WAV (desktop discovery).
const _MUSIC_EXT_PRIORITY := {"ogg": 4, "mp3": 3, "flac": 2, "wav": 1}

const CUELUME_STREAMS := {
	"perfect_chime": "cuelume-chime.wav",
	"ui_click": "cuelume-press.wav",
	"menu_open": "cuelume-bloom.wav",
	"menu_close": "cuelume-droplet.wav",
	"upgrade_bling": "cuelume-sparkle.wav",
	"bucket_full_chime": "cuelume-success.wav",
	"ui_toggle": "cuelume-toggle.wav",
	"pickup_miss": "cuelume-whisper.wav",
	"ui_tick": "cuelume-tick.wav",
	"ui_error": "cuelume-error.wav",
	"ui_page": "cuelume-page.wav",
	"play_loading": "cuelume-loading.wav",
	"harvest_ready": "cuelume-ready.wav",
}

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
var _ui_hover_tick = UiHoverTickScript.new()
## HTTP-loaded streams have empty resource_path; keep the logical track path here.
var _current_music_path: String = ""
var _pending_loop := false
var _web_bgm_fetcher: WebBgmFetcher


func _ready() -> void:
	_sfx_enabled = SaveManager.sfx_enabled
	_music_enabled = SaveManager.music_enabled
	_sfx_volume = SaveManager.sfx_volume
	_music_volume = SaveManager.music_volume
	_build_streams()
	_load_golf_hit_streams()
	_build_pool()
	if OS.has_feature("web"):
		_web_bgm_fetcher = WebBgmFetcher.new()
		_web_bgm_fetcher.name = "WebBgmFetcher"
		add_child(_web_bgm_fetcher)
		_web_bgm_fetcher.fetch_succeeded.connect(_on_web_bgm_fetch_succeeded)
		_web_bgm_fetcher.fetch_failed.connect(_on_web_bgm_fetch_failed)
	_refresh_music_tracks()
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.ui_panel_toggled.connect(_on_ui_panel_toggled)
	EventBus.helper_toggled.connect(_on_helper_toggled)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.ratina_upgrade_purchased.connect(_on_ratina_upgrade_purchased)
	EventBus.shop_item_purchased.connect(_on_shop_item_purchased)
	EventBus.rattling_upgrade_purchased.connect(_on_rattling_upgrade_purchased)
	EventBus.prestige_upgrade_purchased.connect(_on_prestige_upgrade_purchased)


func _process(_delta: float) -> void:
	if not _sfx_enabled:
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if _ui_hover_tick.poll(hovered):
		play_ui_tick()


func get_music_tracks() -> Array[String]:
	_refresh_music_tracks()
	return _music_tracks.duplicate()


func get_current_music_track_path() -> String:
	if not _current_music_path.is_empty():
		return _current_music_path
	if _music_player != null and _music_player.stream != null:
		return _music_player.stream.resource_path
	return ""


func get_current_music_display_name() -> String:
	if not _music_enabled:
		return "Music Off"
	if _ambient_player != null and _ambient_player.playing:
		return "Ambient Wind"
	var path := get_current_music_track_path()
	if path.is_empty():
		return "No Track"
	return MusicTrackRhythm.track_basename(path)


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing and not _music_player.stream_paused


func is_music_paused() -> bool:
	return _music_player != null and _music_player.playing and _music_player.stream_paused


func should_show_play_icon() -> bool:
	if not _music_enabled:
		return false
	if _music_player == null or _music_player.stream == null:
		return true
	return not _music_player.playing or _music_player.stream_paused


func stop_music() -> void:
	if _web_bgm_fetcher != null:
		_web_bgm_fetcher.cancel()
	_current_music_path = ""
	if _music_player != null:
		_music_player.stop()


func toggle_music_playback() -> void:
	if not _music_enabled:
		return
	_refresh_music_tracks()
	if _music_tracks.is_empty():
		return
	if _music_player == null or _music_player.stream == null:
		_is_title_mode = false
		if _rotation_index < 0 or _rotation_index >= _music_tracks.size():
			_rotation_index = 0
		_play_track_at_path(_music_tracks[_rotation_index], false)
		return
	if _music_player.playing and not _music_player.stream_paused:
		_music_player.stream_paused = true
	elif _music_player.playing and _music_player.stream_paused:
		_music_player.stream_paused = false
	else:
		_music_player.stream_paused = false
		_music_player.play()


func skip_music_track() -> void:
	if not _music_enabled:
		return
	_refresh_music_tracks()
	if _music_tracks.is_empty():
		return
	_is_title_mode = false
	_rotation_index = (_rotation_index + 1) % _music_tracks.size()
	_play_track_at_path(_music_tracks[_rotation_index], false)


func previous_music_track() -> void:
	if not _music_enabled:
		return
	_refresh_music_tracks()
	if _music_tracks.is_empty():
		return
	_is_title_mode = false
	_rotation_index = (_rotation_index - 1 + _music_tracks.size()) % _music_tracks.size()
	_play_track_at_path(_music_tracks[_rotation_index], false)


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
		# Re-assert play after a user gesture (web autoplay unlock).
		if OS.has_feature("web") and _music_player.stream != null and not _music_player.playing:
			_music_player.stream_paused = false
			_music_player.play()
		return
	_refresh_music_tracks()
	if _music_tracks.is_empty():
		if _music_player == null:
			_start_ambient()
		return
	# Title track already playing — finish this track, then rotate through the playlist.
	if _music_player != null and _is_title_mode and _music_player.stream != null:
		_is_title_mode = false
		_set_stream_loop(_music_player.stream, false)
		if not _music_player.finished.is_connected(_on_music_finished):
			_music_player.finished.connect(_on_music_finished)
		_music_player.stream_paused = false
		_music_player.play()
		return
	_is_title_mode = false
	if _music_player != null and _music_player.finished.is_connected(_on_music_finished):
		_music_player.finished.disconnect(_on_music_finished)
	_rotation_index = _random_track_index()
	_start_rotation_at(_rotation_index)


func play_start() -> void:
	_play("play_whoosh", -8.0, 0.95)
	_play("play_loading", -4.0)


func play_pickup_plink(combo_tier: int) -> void:
	var pitch := 1.0 + 0.08 * float(maxi(combo_tier, 1) - 1)
	_play("pickup_plink", -6.0, pitch)


func play_pickup_miss() -> void:
	_play("pickup_miss", -10.0)


func play_ui_toggle() -> void:
	_play("ui_toggle", -8.0)


func play_ui_tick() -> void:
	_play("ui_tick", -10.0)


func play_ui_error() -> void:
	_play("ui_error", -6.0)


func play_ui_page() -> void:
	_play("ui_page", -8.0)


func play_ratina_hit(timing_tier: int) -> void:
	_play_golf_hit(timing_tier, Balance.FeedbackTier.WHISPER)


func play_bucket_full_chime() -> void:
	_play("bucket_full_chime", -4.0)


func play_prestige_fanfare() -> void:
	_play("play_loading", -4.0)
	_play("upgrade_bling")


func play_upgrade_bling() -> void:
	_play_upgrade_bling(1)


func _refresh_music_tracks() -> void:
	_music_tracks = _discover_music_tracks()


func _discover_music_tracks() -> Array[String]:
	if OS.has_feature("web"):
		return _discover_web_music_tracks()
	return _discover_packed_music_tracks()


func _discover_web_music_tracks() -> Array[String]:
	var tracks: Array[String] = []
	for basename in WEB_MUSIC_BASENAMES:
		tracks.append("%s%s.ogg" % [WEB_MUSIC_URL_PREFIX, basename])
	return tracks


func _discover_packed_music_tracks() -> Array[String]:
	var by_basename: Dictionary = {}
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return []
	for file_name in dir.get_files():
		var ext := file_name.get_extension().to_lower()
		if ext not in MUSIC_EXTENSIONS:
			continue
		# Skip Godot remaps / imports that appear as files in some exports.
		if file_name.ends_with(".import"):
			continue
		var basename := file_name.get_basename()
		var path := MUSIC_DIR.path_join(file_name)
		if not by_basename.has(basename):
			by_basename[basename] = path
			continue
		var existing: String = by_basename[basename]
		var existing_ext := existing.get_extension().to_lower()
		if int(_MUSIC_EXT_PRIORITY.get(ext, 0)) > int(_MUSIC_EXT_PRIORITY.get(existing_ext, 0)):
			by_basename[basename] = path
	var candidates: Array[String] = []
	for basename in by_basename.keys():
		candidates.append(by_basename[basename])
	candidates.sort()
	return candidates


func _random_track_index() -> int:
	return randi() % _music_tracks.size()


func _start_rotation_at(index: int) -> void:
	_rotation_index = index
	_play_track_at_path(_music_tracks[_rotation_index], false)


func _play_track_at_path(path: String, loop: bool) -> void:
	_pending_loop = loop
	if OS.has_feature("web"):
		_play_web_track_at_path(path, loop)
		return
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("SfxManager: failed to load BGM at %s" % path)
		if _music_player == null and not _is_title_mode:
			_start_ambient()
		return
	_apply_music_stream(path, stream, loop)


func _play_web_track_at_path(path: String, loop: bool) -> void:
	if _web_bgm_fetcher == null:
		push_warning("SfxManager: web BGM fetcher missing")
		return
	_pending_loop = loop
	_web_bgm_fetcher.request_track(path)


func _on_web_bgm_fetch_succeeded(path: String, stream: AudioStreamOggVorbis) -> void:
	_apply_music_stream(path, stream, _pending_loop)


func _on_web_bgm_fetch_failed(path: String, message: String) -> void:
	push_warning("SfxManager: web BGM fetch failed for %s (%s)" % [path, message])
	if _music_player == null and not _is_title_mode:
		_start_ambient()


func _apply_music_stream(path: String, stream: AudioStream, loop: bool) -> void:
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
	_current_music_path = path
	if not loop:
		_music_player.finished.connect(_on_music_finished)
	_apply_music_volume()
	_music_player.stream_paused = false
	_music_player.play()
	music_track_changed.emit(path)


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
	var db := volume_db
	if CUELUME_STREAMS.has(stream_key):
		db += CUELUME_GAIN_DB
	_play_stream(_streams[stream_key], db, pitch_scale)


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
		# Soft confirmation over the hit — quieter than other Cuelume UI cues.
		_play("perfect_chime", -16.0, 1.0)

	if payout >= 25.0:
		var cash_pitch := clampf(1.0 + log(maxf(payout, 1.0)) / log(500.0) * 0.35, 1.0, 1.45)
		_play("cash_register", -4.0, cash_pitch)


func _on_ui_panel_toggled(panel_id: String, is_open: bool) -> void:
	if panel_id == "upgrades" or panel_id == "settings":
		if is_open:
			_play("menu_open", -6.0)
		else:
			_play("menu_close", -7.0)
		return
	_play("ui_click", -8.0)


func _on_helper_toggled(_helper: String, _active: bool) -> void:
	play_ui_toggle()


func _on_phase_changed(phase: String) -> void:
	if phase == "harvest":
		_play("harvest_ready", -6.0)


func _on_upgrade_purchased(_id: String, level: int, _branch: int) -> void:
	_play_upgrade_bling(level)


func _on_ratina_upgrade_purchased(_id: String, level: int) -> void:
	_play_upgrade_bling(level)


func _on_shop_item_purchased(_id: String, level: int) -> void:
	_play_upgrade_bling(level)


func _on_rattling_upgrade_purchased(_id: String, level: int) -> void:
	_play_upgrade_bling(level)


func _on_prestige_upgrade_purchased(_id: String, level: int) -> void:
	_play_upgrade_bling(level)


func _play_upgrade_bling(_level: int) -> void:
	_play("upgrade_bling")


func _build_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = &"Master"
		add_child(player)
		_pool.append(player)


func _build_streams() -> void:
	for stream_key in CUELUME_STREAMS:
		var file_name: String = CUELUME_STREAMS[stream_key]
		_streams[stream_key] = _load_cuelume_stream(file_name, stream_key)
	# Keep charge feedback procedural — do not use Cuelume release here.
	_streams["charge_start"] = _make_click(620.0, 0.05, 0.32)
	_streams["cash_register"] = _make_chime([660.0, 880.0, 1108.0, 1320.0], 0.18, 0.32)
	_streams["play_whoosh"] = _make_thwack(150.0, 0.14, 0.2, 0.5)
	_streams["pickup_plink"] = _load_pickup_plink_stream()
	_streams["ambient_wind"] = _make_wind_loop(2.5, 0.06)


func _load_cuelume_stream(file_name: String, stream_key: String) -> AudioStream:
	var path := CUELUME_DIR.path_join(file_name)
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("SfxManager: failed to load Cuelume cue at %s" % path)
		return _cuelume_fallback(stream_key)
	return stream


func _cuelume_fallback(stream_key: String) -> AudioStream:
	match stream_key:
		"upgrade_bling":
			return _make_coin_bling(0.14, 0.72)
		"perfect_chime", "bucket_full_chime", "play_loading", "harvest_ready":
			return _make_chime([880.0, 1175.0, 1568.0], 0.18, 0.28)
		"menu_open":
			return _make_arpeggio([523.0, 659.0, 784.0, 988.0], 0.045, 0.3)
		"menu_close":
			return _make_arpeggio([880.0, 698.0, 554.0, 440.0], 0.04, 0.24)
		_:
			return _make_click(980.0, 0.035, 0.28)


func _load_pickup_plink_stream() -> AudioStream:
	var stream: AudioStream = load(PICKUP_PLINK_PATH)
	if stream == null:
		push_warning("SfxManager: failed to load pickup plink at %s" % PICKUP_PLINK_PATH)
		return _make_chime([880.0, 1175.0, 1568.0], 0.12, 0.28)
	return stream


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
	if _golf_hit_normal.is_empty() or _golf_hit_power.is_empty():
		push_warning(
			"SfxManager: golf hit pools empty (normal=%d power=%d) — SFX WAVs missing from export?"
			% [_golf_hit_normal.size(), _golf_hit_power.size()]
		)


func _sfx_mix_rate() -> int:
	## Prefer the live AudioServer rate so procedural WAVs need no resampling on web.
	var rate := int(AudioServer.get_mix_rate())
	if rate < 11025:
		return 44100
	return rate


func _make_click(freq_hz: float, duration_sec: float, volume: float) -> AudioStreamWAV:
	var mix_rate := _sfx_mix_rate()
	var sample_count := int(duration_sec * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(mix_rate)
		var env := exp(-18.0 * t / duration_sec)
		var sample := sin(TAU * freq_hz * t) * volume * env
		_write_sample(data, i, sample)
	return _pack_wav(data, mix_rate)


func _make_coin_bling(duration_sec: float, volume: float) -> AudioStreamWAV:
	## Fallback if Mixkit asset missing — punchy click + rising sparkle.
	var mix_rate := _sfx_mix_rate()
	var sample_count := int(duration_sec * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var harmonics: Array = [988.0, 1319.0, 1760.0, 2093.0]
	for i in sample_count:
		var t := float(i) / float(mix_rate)
		var click_env := exp(-70.0 * t)
		var click := rng.randf_range(-1.0, 1.0) * 0.55 * click_env
		var tone_env := exp(-9.0 * t / duration_sec)
		var tone := 0.0
		for hi in harmonics.size():
			var freq := float(harmonics[hi])
			var weight := 1.0 - float(hi) * 0.12
			tone += sin(TAU * freq * t) * weight
		tone = tone / float(harmonics.size()) * tone_env
		# Soft upward chirp for "level up" feel.
		var chirp := sin(TAU * (1200.0 + 1800.0 * t / duration_sec) * t) * exp(-12.0 * t / duration_sec) * 0.35
		var sample := (click * 0.35 + tone * 0.45 + chirp * 0.35) * volume
		_write_sample(data, i, sample)
	return _pack_wav(data, mix_rate)


func _make_thwack(
	tone_hz: float,
	duration_sec: float,
	volume: float,
	noise_mix: float
) -> AudioStreamWAV:
	var mix_rate := _sfx_mix_rate()
	var sample_count := int(duration_sec * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tone_hz * 1000.0)
	for i in sample_count:
		var t := float(i) / float(mix_rate)
		var env := exp(-5.5 * t / duration_sec)
		var tone := sin(TAU * tone_hz * t) * (1.0 - noise_mix)
		var noise := rng.randf_range(-1.0, 1.0) * noise_mix
		var sample := (tone + noise) * volume * env
		_write_sample(data, i, sample)
	return _pack_wav(data, mix_rate)


func _make_arpeggio(freqs: Array, note_duration_sec: float, volume: float) -> AudioStreamWAV:
	var mix_rate := _sfx_mix_rate()
	var total_duration := note_duration_sec * freqs.size()
	var sample_count := int(total_duration * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(mix_rate)
		var note_index := mini(int(t / note_duration_sec), freqs.size() - 1)
		var note_t := fmod(t, note_duration_sec)
		var freq := float(freqs[note_index])
		var env := exp(-8.0 * note_t / note_duration_sec)
		var sample := sin(TAU * freq * note_t) * volume * env
		_write_sample(data, i, sample)
	return _pack_wav(data, mix_rate)


func _make_chime(freqs: Array, duration_sec: float, volume: float) -> AudioStreamWAV:
	var mix_rate := _sfx_mix_rate()
	var sample_count := int(duration_sec * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(mix_rate)
		var env := exp(-3.5 * t / duration_sec)
		var sample := 0.0
		for freq in freqs:
			sample += sin(TAU * float(freq) * t)
		sample = sample / float(freqs.size()) * volume * env
		_write_sample(data, i, sample)
	return _pack_wav(data, mix_rate)


func _make_wind_loop(duration_sec: float, volume: float) -> AudioStreamWAV:
	var mix_rate := _sfx_mix_rate()
	var sample_count := int(duration_sec * mix_rate)
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
	var stream := _pack_wav(data, mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _write_sample(data: PackedByteArray, index: int, sample: float) -> void:
	var int_sample := int(clampf(sample, -1.0, 1.0) * 32767.0)
	data[index * 2] = int_sample & 0xFF
	data[index * 2 + 1] = (int_sample >> 8) & 0xFF


func _pack_wav(data: PackedByteArray, mix_rate: int = 44100) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
