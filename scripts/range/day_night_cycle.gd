extends Node
## Automatic day/night cycle for the driving range — pauses when RangeView is hidden.

var _phase_is_day := true
var _elapsed := 0.0


func _process(delta: float) -> void:
	var range_view := get_parent()
	if range_view == null or not range_view.visible:
		return

	_elapsed += delta
	var phase_duration := DayNightPalette.DAY_SEC if _phase_is_day else DayNightPalette.NIGHT_SEC
	if _elapsed >= phase_duration:
		_elapsed -= phase_duration
		_phase_is_day = not _phase_is_day

	var night_blend := DayNightPalette.compute_night_blend(_phase_is_day, _elapsed)
	if range_view.has_method(&"apply_atmosphere"):
		range_view.apply_atmosphere(night_blend)


func reset_to_day() -> void:
	_phase_is_day = true
	_elapsed = 0.0
	var range_view := get_parent()
	if range_view != null and range_view.has_method(&"apply_atmosphere"):
		range_view.apply_atmosphere(0.0)


func phase_is_day() -> bool:
	return _phase_is_day


func elapsed_in_phase() -> float:
	return _elapsed
