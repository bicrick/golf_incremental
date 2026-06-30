extends Node
## Multi-phase day/night cycle — pauses when RangeView is hidden.

var _cycle_elapsed := 24.0


func _process(delta: float) -> void:
	var range_view := get_parent()
	if range_view == null or not range_view.visible:
		return

	_cycle_elapsed += delta
	if range_view.has_method(&"apply_atmosphere"):
		range_view.apply_atmosphere(_cycle_elapsed)


func set_cycle_elapsed(time: float) -> void:
	_cycle_elapsed = time


func reset_to_day() -> void:
	_cycle_elapsed = 24.0
	var range_view := get_parent()
	if range_view != null and range_view.has_method(&"apply_atmosphere"):
		range_view.apply_atmosphere(_cycle_elapsed)


func cycle_elapsed() -> float:
	return _cycle_elapsed
