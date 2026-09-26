class_name FortuneData
extends RefCounted
## v9 — rooms and upgrades, as data. cost = base × growth^level.

const GOAL := 1000000.0

const ROOMS: Array[Dictionary] = [
	{"id": "tee", "name": "Tee Line", "unlock": 0.0, "icon": "i_ball"},
	{"id": "green", "name": "Putting Green", "unlock": 500.0, "icon": "i_star"},
	{"id": "cards", "name": "Scorecards", "unlock": 3000.0, "icon": "i_book"},
	{"id": "dice", "name": "19th Hole", "unlock": 25000.0, "icon": "i_coin"},
]

const RENOVATIONS := ["barley", "cliffs", "mesa", "frost", "edge"]

## needs: another upgrade id that must be at least level 1 first.
const UPGRADES: Array[Dictionary] = [
	# --- Tee Line ---------------------------------------------------------------
	{"id": "tee_value", "room": "tee", "name": "Ball Value", "icon": "base_pay", "base": 30.0, "growth": 1.45, "max": 40,
		"desc": "+$1 on every ball."},
	{"id": "tee_speed", "room": "tee", "name": "Quick Tee", "icon": "metronome", "base": 60.0, "growth": 3.0, "max": 8,
		"desc": "Swing again sooner."},
	{"id": "tee_rings", "room": "tee", "name": "Wider Rings", "icon": "quality", "base": 120.0, "growth": 3.2, "max": 6,
		"desc": "The ×1, ×2 and ×5 rings grow 8%."},
	{"id": "tee_sweet", "room": "tee", "name": "Sweet Spot", "icon": "perfect_pop", "base": 180.0, "growth": 3.2, "max": 6,
		"desc": "Wider timing windows. More Perfects (they pay ×2)."},
	{"id": "tee_ratina", "room": "tee", "name": "Hire Ratina", "icon": "ball_count", "base": 300.0, "growth": 3.2, "max": 8,
		"desc": "Ratina swings on her own. Each level she's quicker."},
	{"id": "tee_golden", "room": "tee", "name": "Golden Balls", "icon": "golden_ball", "base": 600.0, "growth": 3.5, "max": 6,
		"desc": "+1.5% chance a ball is gold and pays ×10."},
	{"id": "tee_multi", "room": "tee", "name": "Multiball", "icon": "ball_count", "base": 6000.0, "growth": 20.0, "max": 2,
		"desc": "+1 ball every swing."},
	{"id": "tee_pin", "room": "tee", "name": "Pin Hunter", "icon": "combo_bonus", "base": 3600.0, "growth": 3.5, "max": 5,
		"desc": "The PIN pays +5× more and grows a little. PIN hits drop golden putts (×5) on the green."},
	{"id": "tee_cousins", "room": "tee", "name": "Cousins", "icon": "range_picker", "base": 15000.0, "growth": 4.0, "max": 6,
		"desc": "Another rat takes the next bay and swings all day.", "needs": "tee_ratina"},
	{"id": "tee_reno", "room": "tee", "name": "Renovate", "icon": "iron_set", "base": 15000.0, "growth": 5.0, "max": 4,
		"desc": "Rebuild the range somewhere grander. Tee Line income ×1.5."},
	# --- Putting Green ----------------------------------------------------------
	{"id": "putt_value", "room": "green", "name": "Putt Value", "icon": "base_pay", "base": 180.0, "growth": 1.45, "max": 40,
		"desc": "+$2 on every putt."},
	{"id": "putt_cups", "room": "green", "name": "Cup Boost", "icon": "combo_bonus", "base": 600.0, "growth": 3.2, "max": 8,
		"desc": "Every cup pays 25% more."},
	{"id": "putt_auto", "room": "green", "name": "Putt Rattler", "icon": "range_picker", "base": 1200.0, "growth": 3.2, "max": 8,
		"desc": "A Rattling on the fringe drops putts for you, faster each level."},
	{"id": "putt_multi", "room": "green", "name": "Double Drop", "icon": "ball_count", "base": 9000.0, "growth": 15.0, "max": 2,
		"desc": "+1 putt every drop."},
	{"id": "putt_bumpers", "room": "green", "name": "Bumper Pegs", "icon": "perfect_pop", "base": 4500.0, "growth": 3.5, "max": 5,
		"desc": "Every peg a putt hits pays a little."},
	{"id": "putt_jackpot", "room": "green", "name": "Big Jackpot", "icon": "golden_ball", "base": 6000.0, "growth": 3.5, "max": 5,
		"desc": "The JACKPOT cup gets wider. Each jackpot adds to everything, forever."},
	# --- Scorecards ---------------------------------------------------------------
	{"id": "card_value", "room": "cards", "name": "Card Value", "icon": "base_pay", "base": 3000.0, "growth": 1.45, "max": 30,
		"desc": "Pricier cards (+$45) that pay back more."},
	{"id": "card_luck", "room": "cards", "name": "Lucky Pencil", "icon": "perfect_pop", "base": 7500.0, "growth": 3.2, "max": 8,
		"desc": "Better odds on birdies and eagles."},
	{"id": "card_auto", "room": "cards", "name": "Old Owl", "icon": "range_picker", "base": 18000.0, "growth": 3.4, "max": 8,
		"desc": "The Old Owl buys and scratches cards for you, faster each level."},
	{"id": "card_frenzy", "room": "cards", "name": "Birdie Rush", "icon": "metronome", "base": 12000.0, "growth": 3.2, "max": 5,
		"desc": "Birdies send the Tee Line into a longer frenzy (double-speed swings)."},
	{"id": "card_back9", "room": "cards", "name": "Back Nine", "icon": "iron_set", "base": 120000.0, "growth": 1.0, "max": 1,
		"desc": "18-hole cards: twice the holes, same price."},
	# --- 19th Hole ------------------------------------------------------------------
	{"id": "dice_value", "room": "dice", "name": "Dice Value", "icon": "base_pay", "base": 36000.0, "growth": 1.45, "max": 30,
		"desc": "+$60 on every pip."},
	{"id": "dice_speed", "room": "dice", "name": "Quick Hands", "icon": "metronome", "base": 60000.0, "growth": 3.0, "max": 6,
		"desc": "Roll again sooner."},
	{"id": "dice_loaded", "room": "dice", "name": "Loaded Dice", "icon": "perfect_pop", "base": 75000.0, "growth": 3.2, "max": 6,
		"desc": "Doubles come up more often."},
	{"id": "dice_duration", "room": "dice", "name": "Long Night", "icon": "combo_bonus", "base": 90000.0, "growth": 3.0, "max": 6,
		"desc": "Dice buffs last 25% longer."},
	{"id": "dice_auto", "room": "dice", "name": "Toad Barkeep", "icon": "range_picker", "base": 180000.0, "growth": 3.4, "max": 6,
		"desc": "Toad rolls for you."},
	{"id": "dice_third", "room": "dice", "name": "Third Die", "icon": "golden_ball", "base": 600000.0, "growth": 1.0, "max": 1,
		"desc": "Roll three. Triples: ×10 everything for 30 s."},
]


static func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


static func room(id: String) -> Dictionary:
	for r in ROOMS:
		if r["id"] == id:
			return r
	return {}


static func upgrades_for(room_id: String) -> Array:
	return UPGRADES.filter(func(u: Dictionary) -> bool: return u["room"] == room_id)
