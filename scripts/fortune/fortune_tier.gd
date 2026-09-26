class_name FortuneTier
extends RefCounted
## Swing tier names and colours.

const NAMES: Array[String] = ["Perfect!", "Great!", "Good", "Okay", "Bad", "Miss"]
const COLORS: Array[Color] = [
	Color(1.0, 0.86, 0.30), Color(0.62, 0.95, 0.55), Color(0.80, 0.93, 0.95),
	Color(0.90, 0.88, 0.80), Color(0.95, 0.62, 0.45), Color(0.80, 0.50, 0.50),
]


static func name(tier: int) -> String:
	return NAMES[clampi(tier, 0, 5)]


static func color(tier: int) -> Color:
	return COLORS[clampi(tier, 0, 5)]
