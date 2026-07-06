extends Node3D
## Painted range backdrop anchor. Drag this node in the 3D viewport to nudge the
## image left/right/up/down. The quad mesh rebuilds when PerspectiveCamera moves;
## this Transform is preserved across rebuilds. Subtle bottom-anchored side sway when BGM plays.

const SWAY_MAX_RAD := 0.004
## Local-space point near the painted treeline base — rotation pivots here so the top sways.
const PIVOT_LOCAL := Vector3(0.0, -14.0, 0.0)

var _base_transform := Transform3D.IDENTITY
var _base_captured := false


func _ready() -> void:
	_capture_base()


func apply_pulse_strength(sway_amount: float) -> void:
	if not _base_captured:
		_capture_base()
	if is_zero_approx(sway_amount):
		_apply_base()
		return

	var angle := sway_amount * SWAY_MAX_RAD
	var axis := _base_transform.basis.y.normalized()
	transform = _rotate_about_local_pivot(_base_transform, PIVOT_LOCAL, axis, angle)


func capture_base_transform() -> void:
	_capture_base()


func _rotate_about_local_pivot(
	base: Transform3D,
	pivot_local: Vector3,
	axis: Vector3,
	angle: float
) -> Transform3D:
	var pivot := base * pivot_local
	var offset := base.origin - pivot
	var rotation := Basis(axis, angle)
	return Transform3D(rotation * base.basis, pivot + rotation * offset)


func _capture_base() -> void:
	_base_transform = transform
	_base_captured = true


func _apply_base() -> void:
	if _base_captured:
		transform = _base_transform
