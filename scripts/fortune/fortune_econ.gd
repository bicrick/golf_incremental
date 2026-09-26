class_name FortuneEcon
extends RefCounted
## v9 — every derived number, from upgrade levels. Pure functions so the game,
## the autoplayer and any sim agree.

# --- global ----------------------------------------------------------------------

static func lv(levels: Dictionary, id: String) -> int:
	return int(levels.get(id, 0))


# --- Tee Line --------------------------------------------------------------------

const TIER_BONUS: Array[float] = [2.0, 1.3, 1.0, 0.9, 0.7, 0.5]
const TIER_WINDOW_MS: Array[float] = [34.0, 70.0, 115.0, 170.0, 250.0]
## How far from the aim point each tier lands (yards, 1σ).
const TIER_SCATTER: Array[float] = [4.5, 7.0, 10.0, 15.0, 22.0, 32.0]
const RING_RADII: Array[float] = [26.0, 15.0, 7.5, 1.4] ## ×1, ×2, ×5, PIN
const RING_MULT: Array[float] = [1.0, 2.0, 5.0, 15.0]
const MISS_MULT := 0.2
const TARGET_Z := 78.0
const WINDUP_SEC := 0.5


static func tee_value(levels: Dictionary) -> float:
	return (1.0 + lv(levels, "tee_value")) * pow(1.5, lv(levels, "tee_reno"))


static func tee_cooldown(levels: Dictionary) -> float:
	return maxf(0.6 * pow(0.86, lv(levels, "tee_speed")), 0.14)


static func ring_scale(levels: Dictionary) -> float:
	return pow(1.08, lv(levels, "tee_rings"))


## Wider Rings grows ×1/×2/×5; Pin Hunter grows the PIN a little.
static func ring_radius(levels: Dictionary, ring: int) -> float:
	if ring == 3:
		return RING_RADII[3] * (1.0 + 0.06 * lv(levels, "tee_pin"))
	return RING_RADII[ring] * ring_scale(levels)


static func ring_mult(levels: Dictionary, ring: int) -> float:
	if ring == 3:
		return RING_MULT[3] + 5.0 * lv(levels, "tee_pin")
	return RING_MULT[ring]


static func window_scale(levels: Dictionary) -> float:
	return 1.0 + 0.15 * lv(levels, "tee_sweet")


static func tier_for_error(err_ms: float, scale: float) -> int:
	var e := absf(err_ms)
	for i in TIER_WINDOW_MS.size():
		if e <= TIER_WINDOW_MS[i] * scale:
			return i
	return 5


static func balls_per_swing(levels: Dictionary) -> int:
	return 1 + lv(levels, "tee_multi")


static func golden_chance(levels: Dictionary) -> float:
	return 0.015 * lv(levels, "tee_golden")


## Ratina: seconds between swings (0 = not hired).
static func ratina_interval(levels: Dictionary) -> float:
	var l := lv(levels, "tee_ratina")
	return 0.0 if l == 0 else 2.6 * pow(0.84, l - 1)


static func cousin_count(levels: Dictionary) -> int:
	return lv(levels, "tee_cousins")


const COUSIN_INTERVAL := 3.2


## Which ring a landing point (distance from the pin, yards) scores.
static func ring_for(dist: float, levels: Dictionary) -> int:
	for i in range(3, -1, -1):
		if dist <= ring_radius(levels, i):
			return i
	return -1


static func landing_mult(dist: float, levels: Dictionary) -> float:
	var r := ring_for(dist, levels)
	return MISS_MULT if r < 0 else ring_mult(levels, r)


# --- Putting Green ---------------------------------------------------------------

## Eight cups along the bottom, richest in the middle. A small golden JACKPOT
## hole slides back and forth across them.
const CUP_MULTS: Array[float] = [0.3, 0.6, 1.0, 2.0, 2.0, 1.0, 0.6, 0.3]
const JACKPOT_MULT := 25.0


static func putt_value(levels: Dictionary) -> float:
	return 3.0 + 2.0 * lv(levels, "putt_value")


static func cup_mult(levels: Dictionary, cup: int) -> float:
	return CUP_MULTS[cup] * pow(1.25, lv(levels, "putt_cups"))


static func putts_per_drop(levels: Dictionary) -> int:
	return 1 + lv(levels, "putt_multi")


## Jackpot hole width in board pixels.
static func jackpot_width(levels: Dictionary) -> float:
	return 9.0 * pow(1.2, lv(levels, "putt_jackpot"))


static func jackpot_mult(levels: Dictionary) -> float:
	return JACKPOT_MULT * pow(1.25, lv(levels, "putt_cups"))


static func putt_auto_interval(levels: Dictionary) -> float:
	var l := lv(levels, "putt_auto")
	return 0.0 if l == 0 else 1.6 * pow(0.8, l - 1)


static func bumper_pay(levels: Dictionary) -> float:
	return putt_value(levels) * 0.02 * lv(levels, "putt_bumpers")


## Each jackpot adds a little less than the last: 2%, 1.4%, 1.2%, 1%…
static func jackpot_permanent(jackpots: int) -> float:
	return 0.01 / sqrt(1.0 + jackpots)


# --- Scorecards --------------------------------------------------------------------

## bogey, par, birdie, eagle, hole-in-one
const CARD_OUTCOMES := ["Bogey", "Par", "Birdie", "Eagle", "Hole in one!"]
const CARD_PAYS: Array[float] = [0.0, 0.1, 0.5, 2.5, 12.0] ## × card price
const ACE_PERMANENT := 0.03


static func card_price(levels: Dictionary) -> float:
	return 60.0 + 45.0 * lv(levels, "card_value")


static func card_holes(levels: Dictionary) -> int:
	return 18 if lv(levels, "card_back9") > 0 else 9


static func card_odds(levels: Dictionary) -> Array[float]:
	var l := float(lv(levels, "card_luck"))
	var ace := 0.003 + 0.0006 * l
	var eagle := 0.05 + 0.01 * l
	var birdie := 0.17 + 0.02 * l
	var par := 0.36
	var bogey := maxf(1.0 - ace - eagle - birdie - par, 0.05)
	return [bogey, par, birdie, eagle, ace]


static func card_auto_interval(levels: Dictionary) -> float:
	var l := lv(levels, "card_auto")
	return 0.0 if l == 0 else 4.0 * pow(0.8, l - 1)


## Seconds of Tee Line frenzy each birdie-or-better adds.
static func frenzy_sec(levels: Dictionary) -> float:
	return 3.0 + lv(levels, "card_frenzy")


const FRENZY_CAP := 30.0
const SNAKE_EYES_PERMANENT := 0.03


# --- 19th Hole ----------------------------------------------------------------------

static func pip_value(levels: Dictionary) -> float:
	return 90.0 + 60.0 * lv(levels, "dice_value")


static func dice_cooldown(levels: Dictionary) -> float:
	return 4.0 * pow(0.85, lv(levels, "dice_speed"))


static func dice_count(levels: Dictionary) -> int:
	return 3 if lv(levels, "dice_third") > 0 else 2


## Chance to force a matching die (loaded dice).
static func loaded_chance(levels: Dictionary) -> float:
	return 0.06 * lv(levels, "dice_loaded")


static func buff_scale(levels: Dictionary) -> float:
	return 1.0 + 0.25 * lv(levels, "dice_duration")


static func dice_auto_interval(levels: Dictionary) -> float:
	var l := lv(levels, "dice_auto")
	return 0.0 if l == 0 else 6.0 * pow(0.82, l - 1)
