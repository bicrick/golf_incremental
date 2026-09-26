extends Node
## v8 audio (autoload `Audio`): music, sound effects and ambience.
##
## Music: each range has its own songs (set_playlist); the title plays the main
## theme. On desktop tracks load from assets/audio/music; on the web build they
## stream from /audio/*.ogg next to the page (see tools/export_web.sh).
## Settings (volumes, on/off) live in user://settings.json.

const WebAudioUnlock := preload("res://scripts/tour/audio/web_audio_unlock.gd")
const WebBgmFetcherScript := preload("res://scripts/tour/audio/web_bgm_fetcher.gd")

const MUSIC_DIR := "res://assets/audio/music/"
const WEB_MUSIC_PREFIX := "/audio/"
const SETTINGS_PATH := "user://settings.json"
const BGM_DB := -9.0
const POOL_SIZE := 10
const GOLF_DIR := "res://assets/audio/sfx/golf/"
const HITS_SOFT := ["mixkit-golf-ball-hit-2105.wav", "mixkit-quick-golf-hit-2121.wav",
	"mixkit-quick-shot-golf-2125.wav", "mixkit-short-golf-shot-2127.wav"]
const HITS_PURE := ["mixkit-golf-ball-hard-hit-2120.wav", "mixkit-hard-golf-swing-2119.wav",
	"mixkit-powerful-golf-shot-2126.wav", "mixkit-sharp-golf-hit-2122.wav", "mixkit-golf-metal-shot-2123.wav"]
const CUE_DIR := "res://assets/audio/sfx/ui/cuelume/"
const CUE_GAIN_DB := 24.0
const CUES := {"ui_tick": "cuelume-tick.wav", "ui_error": "cuelume-error.wav", "page": "cuelume-page.wav",
	"buy": "cuelume-sparkle.wav", "perfect": "cuelume-chime.wav", "open": "cuelume-bloom.wav"}
const PLINK_PATH := "res://assets/audio/sfx/pickup/throwing-a-coin-into-a-piggy-bank.mp3"

var music_volume := 1.0
var sfx_volume := 1.0

var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _streams := {}
var _hits_soft: Array[AudioStream] = []
var _hits_pure: Array[AudioStream] = []
var _music: AudioStreamPlayer
var _playlist: Array = []
var _playlist_pos := 0
var _current := ""
var _fade: Tween
var _fetcher: Node
var _pending := ""
var _amb: AudioStreamPlayer
var _amb_kind := ""
var _amb_cache := {}
var _amb_db := 0.0
## Music-reactive style: smoothed loudness of the song (0..1) and a beat
## pulse that jumps on kicks and decays. Nothing in the gameplay reads these;
## the world just moves with the music.
var energy := 0.0
var pulse := 0.0
var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _bass_avg := 0.0
signal song_started(name: String)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = _music_bus()
	add_child(_music)
	_music.finished.connect(_on_music_finished)
	_amb = AudioStreamPlayer.new()
	add_child(_amb)
	for f in HITS_SOFT:
		_hits_soft.append(load(GOLF_DIR + f))
	for f in HITS_PURE:
		_hits_pure.append(load(GOLF_DIR + f))
	for k in CUES:
		_streams[k] = load(CUE_DIR + CUES[k])
	_streams["plink"] = load(PLINK_PATH)
	_streams["type"] = _typewriter()
	_streams["land"] = _thwack(110.0, 0.12, 0.35, 0.55)
	_streams["green"] = _arpeggio([784.0, 988.0, 1175.0], 0.09, 0.32)
	_streams["star"] = _arpeggio([659.0, 784.0, 988.0, 1319.0, 1568.0], 0.08, 0.34)
	_streams["ace"] = _arpeggio([523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0, 2093.0], 0.07, 0.38)
	_streams["splash"] = _splash()
	_streams["lost"] = _thwack(70.0, 0.35, 0.3, 0.8)
	_streams["keepsake"] = _chime([880.0, 1320.0, 1760.0], 1.0, 0.3)
	_streams["sweep_start"] = _thwack(220.0, 0.18, 0.25, 0.3)
	_streams["flag"] = _chime([523.0, 659.0, 784.0, 1047.0], 2.2, 0.34)
	_streams["travel"] = _arpeggio([392.0, 523.0, 659.0, 784.0], 0.14, 0.3)
	_streams["lantern"] = _chime([440.0, 660.0, 990.0], 1.4, 0.3)
	if OS.has_feature("web"):
		WebAudioUnlock.install()
		_fetcher = WebBgmFetcherScript.new()
		add_child(_fetcher)
		_fetcher.fetch_succeeded.connect(func(path: String, stream: AudioStream) -> void:
			if path == _pending:
				_start_stream(path, stream)
		)


func _music_bus() -> StringName:
	var idx := AudioServer.get_bus_index(&"Music")
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, &"Music")
		AudioServer.set_bus_send(idx, &"Master")
		var spec := AudioEffectSpectrumAnalyzer.new()
		spec.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		AudioServer.add_bus_effect(idx, spec)
	_analyzer = AudioServer.get_bus_effect_instance(idx, 0) as AudioEffectSpectrumAnalyzerInstance
	return &"Music"


func _process(delta: float) -> void:
	if _analyzer == null or not _music.playing:
		energy = move_toward(energy, 0.0, delta)
		pulse = move_toward(pulse, 0.0, delta * 3.0)
		return
	var full := _analyzer.get_magnitude_for_frequency_range(40.0, 4000.0).length()
	var bass := _analyzer.get_magnitude_for_frequency_range(40.0, 160.0).length()
	var e := clampf((linear_to_db(maxf(full, 0.00001)) + 42.0) / 32.0, 0.0, 1.0)
	energy = lerpf(energy, e, clampf(delta * 4.0, 0.0, 1.0))
	## A kick is bass well above its running average.
	if bass > _bass_avg * 1.45 and bass > 0.004:
		pulse = 1.0
	_bass_avg = lerpf(_bass_avg, bass, clampf(delta * 2.0, 0.0, 1.0))
	pulse = maxf(pulse - delta * 3.2, 0.0)


func _input(event: InputEvent) -> void:
	if OS.has_feature("web") and WebAudioUnlock.is_unlock_gesture(event):
		WebAudioUnlock.resume()
		if _music.stream != null and not _music.playing and music_volume > 0.0:
			_music.play()


# --- settings -------------------------------------------------------------------

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_music.volume_db = _music_db()
	_amb.volume_db = _sfx_db(_amb_db)
	_save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_amb.volume_db = _sfx_db(_amb_db)
	_save_settings()


func _music_db() -> float:
	return BGM_DB + linear_to_db(maxf(music_volume, 0.0001))


func _sfx_db(base: float) -> float:
	return base + linear_to_db(maxf(sfx_volume, 0.0001))


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary:
		music_volume = float(d.get("music", 1.0))
		sfx_volume = float(d.get("sfx", 1.0))


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"music": music_volume, "sfx": sfx_volume}))


# --- music ------------------------------------------------------------------------

## Loop through these songs until told otherwise. Fades out whatever is playing
## unless it's already one of them.
func set_playlist(names: Array, fade_sec: float = 1.2) -> void:
	_playlist = names.duplicate()
	_playlist_pos = 0
	if names.is_empty():
		return
	if names.has(_current) and _music.playing:
		_playlist_pos = names.find(_current)
		return
	if not _music.playing:
		_play_named(String(names[0]))
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", -40.0, fade_sec)
	_fade.tween_callback(func() -> void: _play_named(String(_playlist[0])))


func current_song() -> String:
	return _current


const SONG_TITLES := {
	"main-theme": "Range Rat", "sunrise": "Sunrise", "early-riser": "Early Riser",
	"midday": "Midday", "dusk": "Dusk", "night": "Night", "midnight": "Midnight", "final": "Final",
}


static func song_title(name: String) -> String:
	return SONG_TITLES.get(name, name.capitalize())


func _play_named(name: String) -> void:
	_current = name
	song_started.emit(name)
	if OS.has_feature("web"):
		_pending = WEB_MUSIC_PREFIX + name + ".ogg"
		_fetcher.request_track(_pending)
		return
	var path := MUSIC_DIR + name + ".ogg"
	if not ResourceLoader.exists(path):
		path = MUSIC_DIR + name + ".wav"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream != null:
		_start_stream(path, stream)


func _start_stream(_path: String, stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_music.stream = stream
	_music.volume_db = _music_db()
	_music.play()


func _on_music_finished() -> void:
	if _playlist.is_empty():
		return
	_playlist_pos = (_playlist_pos + 1) % _playlist.size()
	_play_named(String(_playlist[_playlist_pos]))


# --- sound effects ------------------------------------------------------------------

func play(kind: String, pitch: float = 1.0) -> void:
	var s: AudioStream = _streams.get(kind)
	if s == null:
		return
	var db := _base_db(kind)
	if CUES.has(kind):
		db += CUE_GAIN_DB
	_play_stream(s, db, pitch)


func play_hit(tier: int) -> void:
	var pool := _hits_pure if tier == 0 else _hits_soft
	if pool.is_empty():
		return
	var db: float = [-1.0, -2.5, -3.0, -4.0, -4.5, -5.0][clampi(tier, 0, 5)]
	_play_stream(pool[randi() % pool.size()], db, randf_range(0.97, 1.03))
	if tier == 0:
		_play_stream(_streams["perfect"], -16.0 + CUE_GAIN_DB, 1.0)


func play_plink(chain: int) -> void:
	_play_stream(_streams["plink"], -6.0, 1.0 + 0.08 * float(maxi(chain, 1) - 1))


func play_type() -> void:
	play("type", randf_range(0.9, 1.15))


func _base_db(kind: String) -> float:
	match kind:
		"land":
			return -12.0
		"type":
			return -14.0
		"ui_tick", "page":
			return -8.0
		"green", "star":
			return -5.0
	return -4.0


func _play_stream(s: AudioStream, db: float, pitch: float) -> void:
	if s == null or sfx_volume <= 0.0:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = _sfx_db(db)
	p.pitch_scale = pitch
	p.play()


# --- ambience -------------------------------------------------------------------------

## Quiet looping bed under the music: dawn birds, waves, desert wind, night air.
func set_ambience(range_id: String) -> void:
	var kind: String = {"barley": "birds", "cliffs": "waves", "mesa": "wind", "frost": "wind_soft", "edge": "air"}.get(range_id, "")
	if kind == _amb_kind:
		return
	_amb_kind = kind
	if kind == "":
		_amb.stop()
		return
	if not _amb_cache.has(kind):
		_amb_cache[kind] = _ambience(kind)
	_amb.stream = _amb_cache[kind]
	_amb_db = float({"birds": -20.0, "waves": -15.0, "wind": -18.0, "wind_soft": -22.0, "air": -21.0}[kind])
	_amb.volume_db = _sfx_db(_amb_db)
	_amb.play()


# --- synthesis --------------------------------------------------------------------------

func _rate() -> int:
	var r := int(AudioServer.get_mix_rate())
	return r if r >= 11025 else 44100


func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s


func _write(data: PackedByteArray, i: int, v: float) -> void:
	var x := int(clampf(v, -1.0, 1.0) * 32767.0)
	data[i * 2] = x & 0xFF
	data[i * 2 + 1] = (x >> 8) & 0xFF


func _render(dur: float, fn: Callable) -> AudioStreamWAV:
	var rate := _rate()
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		_write(data, i, fn.call(float(i) / rate))
	return _wav(data, rate)


func _thwack(hz: float, dur: float, vol: float, noise: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hz * 1000.0)
	return _render(dur, func(t: float) -> float:
		return (sin(TAU * hz * t) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise) * vol * exp(-5.5 * t / dur))


func _arpeggio(freqs: Array, note: float, vol: float) -> AudioStreamWAV:
	return _render(note * freqs.size(), func(t: float) -> float:
		var i := mini(int(t / note), freqs.size() - 1)
		var nt := fmod(t, note)
		return sin(TAU * float(freqs[i]) * nt) * vol * exp(-8.0 * nt / note))


func _chime(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	return _render(dur, func(t: float) -> float:
		var v := 0.0
		for f in freqs:
			v += sin(TAU * float(f) * t)
		return v / freqs.size() * vol * exp(-3.5 * t / dur))


func _typewriter() -> AudioStreamWAV:
	return _render(0.04, func(t: float) -> float:
		return (sin(TAU * 1450.0 * t) * 0.34 + sin(TAU * 2200.0 * t) * 0.16) * exp(-42.0 * t / 0.04))


func _splash() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var lp := [0.0]
	return _render(0.45, func(t: float) -> float:
		lp[0] = lerpf(lp[0], rng.randf_range(-1.0, 1.0), 0.25 + 0.2 * sin(t * 40.0))
		var bloop := sin(TAU * (300.0 - 200.0 * t) * t) * exp(-12.0 * t) * 0.4
		return (lp[0] * 0.6 + bloop) * exp(-7.0 * t) * minf(t * 60.0, 1.0) * 0.5)


func _ambience(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var dur := 8.0
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var lp := 0.0
	var lp2 := 0.0
	var chirps: Array = []
	if kind == "birds":
		for i in 7:
			chirps.append([rng.randf_range(0.0, dur - 0.5), rng.randf_range(2400.0, 4200.0), rng.randi_range(2, 5)])
	for i in n:
		var t := float(i) / rate
		var ph := t / dur * TAU ## every swell is a whole cycle, so it loops cleanly
		var white := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		match kind:
			"waves":
				lp = lerpf(lp, white, 0.05)
				lp2 = lerpf(lp2, white, 0.3)
				var swell := 0.35 + 0.65 * pow(0.5 + 0.5 * sin(ph * 2.0), 3.0)
				v = (lp * 1.6 + lp2 * 0.25 * swell) * swell
			"wind", "wind_soft", "air":
				lp = lerpf(lp, white, 0.02 + 0.03 * (0.5 + 0.5 * sin(ph * 3.0)))
				v = lp * (2.2 if kind != "air" else 1.6) * (0.6 + 0.4 * sin(ph + 1.0))
			"birds":
				lp = lerpf(lp, white, 0.01)
				v = lp * 0.4
				for c in chirps:
					var ct := t - float(c[0])
					if ct > 0.0 and ct < 0.09 * int(c[2]):
						var k := fmod(ct, 0.09) / 0.09
						v += sin(TAU * float(c[1]) * (1.0 + 0.25 * k) * ct) * sin(PI * k) * 0.35
		_write(data, i, v * 0.6)
	var w := _wav(data, rate)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
