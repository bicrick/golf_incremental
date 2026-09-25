class_name StoryScript
extends RefCounted
## Every story line. Keep in sync with docs/v5/01-story.md.
## Each line is [speaker, text]; speaker is "rat", "ratina", or "note".

const NOTES := {
	"note_ratina": "Following the light. It must be the first tee. Back by dark. —R",
	"note_1": "HOLE 1 · PAR 4 · 385 YDS. Practice the swing you'll need, not the one you have. —B",
	"note_2": "The mist isn't weather. It's forgetting. Grass forgets it's a fairway if nobody plays to it. Every ball is a reminder. —B",
	"note_3": "Left the range to you. Knew you'd grumble. Knew you'd stay. Keep swinging. I can hear them landing from here. —B",
	"note_tee": "(carved) HOLE 1 · PAR 4 · 385 YDS. Tee it high. —B",
	"note_last": "Took you long enough. Green's awake. Went on ahead to wake up the second. See you at the turn. Hole 1: your honor. —B",
}

const FIND_LINES := {
	"scorecard_1": [
		["rat", "A scorecard. Barley's pencil."],
		["rat", "He always wrote in pencil. Said it made lying easier."],
		["note", "note_1"],
		["rat", "Hole 1. Three hundred eighty-five yards. ...There's no Hole 1. There's just mist."],
	],
	"ratina_bag": [
		["rat", "A golf bag. Pink. The name tag says RATINA."],
		["rat", "Somebody came out here looking for the course. There's a note in the pocket."],
		["note", "note_ratina"],
		["rat", "...That was a long time ago."],
		["rat", "She's still out there somewhere. The bag's full of spare balls. I'll hold onto them for her."],
	],
	"range_bell": [
		["rat", "...DONNNG."],
		["rat", "Last bucket. Except it isn't. Feels quicker out here now."],
	],
	"picker_cart": [
		["rat", "The old ball-picker cart. Half buried."],
		["rat", "Still has a basket on it. That's more balls per bucket."],
	],
	"rattling_burrow": [
		["rat", "A burrow. Something's blinking at me."],
		["rat", "Rattlings. They lived in the rough before the mist."],
		["rat", "There's a pile of balls in there. ...Some of them have a B on them."],
		["rat", "They watched him go by. They've been keeping his balls safe."],
		["rat", "They like shiny round things. We have a lot of shiny round things."],
		["rat", "They won't touch what I'm picking up. But anything I leave behind... they'll bring back."],
	],
	"scorecard_2": [
		["rat", "Another one."],
		["note", "note_2"],
		["rat", "So every ball I've hit was... a reminder."],
	],
	"barley_spoon": [
		["rat", "Barley's old spoon. Stuck upright in the turf, like a marker."],
		["rat", "'I went this way.' ...He left me his clubs."],
		["rat", "It flies farther than it has any right to. He always said so."],
	],
	"stone_lantern": [
		["rat", "A stone lantern. There used to be two of these at the first tee."],
		["rat", "Somebody lit it. It's still burning."],
		["rat", "There's a pink ribbon tied around the post."],
		["rat", "...Ratina came this way. She followed this light."],
	],
	"birdhouse": [
		["rat", "Oh. Oh, that's a lot of birds."],
		["rat", "Some of them are shiny. Keep an eye out."],
	],
	"scorecard_3": [
		["rat", "Third one."],
		["note", "note_3"],
		["rat", "...He can hear them landing."],
		["rat", "Okay, Barley. Louder, then."],
	],
	"persimmon_driver": [
		["rat", "His driver. The persimmon one. He never let anyone touch it."],
		["rat", "He didn't drop this. He leaned it where I'd see it."],
		["rat", "...Okay. I'll look after it."],
	],
	"ratina_found": [
		["rat", "Someone's sitting on the far bank. Pink visor."],
		["ratina", "Oh! You can SEE me?"],
		["ratina", "I followed a light out here. Then the mist came in and the bridge was just... gone."],
		["ratina", "I've been listening to your shots land for ages. You slice, by the way."],
		["rat", "Your bag's back at the range. Want a bay? We have bays."],
		["ratina", "Do I want a bay. Yes. Obviously."],
		["ratina", "First tip's free: you're rushing the top. Let it breathe, then go."],
	],
	"footbridge": [
		["rat", "A footbridge. There's a creek under the mist."],
		["rat", "I didn't know there was a creek. That means we're off the range."],
		["rat", "We're on the course."],
		["rat", "The Rattlings won't have to swim anymore. They'll like that."],
	],
	"tee_sign": [
		["rat", "Hole one. Par four. Three eighty-five."],
		["note", "note_tee"],
		["rat", "'Tee it high.' ...Fine."],
		["rat", "The green's out there. One more good one."],
	],
	"first_green": [
		["rat", "A flag. A real flag. On a real green."],
		["rat", "His cap's on the flagstick. He never leaves the cap."],
		["rat", "There's a note."],
		["note", "note_last"],
		["rat", "...Your honor."],
		["rat", "Okay. One ball."],
	],
}

## Kept for API compatibility — Ratina is found late now, so nothing to add.
const RATINA_AWARE_LINES := {}

## Clicking a target find before a ball has landed on it.
const TARGET_HINT_LINES := {
	"range_bell": [
		["rat", "The old range bell. Rusted stiff."],
		["rat", "Barley used to ring it for last bucket. A good shot might knock it loose."],
	],
	"birdhouse": [
		["rat", "A birdhouse. Empty. Maybe somebody's asleep in there."],
		["rat", "Knock with a ball. Gently. Ish."],
	],
}

const REVEAL_HINT := "The mist pulled back. Something's out there, past the %d sign."
const REVEAL_HINT_NEAR := "The mist pulled back. Something's out there."
const TARGET_TRIGGERED := {
	"range_bell": "...Did you hear that? The bell.",
	"birdhouse": "Something rattled in the birdhouse.",
}

## First harvest after the tutorial — introduces the idea that the mist hides things.
const FIRST_MIST_LINES := [
	["rat", "See the mist down there? It sits one step past our longest ball."],
	["rat", "Hit farther and it backs off. Barley used to say it was hiding a golf course."],
	["rat", "Barley said a lot of things."],
]

const FINALE_ARMED_LINE := "One ball. Take your time."
const FINAL_SWING_LINE := "...Fore."

const ENDING_LINES: Array[String] = [
	"The mist lifted off Mistmeadow that evening, one fairway at a time.",
	"Ratina swears she heard a far-off \"FORE!\" from somewhere past the second green.",
	"The Rattlings still bring every ball back. Some of them aren't ours.",
	"And the range stays open. Somebody has to keep the lights on.",
]

const POSTGAME_WELCOME_LINES: PackedStringArray = [
	"Course is awake. Range is still ours.",
	"Somebody has to keep the lights on. Might as well be us.",
	"Ratina says she heard a 'FORE!' past the second green.",
	"Hit a few. Barley can hear them.",
]


static func lines_for_find(id: String, ratina_here: bool = false) -> Array:
	var lines: Array = FIND_LINES.get(id, []).duplicate()
	if ratina_here and RATINA_AWARE_LINES.has(id):
		lines.append_array(RATINA_AWARE_LINES[id])
	return lines


static func hint_lines_for(id: String) -> Array:
	return TARGET_HINT_LINES.get(id, [])


static func note_text(key: String) -> String:
	return NOTES.get(key, "")


static func reveal_hint(yards: float) -> String:
	## Name the nearest yardage sign short of the find (signs every 50 yd).
	var sign := mini(int(floor(yards / 50.0)) * 50, 300)
	if sign < 50:
		return REVEAL_HINT_NEAR
	return REVEAL_HINT % sign


static func pick_postgame_welcome() -> String:
	return POSTGAME_WELCOME_LINES[randi() % POSTGAME_WELCOME_LINES.size()]
