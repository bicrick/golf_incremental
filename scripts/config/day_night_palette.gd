class_name DayNightPalette
extends RefCounted
## Day/night color tables for the driving range atmosphere.

const DAY_SEC := 60.0
const NIGHT_SEC := 30.0
const TRANSITION_SEC := 3.0

const SKY_DAY := Color(0.55, 0.75, 0.92, 1.0)
const SKY_NIGHT := Color(0.10, 0.14, 0.32, 1.0)

const HILLS_DAY := Color(0.35, 0.55, 0.38, 1.0)
const HILLS_NIGHT := Color(0.18, 0.28, 0.22, 1.0)

const FAIRWAY_BASE_DAY := Color(0.40, 0.58, 0.32, 1.0)
const FAIRWAY_LIGHT_DAY := Color(0.54, 0.76, 0.44, 1.0)
const FAIRWAY_DARK_DAY := Color(0.36, 0.52, 0.28, 1.0)
const FAIRWAY_BASE_NIGHT := Color(0.26, 0.38, 0.30, 1.0)
const FAIRWAY_LIGHT_NIGHT := Color(0.35, 0.50, 0.38, 1.0)
const FAIRWAY_DARK_NIGHT := Color(0.23, 0.34, 0.26, 1.0)

const MAT_BORDER_DAY := Color(0.08, 0.18, 0.08, 1.0)
const MAT_FILL_DAY := Color(0.15, 0.38, 0.15, 1.0)
const MAT_HIGHLIGHT_DAY := Color(0.28, 0.55, 0.28, 1.0)
const MAT_BORDER_NIGHT := Color(0.05, 0.11, 0.07, 1.0)
const MAT_FILL_NIGHT := Color(0.09, 0.23, 0.12, 1.0)
const MAT_HIGHLIGHT_NIGHT := Color(0.17, 0.33, 0.20, 1.0)

const CANVAS_MODULATE_DAY := Color(1.0, 1.0, 1.0, 1.0)
const CANVAS_MODULATE_NIGHT := Color(0.58, 0.62, 0.78, 1.0)

const SUN_COLOR := Color(1.0, 0.92, 0.55, 1.0)
const MOON_COLOR := Color(0.85, 0.88, 0.95, 1.0)


static func lerp_color(day: Color, night: Color, night_blend: float) -> Color:
	return day.lerp(night, clampf(night_blend, 0.0, 1.0))


static func compute_night_blend(phase_is_day: bool, elapsed_in_phase: float) -> float:
	var steady_end := (DAY_SEC if phase_is_day else NIGHT_SEC) - TRANSITION_SEC
	if elapsed_in_phase < steady_end:
		return 0.0 if phase_is_day else 1.0
	var t := (elapsed_in_phase - steady_end) / TRANSITION_SEC
	t = clampf(t, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	if phase_is_day:
		return t
	return 1.0 - t
