class_name TourStory
extends RefCounted
## v8 — every line of dialogue. who: rat, ratina, note, sign.

const BEATS := {
	"intro": [
		{"who": "sign", "text": "Barley's Range. Dawn."},
		{"who": "rat", "text": "Ratina's bag. On my mat. With a note taped to it."},
		{"who": "note", "text": "Rat, I took Barley's old scorecard. Five holes, five ranges, one day."},
		{"who": "note", "text": "The last one is the Longest Hole. It tees off at the edge of the world when the sun comes up."},
		{"who": "note", "text": "You've hit a million balls here and never played a single hole. Come play this one with me. Follow my pink flags. -R"},
		{"who": "rat", "text": "She knows I don't leave the range."},
		{"who": "rat", "text": "...One bucket at a time, then."},
	],
	"tip_swing": [
		{"who": "rat", "text": "Hold Space (or the mouse). Let go when the ring closes on the ball."},
		{"who": "rat", "text": "Too early pulls it left. Too late pushes it right. A Perfect flies true."},
	],
	"tip_aim": [
		{"who": "rat", "text": "A and D pick a flag. Balls that stop on a green pay triple."},
	],
	"tip_sweep": [
		{"who": "rat", "text": "Bucket's empty. Drive the cart over the balls. Quick pickups in a row earn tips."},
	],
	"tip_shop": [
		{"who": "rat", "text": "Enough for something from the Pro Shop. Tab opens it. Club Speed gets me closer to her flag."},
	],
	"flag_barley": [
		{"who": "note", "text": "Told you you could reach it."},
		{"who": "note", "text": "Next: Saltwind Cliffs. The wind there always blows toward the sea. -R"},
		{"who": "rat", "text": "Tied to the flag: Barley's old spoon. He'd want it swung."},
	],
	"arrive_cliffs": [
		{"who": "sign", "text": "Saltwind Cliffs. Late morning."},
		{"who": "rat", "text": "Salt in the air. The sea eats golf balls here."},
		{"who": "rat", "text": "Watch the windsock. A tailwind carries. A crosswind drags it sideways, so lean into it early or late."},
		{"who": "rat", "text": "Her flag's on that island. Short is wet. Long is wet."},
	],
	"flag_cliffs": [
		{"who": "note", "text": "Barley played this in a gale in '79 and wrote KEEP IT LOW in the margin."},
		{"who": "note", "text": "I did not keep it low. Lost six balls. Next is the Mesa. The ground is hard as a skillet, so let it roll. -R"},
		{"who": "rat", "text": "She left his persimmon driver in the sand. Still warm from the sun."},
	],
	"arrive_mesa": [
		{"who": "sign", "text": "Redrock Mesa. Dusk."},
		{"who": "rat", "text": "Everything out here is red. Even the ground's hot."},
		{"who": "rat", "text": "Balls roll a long way on this hardpan. Land short and let it run on."},
		{"who": "rat", "text": "And that canyon. Carry it, or it keeps the ball."},
	],
	"flag_mesa": [
		{"who": "note", "text": "Barley's card says: Hole 3, the canyon. Carry it or cry."},
		{"who": "note", "text": "I carried it on the ninth try. It's getting dark, and I'm heading up the mountain. Bring a light. -R"},
		{"who": "rat", "text": "His lantern, hanging off the flagstick. Barley never went anywhere without it."},
	],
	"arrive_frost": [
		{"who": "sign", "text": "Frostpine. Night."},
		{"who": "rat", "text": "Can't see past my own nose."},
		{"who": "rat", "text": "Lanterns out on the snow. Land one on a lantern's green and it lights. Every light makes the range pay more."},
		{"who": "rat", "text": "Light all four and I bet the path to her flag shows up."},
	],
	"frost_path": [
		{"who": "rat", "text": "There. A pink flag, way out in the dark."},
	],
	"flag_frost": [
		{"who": "note", "text": "The last hole on Barley's card is blank. No yardage, no par. Just: play it with somebody."},
		{"who": "note", "text": "I'm at the top. Hurry. It's almost morning. -R"},
		{"who": "rat", "text": "One ball, wrapped in the note. Barley's initials on it."},
	],
	"arrive_edge": [
		{"who": "sign", "text": "The Edge. Before sunrise."},
		{"who": "ratina", "text": "You came."},
		{"who": "rat", "text": "You took my scorecard."},
		{"who": "ratina", "text": "Barley's scorecard. He said the green on the Longest Hole is wherever the sun comes up. Nobody's ever reached it."},
		{"who": "rat", "text": "Nobody's ever tried from a range."},
		{"who": "ratina", "text": "It's not a range. It's a hole. You don't get a bucket, you get one ball."},
		{"who": "ratina", "text": "...Warm up first. I'll wait."},
	],
	"edge_ready": [
		{"who": "ratina", "text": "That's it. You can reach it now."},
		{"who": "ratina", "text": "Pick the Longest Hole and put Barley's ball on it."},
	],
	"edge_miss": [
		{"who": "ratina", "text": "Again. Nobody counts the first one."},
	],
	"ending": [
		{"who": "ratina", "text": "...It's on."},
		{"who": "ratina", "text": "What's par on the Longest Hole?"},
		{"who": "rat", "text": "Whatever it took to get here."},
		{"who": "ratina", "text": "Then we made par."},
	],
	"postgame": [
		{"who": "ratina", "text": "Same time tomorrow? I know a range."},
	],
}

const REWARD_TEXT := {
	"spoon": "Barley's Spoon: +6% reach",
	"driver": "Persimmon Driver: +6% reach",
	"lantern": "Barley's Lantern: the Frostpine lanterns can be lit",
	"ball": "Barley's Ball: +5% reach, for the Longest Hole",
}

const BONUS_TEXT := {
	"pay": "+%d%% pay",
	"reach": "+%d%% reach",
	"balls": "+1 ball per bucket",
	"drift": "-%d%% crosswind drift",
	"roll": "+%d%% roll",
	"sweet": "wider timing windows",
}


static func beat(id: String) -> Array:
	return BEATS.get(id, [])


static func bonus_text(bonus: Dictionary) -> String:
	var parts: Array[String] = []
	for k in bonus:
		var fmt: String = BONUS_TEXT.get(k, "")
		if fmt.contains("%d"):
			parts.append(fmt % int(round(float(bonus[k]) * 100.0)))
		else:
			parts.append(fmt)
	return ", ".join(parts)
