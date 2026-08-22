class_name MusicPlaylist
extends RefCounted
## Canonical BGM order: opening theme first, then daytime cycle. No shuffle.

const OPENING_THEME := "main-theme"
const _UNKNOWN_ORDER := 1000

const DAYTIME_SEQUENCE := [
	"sunrise",
	"early-riser",
	"midday",
	"dusk",
	"night",
	"midnight",
	"final",
]


static func ordered_basenames() -> PackedStringArray:
	var names := PackedStringArray()
	names.append(OPENING_THEME)
	for name in DAYTIME_SEQUENCE:
		names.append(name)
	return names


static func order_index(basename: String) -> int:
	if basename == OPENING_THEME:
		return 0
	var daytime_i := DAYTIME_SEQUENCE.find(basename)
	if daytime_i >= 0:
		return daytime_i + 1
	return _UNKNOWN_ORDER


static func sort_discovered(paths: Array[String]) -> Array[String]:
	var sorted := paths.duplicate()
	sorted.sort_custom(_path_less_than)
	return sorted


static func opening_index(paths: Array[String]) -> int:
	for i in paths.size():
		if MusicTrackRhythm.track_basename(paths[i]) == OPENING_THEME:
			return i
	return 0


static func next_index(paths: Array[String], current_index: int) -> int:
	return _step_index(paths, current_index, 1)


static func previous_index(paths: Array[String], current_index: int) -> int:
	return _step_index(paths, current_index, -1)


static func _step_index(paths: Array[String], current_index: int, step: int) -> int:
	var size := paths.size()
	if size <= 0:
		return 0
	if size == 1:
		return 0
	var from := posmod(current_index, size)
	var next_i := posmod(from + step, size)
	var current_name := MusicTrackRhythm.track_basename(paths[from])
	if MusicTrackRhythm.track_basename(paths[next_i]) == current_name:
		return posmod(next_i + step, size)
	return next_i


static func _path_less_than(a: String, b: String) -> bool:
	var a_name := MusicTrackRhythm.track_basename(a)
	var b_name := MusicTrackRhythm.track_basename(b)
	var a_i := order_index(a_name)
	var b_i := order_index(b_name)
	if a_i != b_i:
		return a_i < b_i
	return a_name.naturalnocasecmp_to(b_name) < 0
