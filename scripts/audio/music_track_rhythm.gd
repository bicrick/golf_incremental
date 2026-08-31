class_name MusicTrackRhythm
extends RefCounted
## Per-track tempo hints for music-synced backdrop sway.
## Keys are track basenames (no extension) so .wav / .ogg / HTTP URLs all resolve.
## Tune `bpm` / `offset_sec` here if a track drifts; live onset detection also refines timing.
## Tracks are timing-named; play order lives in MusicPlaylist (opening theme, then daytime).

const DEFAULT_BPM := 112.0
const DEFAULT_OFFSET_SEC := 0.0

const _TRACKS: Dictionary = {
	"dusk": {"bpm": 120.0, "offset_sec": 0.0},
	"early-riser": {"bpm": 112.0, "offset_sec": 0.0},
	"final": {"bpm": 112.0, "offset_sec": 0.0},
	"main-theme": {"bpm": 118.0, "offset_sec": 0.0},
	"midday": {"bpm": 112.0, "offset_sec": 0.0},
	"midnight": {"bpm": 112.0, "offset_sec": 0.0},
	"night": {"bpm": 92.0, "offset_sec": 0.0},
	"sunrise": {"bpm": 108.0, "offset_sec": 0.0},
}


static func track_basename(track_path: String) -> String:
	if track_path.is_empty():
		return ""
	return track_path.get_file().get_basename()


static func get_bpm(track_path: String) -> float:
	var entry: Variant = _TRACKS.get(track_basename(track_path))
	if entry is Dictionary and entry.has("bpm"):
		return float(entry["bpm"])
	return DEFAULT_BPM


static func get_offset_sec(track_path: String) -> float:
	var entry: Variant = _TRACKS.get(track_basename(track_path))
	if entry is Dictionary and entry.has("offset_sec"):
		return float(entry["offset_sec"])
	return DEFAULT_OFFSET_SEC


static func beat_duration_sec(track_path: String) -> float:
	return 60.0 / maxf(get_bpm(track_path), 1.0)
