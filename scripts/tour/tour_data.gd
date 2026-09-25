class_name TourData
extends RefCounted
## v8 — every range, green, hazard, keepsake and upgrade, as data.
## World: 1 unit = 1 yard, tee at the origin, -Z is down range, +X is right.

const TIER_NAMES: Array[String] = ["Perfect!", "Great!", "Good", "Okay", "Bad", "Miss"]
const TIER_COLORS: Array[Color] = [
	Color(1.0, 0.86, 0.30), Color(0.62, 0.95, 0.55), Color(0.80, 0.93, 0.95),
	Color(0.90, 0.88, 0.80), Color(0.95, 0.62, 0.45), Color(0.80, 0.50, 0.50),
]
## Share of the aimed distance a tier actually carries.
const TIER_DISTANCE: Array[float] = [1.0, 0.965, 0.91, 0.82, 0.66, 0.38]
## Degrees the ball starts off line (sign from early/late release).
const TIER_ANGLE_DEG: Array[float] = [0.25, 1.4, 3.2, 5.8, 9.5, 15.0]
const TIER_PAY: Array[float] = [1.5, 1.2, 1.0, 0.8, 0.55, 0.3]
## Timing windows (ms of release error) for Perfect..Bad; beyond Bad is Miss.
const TIER_WINDOW_MS: Array[float] = [34.0, 70.0, 115.0, 170.0, 250.0]
const WINDUP_SEC := 0.5
const SWING_COOLDOWN_SEC := 0.55

const START_REACH := 92.0
const POWER_STEP := 1.05
const GREEN_MULT := 3.0
const ACE_RADIUS := 0.7
const ACE_MULT := 10.0
const FIRST_GREEN_BONUS_BALLS := 4.0
const STREAK_STEP := 0.1
const GOLDEN_MULT := 5.0
const SWEEP_TIP := 0.08 ## share of an average ball's pay, × chain

const RANGES: Array[Dictionary] = [
	{
		"id": "barley",
		"numeral": "I",
		"name": "Barley's Range",
		"time": "Dawn",
		"songs": ["sunrise", "early-riser"],
		"pay_mult": 1.0,
		"sky_hour": 6.2,
		"fairway_half_width": 26.0,
		"mechanic": "",
		"roll": 0.04,
		"greens": [
			{"id": "b1", "name": "Practice Green", "z": 45.0, "x": -5.0, "r": 7.5},
			{"id": "b2", "name": "The Barn", "z": 82.0, "x": 7.0, "r": 7.0},
			{"id": "b3", "name": "Old Oak", "z": 112.0, "x": -6.0, "r": 6.5},
			{"id": "b_flag", "name": "Ratina's Flag", "z": 138.0, "x": 2.0, "r": 6.5, "ratina": true},
		],
		"hazards": [],
		"keepsakes": [
			{"id": "k_tee", "name": "Carved tee \"B.\"", "z": 70.0, "x": -31.0,
				"line": "Barley whittled his own tees. Said store tees had no manners.",
				"bonus": {"pay": 0.05}},
			{"id": "k_key", "name": "Barn key", "z": 120.0, "x": 33.0,
				"line": "The barn's where he kept the good balls. It's empty now.",
				"bonus": {"balls": 1}},
		],
		"reward": {"id": "spoon", "name": "Barley's Spoon", "reach": 1.06},
	},
	{
		"id": "cliffs",
		"numeral": "II",
		"name": "Saltwind Cliffs",
		"time": "Late morning",
		"songs": ["midday", "main-theme"],
		"pay_mult": 3.6,
		"sky_hour": 11.0,
		"fairway_half_width": 24.0,
		"mechanic": "wind",
		"roll": 0.03,
		"greens": [
			{"id": "c1", "name": "Lighthouse", "z": 78.0, "x": 6.0, "r": 7.0},
			{"id": "c2", "name": "Gull Rock", "z": 128.0, "x": -7.0, "r": 6.5},
			{"id": "c3", "name": "Driftwood", "z": 172.0, "x": 5.0, "r": 6.5},
			{"id": "c_flag", "name": "Ratina's Flag", "z": 212.0, "x": 0.0, "r": 7.0, "ratina": true, "island": 12.0},
		],
		"hazards": [{"type": "water", "z0": 190.0, "z1": 236.0}],
		"keepsakes": [
			{"id": "k_feather", "name": "Gull feather", "z": 95.0, "x": 30.0,
				"line": "Barley said gulls are just rats that learned to fly.",
				"bonus": {"reach": 0.05}},
			{"id": "k_bottle", "name": "Message in a bottle", "z": 160.0, "x": -30.0,
				"line": "'Keep it low.' —B. He wrote it everywhere.",
				"bonus": {"drift": 0.25}},
		],
		"reward": {"id": "driver", "name": "Persimmon Driver", "reach": 1.06},
	},
	{
		"id": "mesa",
		"numeral": "III",
		"name": "Redrock Mesa",
		"time": "Dusk",
		"songs": ["dusk"],
		"pay_mult": 17.0,
		"sky_hour": 18.6,
		"fairway_half_width": 24.0,
		"mechanic": "roll",
		"roll": 0.13,
		"greens": [
			{"id": "m1", "name": "Saguaro", "z": 100.0, "x": -4.0, "r": 7.0},
			{"id": "m2", "name": "Dry Wash", "z": 158.0, "x": 6.0, "r": 6.5},
			{"id": "m3", "name": "Far Rim", "z": 258.0, "x": -5.0, "r": 6.5},
			{"id": "m_flag", "name": "Ratina's Flag", "z": 300.0, "x": 3.0, "r": 8.0, "ratina": true},
		],
		"hazards": [{"type": "canyon", "z0": 196.0, "z1": 232.0}],
		"keepsakes": [
			{"id": "k_rattle", "name": "Rattlesnake rattle", "z": 130.0, "x": -32.0,
				"line": "Hollow. He used it to scare crows off the greens.",
				"bonus": {"pay": 0.05}},
			{"id": "k_postcard", "name": "Postcard from the coast", "z": 275.0, "x": 31.0,
				"line": "'Retired. The fishing's terrible. Who's running my range?' —B.",
				"bonus": {"roll": 0.1}},
		],
		"reward": {"id": "lantern", "name": "Barley's Lantern", "reach": 1.0},
	},
	{
		"id": "frost",
		"numeral": "IV",
		"name": "Frostpine",
		"time": "Night",
		"songs": ["night", "midnight"],
		"pay_mult": 9.0,
		"sky_hour": 22.5,
		"fairway_half_width": 24.0,
		"mechanic": "dark",
		"roll": 0.0,
		"greens": [
			{"id": "f1", "name": "First Lantern", "z": 130.0, "x": 5.0, "r": 7.0, "lantern": true},
			{"id": "f2", "name": "Second Lantern", "z": 200.0, "x": -6.0, "r": 6.5, "lantern": true},
			{"id": "f3", "name": "Third Lantern", "z": 268.0, "x": 5.0, "r": 6.5, "lantern": true},
			{"id": "f4", "name": "Fourth Lantern", "z": 336.0, "x": -4.0, "r": 6.5, "lantern": true},
			{"id": "f_flag", "name": "Ratina's Flag", "z": 400.0, "x": 1.0, "r": 7.0, "ratina": true, "needs_lit": 4},
		],
		"hazards": [],
		"keepsakes": [
			{"id": "k_mitten", "name": "Pink mitten", "z": 170.0, "x": 31.0,
				"line": "Pink. Ratina's. She was here not long ago.",
				"bonus": {"sweet": 0.12}},
			{"id": "k_thermos", "name": "Thermos", "z": 300.0, "x": -32.0,
				"line": "Still warm. Cocoa.",
				"bonus": {"balls": 1}},
		],
		"reward": {"id": "ball", "name": "Barley's Ball", "reach": 1.05},
	},
	{
		"id": "edge",
		"numeral": "V",
		"name": "The Edge",
		"time": "Before sunrise",
		"songs": ["final"],
		"pay_mult": 30.0,
		"sky_hour": 5.2,
		"fairway_half_width": 22.0,
		"mechanic": "finale",
		"roll": 0.02,
		"greens": [
			{"id": "e1", "name": "Cloud Nine", "z": 200.0, "x": -5.0, "r": 7.0},
			{"id": "e2", "name": "Morning Star", "z": 420.0, "x": 5.0, "r": 7.0},
			{"id": "e_flag", "name": "The Longest Hole", "z": 610.0, "x": 0.0, "r": 9.0, "ratina": true},
		],
		"hazards": [],
		"keepsakes": [
			{"id": "k_cap", "name": "Barley's cap", "z": 260.0, "x": -28.0,
				"line": "It still smells like cut grass.",
				"bonus": {"reach": 0.05}},
			{"id": "k_photo", "name": "Old photo", "z": 500.0, "x": 28.0,
				"line": "Barley, Ratina and you, all younger, on the range. You were holding a bucket.",
				"bonus": {"pay": 0.1}},
		],
		"reward": {},
	},
]

## cost = base × growth^level. "shows" gates when a card appears in the shop.
const UPGRADES: Array[Dictionary] = [
	{"id": "power", "name": "Club Speed", "icon": "quality", "base": 5.0, "growth": 1.35, "max": 60,
		"desc": "Hit farther. +8% reach.", "shows": ""},
	{"id": "fee", "name": "Range Fee", "icon": "base_pay", "base": 8.0, "growth": 1.4, "max": 60,
		"desc": "Every ball pays more. +35% pay.", "shows": ""},
	{"id": "bucket", "name": "Bigger Bucket", "icon": "ball_count", "base": 26.8, "growth": 2.4, "max": 6,
		"desc": "+2 balls per bucket.", "shows": ""},
	{"id": "sweet", "name": "Sweet Spot", "icon": "metronome", "base": 40.2, "growth": 2.3, "max": 6,
		"desc": "Wider timing windows. Perfects come easier.", "shows": "bought_any"},
	{"id": "greens", "name": "Green Reader", "icon": "combo_bonus", "base": 53.6, "growth": 2.4, "max": 6,
		"desc": "Balls that stop on a green pay +0.5× more.", "shows": "green_hit"},
	{"id": "streak", "name": "Hot Streak", "icon": "perfect_pop", "base": 100.6, "growth": 2.4, "max": 5,
		"desc": "Great or better in a row: +10% pay each, up to a higher cap.", "shows": "stars_2"},
	{"id": "cart", "name": "Picker Cart", "icon": "range_picker", "base": 33.5, "growth": 2.3, "max": 6,
		"desc": "Bigger, faster sweep. Longer tip chains.", "shows": "swept"},
	{"id": "golden", "name": "Golden Balls", "icon": "golden_ball", "base": 201.2, "growth": 2.3, "max": 8,
		"desc": "+2% chance a ball is golden and pays ×5.", "shows": "range_1"},
	{"id": "wind", "name": "Wind Reader", "icon": "distance_pay", "base": 1005.8, "growth": 2.4, "max": 5,
		"desc": "Shows where the wind will take the ball. Less crosswind drift.", "shows": "range_1"},
	{"id": "roll", "name": "Run-Up", "icon": "iron_set", "base": 5364.0, "growth": 2.4, "max": 5,
		"desc": "Shows the roll. Rolled yards pay double.", "shows": "range_2"},
	{"id": "oil", "name": "Lamp Oil", "icon": "pickup", "base": 33525.0, "growth": 2.4, "max": 5,
		"desc": "Every lit lantern pays +10% more.", "shows": "range_3"},
]


static func range_count() -> int:
	return RANGES.size()


static func get_range(index: int) -> Dictionary:
	return RANGES[clampi(index, 0, RANGES.size() - 1)]


static func range_index(id: String) -> int:
	for i in RANGES.size():
		if RANGES[i]["id"] == id:
			return i
	return -1


static func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


static func all_keepsakes() -> Array:
	var out: Array = []
	for r in RANGES:
		out.append_array(r["keepsakes"])
	return out


static func flag_green(range_def: Dictionary) -> Dictionary:
	for g in range_def["greens"]:
		if g.get("ratina", false):
			return g
	return {}
