class_name TourPhysics
extends RefCounted
## v8 — shot and money math. Pure functions over (levels, range, inputs), so the
## pacing sim and the game resolve shots exactly the same way.
## Ground points are Vector2(x, d): x to the right, d yards down range.


static func level(levels: Dictionary, id: String) -> int:
	return int(levels.get(id, 0))


static func bonus_sum(keepsakes: Dictionary, key: String) -> float:
	var total := 0.0
	for k in TourData.all_keepsakes():
		if keepsakes.get(k["id"], false):
			total += float(k["bonus"].get(key, 0.0))
	return total


static func reward_reach(rewards: Dictionary) -> float:
	var m := 1.0
	for r in TourData.RANGES:
		var rw: Dictionary = r["reward"]
		if not rw.is_empty() and rewards.get(rw["id"], false):
			m *= float(rw.get("reach", 1.0))
	return m


## Longest carry a Perfect reaches (the aim cap).
static func reach(levels: Dictionary, rewards: Dictionary, keepsakes: Dictionary) -> float:
	return (TourData.START_REACH * pow(TourData.POWER_STEP, level(levels, "power"))
		* reward_reach(rewards) * (1.0 + bonus_sum(keepsakes, "reach")))


static func bucket_size(levels: Dictionary, keepsakes: Dictionary) -> int:
	return 8 + 2 * level(levels, "bucket") + int(bonus_sum(keepsakes, "balls"))


static func window_scale(levels: Dictionary, keepsakes: Dictionary) -> float:
	return 1.0 + 0.12 * level(levels, "sweet") + bonus_sum(keepsakes, "sweet")


## err_ms: release time minus the contact time (negative = early).
static func tier_for_error(err_ms: float, scale: float) -> int:
	var e := absf(err_ms)
	for i in TourData.TIER_WINDOW_MS.size():
		if e <= TourData.TIER_WINDOW_MS[i] * scale:
			return i
	return 5


static func streak_cap(levels: Dictionary) -> int:
	return 3 + 2 * level(levels, "streak")


static func golden_chance(levels: Dictionary) -> float:
	return 0.02 * level(levels, "golden")


static func cart_radius(levels: Dictionary) -> float:
	return 7.0 * (1.0 + 0.2 * level(levels, "cart"))


static func cart_speed(levels: Dictionary) -> float:
	return 70.0 * (1.0 + 0.2 * level(levels, "cart"))


static func green_mult(levels: Dictionary) -> float:
	return TourData.GREEN_MULT + 0.5 * level(levels, "greens")


static func fee_mult(levels: Dictionary, keepsakes: Dictionary) -> float:
	return (1.0 + 0.5 * level(levels, "fee")) * (1.0 + bonus_sum(keepsakes, "pay"))


## Per-yard pay before tier / green / streak multipliers.
static func base_pay(yards: float, levels: Dictionary, keepsakes: Dictionary, range_def: Dictionary) -> float:
	return (0.05 + 0.0025 * yards) * fee_mult(levels, keepsakes) * float(range_def["pay_mult"])


## Where a shot goes. aim = Vector2(x, d). wind = Vector2(cross yd per 100 yd,
## along share of carry). sign: -1 early (pull left), +1 late (push right).
static func resolve_shot(
	aim: Vector2, tier: int, sign_lr: float, wind: Vector2, range_def: Dictionary,
	levels: Dictionary, keepsakes: Dictionary, rng: RandomNumberGenerator
) -> Dictionary:
	var aim_dist := aim.length()
	var dir := aim / maxf(aim_dist, 0.001)
	## A Perfect lands within a couple of yards at any distance; worse tiers
	## scatter with the length of the shot.
	var carry := aim_dist * TourData.TIER_DISTANCE[tier] * rng.randf_range(0.98, 1.02)
	if tier == 0:
		carry = aim_dist + rng.randf_range(-2.5, 2.5)
	var angle := deg_to_rad(TourData.TIER_ANGLE_DEG[tier] * rng.randf_range(0.6, 1.1))
	if tier == 0:
		angle = rng.randf_range(-2.0, 2.0) / maxf(aim_dist, 1.0)
	else:
		angle *= sign_lr
	## Rotate the aim direction clockwise (to the right) by angle.
	var shot_dir := Vector2(dir.x * cos(angle) + dir.y * sin(angle), -dir.x * sin(angle) + dir.y * cos(angle))
	var windy: bool = range_def.get("mechanic", "") == "wind"
	if windy:
		var along := wind.y
		if along > 0.0:
			along *= 1.0 + 0.1 * level(levels, "wind")
		carry *= 1.0 + along
	var land := shot_dir * carry
	if windy:
		var cut := clampf(1.0 - 0.15 * level(levels, "wind") - bonus_sum(keepsakes, "drift"), 0.2, 1.0)
		land.x += wind.x * carry / 100.0 * cut
	var roll_share := roll_share_for(range_def, levels, keepsakes)
	roll_share *= rng.randf_range(0.9, 1.1)
	if tier >= 4:
		roll_share *= 1.6 ## thin shots skip along the ground
	var rest := land + shot_dir * carry * roll_share
	return {
		"aim": aim,
		"tier": tier,
		"land": land,
		"rest": rest,
		"carry": land.length(),
		"roll": (rest - land).length(),
	}


static func roll_share_for(range_def: Dictionary, levels: Dictionary, keepsakes: Dictionary) -> float:
	return float(range_def.get("roll", 0.0)) * (1.0 + bonus_sum(keepsakes, "roll") + 0.2 * level(levels, "roll"))


## Hazard / green / ace outcome for where a ball comes to rest (or lands, for
## hazards that swallow on the fly). lit: lantern greens already lit.
static func judge(shot: Dictionary, range_def: Dictionary, lit_count: int) -> Dictionary:
	var land: Vector2 = shot["land"]
	var rest: Vector2 = shot["rest"]
	var out := {"lost": "", "green": "", "ace": false, "rest": rest}
	for h in range_def["hazards"]:
		var hit_land := _in_hazard(land, h, range_def)
		var hit_rest := _in_hazard(rest, h, range_def)
		if hit_land:
			out["lost"] = h["type"]
			out["rest"] = land
			return out
		if hit_rest:
			## Rolled in: stops at the hazard's near edge for a canyon, sinks for water.
			out["lost"] = h["type"]
			var t := clampf((float(h["z0"]) - land.y) / maxf(rest.y - land.y, 0.001), 0.0, 1.0)
			out["rest"] = land.lerp(rest, t)
			return out
	for g in range_def["greens"]:
		if g.has("needs_lit") and lit_count < int(g["needs_lit"]):
			continue
		var c := Vector2(float(g["x"]), float(g["z"]))
		var d := rest.distance_to(c)
		if d <= float(g["r"]):
			out["green"] = g["id"]
			out["ace"] = d <= TourData.ACE_RADIUS
			return out
	return out


static func _in_hazard(p: Vector2, h: Dictionary, range_def: Dictionary) -> bool:
	if p.y < float(h["z0"]) or p.y > float(h["z1"]):
		return false
	## An island green inside a water band is dry land.
	for g in range_def["greens"]:
		if g.has("island") and p.distance_to(Vector2(float(g["x"]), float(g["z"]))) <= float(g["island"]):
			return false
	return true


## One-time bonus for the first ball to stop on a green.
static func first_green_bonus(carry: float, levels: Dictionary, keepsakes: Dictionary, range_def: Dictionary) -> float:
	return base_pay(carry, levels, keepsakes, range_def) * green_mult(levels) * TourData.FIRST_GREEN_BONUS_BALLS


static func payout(
	shot: Dictionary, verdict: Dictionary, streak: int, golden: bool, lit_count: int,
	range_def: Dictionary, levels: Dictionary, keepsakes: Dictionary
) -> float:
	if verdict["lost"] != "":
		return 0.0
	var yards: float = shot["carry"] + shot["roll"] * (2.0 if level(levels, "roll") > 0 else 1.0)
	var pay := base_pay(yards, levels, keepsakes, range_def)
	pay *= TourData.TIER_PAY[int(shot["tier"])]
	pay *= 1.0 + TourData.STREAK_STEP * mini(streak, streak_cap(levels))
	if verdict["green"] != "":
		pay *= green_mult(levels)
		if verdict["ace"]:
			pay *= TourData.ACE_MULT
	if golden:
		pay *= TourData.GOLDEN_MULT
	if range_def.get("mechanic", "") == "dark":
		pay *= 1.0 + (0.15 + 0.1 * level(levels, "oil")) * lit_count
	return pay
