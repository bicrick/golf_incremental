extends Node
## Multi-phase day/night cycle — advances while RangeView or IsoView is active.

var _cycle_elapsed := 60.0


func _process(delta: float) -> void:
	var range_view := get_parent()
	if range_view == null:
		return
	var iso_view := get_tree().get_first_node_in_group(&"iso_view") as Node
	var range_active: bool = range_view.visible
	var iso_active: bool = iso_view != null and iso_view.visible
	if not range_active and not iso_active:
		return

	_cycle_elapsed += delta
	if range_view.has_method(&"apply_atmosphere"):
		range_view.apply_atmosphere(_cycle_elapsed)
	if iso_active and iso_view.has_method(&"apply_atmosphere"):
		iso_view.apply_atmosphere(_cycle_elapsed)


func set_cycle_elapsed(time: float) -> void:
	_cycle_elapsed = time


func reset_to_day() -> void:
	_cycle_elapsed = 60.0
	var range_view := get_parent()
	if range_view != null and range_view.has_method(&"apply_atmosphere"):
		range_view.apply_atmosphere(_cycle_elapsed)
	var iso_view := get_tree().get_first_node_in_group(&"iso_view") as Node
	if iso_view != null and iso_view.has_method(&"apply_atmosphere"):
		iso_view.apply_atmosphere(_cycle_elapsed)


func cycle_elapsed() -> float:
	return _cycle_elapsed
