extends Control
## Barebones branch-colored polygon for upgrade tree nodes.

const BRANCH_COLORS: Dictionary = {
	Balance.UpgradeBranch.BASE_PAY: Color(0.82, 0.72, 0.48, 1.0),
	Balance.UpgradeBranch.POWER: Color(0.92, 0.58, 0.22, 1.0),
	Balance.UpgradeBranch.QUALITY: Color(0.28, 0.58, 0.72, 1.0),
	Balance.UpgradeBranch.PICKUP: Color(0.85, 0.55, 0.28, 1.0),
}

var branch: int = Balance.UpgradeBranch.BASE_PAY


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(12, 12)
	size = custom_minimum_size


func _draw() -> void:
	var fill: Color = BRANCH_COLORS.get(branch, Color(0.6, 0.6, 0.6, 1.0))
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	match branch:
		Balance.UpgradeBranch.BASE_PAY:
			var half := r * 0.85
			draw_rect(
				Rect2(center.x - half, center.y - half, half * 2.0, half * 2.0),
				fill
			)
		Balance.UpgradeBranch.POWER:
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -r),
				center + Vector2(r, 0.0),
				center + Vector2(0.0, r),
				center + Vector2(-r, 0.0),
			])
			draw_colored_polygon(diamond, fill)
		Balance.UpgradeBranch.QUALITY:
			var tri := PackedVector2Array([
				center + Vector2(0.0, -r),
				center + Vector2(-r * 0.92, r * 0.75),
				center + Vector2(r * 0.92, r * 0.75),
			])
			draw_colored_polygon(tri, fill)
		Balance.UpgradeBranch.PICKUP:
			var pent := PackedVector2Array()
			for i in range(5):
				var angle := -TAU / 4.0 + TAU * float(i) / 5.0
				pent.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(pent, fill)
		_:
			draw_rect(Rect2(Vector2.ZERO, size), fill)
