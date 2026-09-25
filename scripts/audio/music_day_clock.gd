class_name MusicDayClock
extends RefCounted
## v5 — "the music is the clock". Each BGM track is named for a time of day;
## the sky follows the track that's playing. One pass through the playlist is
## one day on the range (~15 min) instead of a 2-minute spin.
##
## Cycle seconds (DayNightPalette.CYCLE_SEC = 120):
##   0 midnight · 30 dawn · 60 day · 90 dusk · 120 midnight

## basename → [cycle start, cycle end] swept across the track's length.
const TRACK_WINDOWS := {
	"main-theme": [58.0, 66.0],
	"sunrise": [24.0, 40.0],
	"early-riser": [40.0, 50.0],
	"midday": [50.0, 70.0],
	"dusk": [74.0, 94.0],
	"night": [96.0, 110.0],
	"midnight": [110.0, 126.0],
	"final": [6.0, 24.0],
}
## How fast the sky may catch up to a new track (cycle-seconds per real second).
const CATCH_UP_RATE := 5.0


## Target cycle time for a track at `fraction` (0..1) through it, or -1.
static func target_for(basename: String, fraction: float) -> float:
	if not TRACK_WINDOWS.has(basename):
		return -1.0
	var w: Array = TRACK_WINDOWS[basename]
	return lerpf(float(w[0]), float(w[1]), clampf(fraction, 0.0, 1.0))


## Step `current` toward `target` along the shortest way around the cycle.
static func approach(current: float, target: float, delta: float, cycle: float) -> float:
	var cur := fposmod(current, cycle)
	var diff := fposmod(target - cur + cycle * 0.5, cycle) - cycle * 0.5
	var step := clampf(diff, -CATCH_UP_RATE * delta, CATCH_UP_RATE * delta)
	## Never run the sun backwards by much — prefer waiting a beat.
	if diff < -2.0:
		step = 0.0
	return current + step


static func display_name(basename: String) -> String:
	match basename:
		"main-theme":
			return "Range Rat"
		"":
			return ""
	var words := basename.replace("_", "-").split("-")
	var out: PackedStringArray = []
	for w in words:
		out.append(w.capitalize())
	return " ".join(out)
