class_name MusicTrackRhythm
extends RefCounted
## Per-track tempo hints for music-synced backdrop sway.
## Tune `bpm` / `offset_sec` here if a track drifts; live onset detection also refines timing.
## Tracks are timing-named for future day/night wiring; playlist rotation only for now.

const DEFAULT_BPM := 112.0
const DEFAULT_OFFSET_SEC := 0.0

const _TRACKS: Dictionary = {
	"res://assets/audio/music/dusk.wav": {"bpm": 120.0, "offset_sec": 0.0},
	"res://assets/audio/music/early-riser.wav": {"bpm": 112.0, "offset_sec": 0.0},
	"res://assets/audio/music/final.wav": {"bpm": 112.0, "offset_sec": 0.0},
	"res://assets/audio/music/main-theme.wav": {"bpm": 118.0, "offset_sec": 0.0},
	"res://assets/audio/music/midday.wav": {"bpm": 112.0, "offset_sec": 0.0},
	"res://assets/audio/music/midnight.wav": {"bpm": 112.0, "offset_sec": 0.0},
	"res://assets/audio/music/night.wav": {"bpm": 92.0, "offset_sec": 0.0},
	"res://assets/audio/music/sunrise.wav": {"bpm": 108.0, "offset_sec": 0.0},
}


static func get_bpm(track_path: String) -> float:
	var entry: Variant = _TRACKS.get(track_path)
	if entry is Dictionary and entry.has("bpm"):
		return float(entry["bpm"])
	return DEFAULT_BPM


static func get_offset_sec(track_path: String) -> float:
	var entry: Variant = _TRACKS.get(track_path)
	if entry is Dictionary and entry.has("offset_sec"):
		return float(entry["offset_sec"])
	return DEFAULT_OFFSET_SEC


static func beat_duration_sec(track_path: String) -> float:
	return 60.0 / maxf(get_bpm(track_path), 1.0)
