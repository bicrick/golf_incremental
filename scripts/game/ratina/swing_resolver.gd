class_name RatinaSwingResolver
extends RefCounted
## Weighted timing tier roll for Ratina's autonomous swings.

const SHAKY_WEIGHTS: Array[float] = [0.04, 0.10, 0.22, 0.28, 0.24, 0.12]
const STEADY_WEIGHTS: Array[float] = [0.18, 0.24, 0.26, 0.18, 0.10, 0.04]


static func roll_tier(consistency: float) -> int:
	var t := clampf(consistency, 0.0, 1.0)
	var weights: Array[float] = []
	for i in range(SHAKY_WEIGHTS.size()):
		weights.append(lerpf(SHAKY_WEIGHTS[i], STEADY_WEIGHTS[i], t))
	return _pick_weighted(weights)


static func _pick_weighted(weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return Balance.TimingTier.GOOD
	var roll := randf() * total
	var cumulative := 0.0
	for i in weights.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return i
	return weights.size() - 1
