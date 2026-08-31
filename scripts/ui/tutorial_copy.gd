class_name TutorialCopy
extends RefCounted
## First-session dialogue lines (desktop vs mobile).
## Progress checkpoints (persisted): WELCOME→HOLD→FIRST_BUCKET→HARVEST_ENTER→HARVEST_RETURN→UPGRADES→KEEP_GOING.
## Intermediate beats chain in-session and are not durable checkpoints.
## Returning players (tutorial_completed) get a one-shot welcome-back line on Play.

const TUTORIAL_VERSION := 4
const FINAL_BEAT := 10

## Short returning-player lines. Soft-spoken range rat who knows the job.
const WELCOME_BACK_LINES: PackedStringArray = [
	"Welcome back. Let's hit some balls.",
	"You're back. The bucket's waiting.",
	"Good to see you. Grab a club.",
	"Range is open. You know the drill.",
	"Back already? I'm glad. Swing time.",
	"There you are. Ready when you are.",
	"Hey again. Fairway's ready.",
	"Don't keep the bucket waiting too long.",
	"Good to see you. Let's make more cash.",
	"Ah. You're back. Let's knock a few.",
]

enum Beat {
	WELCOME = 0,
	HOLD = 1,
	SHOT_REACTION = 2,
	FIRST_BUCKET = 3,
	OUT_OF_BALLS = 4,
	HARVEST_ENTER = 5,
	HARVEST_PICK = 6,
	HARVEST_DONE = 7,
	HARVEST_RETURN = 8,
	UPGRADES = 9,
	KEEP_GOING = 10,
	## In-session nudge only (not a progress checkpoint). Shown if Space during HARVEST_PICK wait.
	HARVEST_FIND_HINT = 11,
	## Range upgrades story (in-session). Final CTA is durable UPGRADES.
	UPGRADES_STUCK = 12,
	UPGRADES_SPEND = 13,
	## First open of upgrade menu (in-session). Persisted via tutorial_upgrade_menu_seen.
	UPGRADES_MENU_BROKE = 14,
	UPGRADES_MENU_CLICK = 15,
}


## Remap pre-expanded (v1) progress 0–4 onto durable v2+ checkpoints.
static func remap_legacy_progress(progress: int) -> int:
	match progress:
		0, 1:
			return progress
		2: # old TEMPO: past first-swing tip, finishing bucket
			return Beat.FIRST_BUCKET
		3: # old PICKUP: tip done, waiting harvest→strike
			return Beat.HARVEST_RETURN
		4: # old UPGRADES / completed marker
			return Beat.UPGRADES
		_:
			return progress


static func line_for(beat: int, mobile_override: Variant = null) -> String:
	var mobile := _resolve_mobile(mobile_override)
	match beat:
		Beat.WELCOME:
			return "Hey. Welcome to Range Rat."
		Beat.HOLD:
			if mobile:
				return "Press and hold to take a cut."
			return "Press and hold Space to take a cut."
		Beat.FIRST_BUCKET:
			return "Okay. Let's knock out our first bucket."
		Beat.OUT_OF_BALLS:
			return "We're out. Let's go collect the balls we have. Only a few, but I'm sure we can buy more later."
		Beat.HARVEST_ENTER:
			if mobile:
				return "Tap the bag to enter harvest mode."
			return "Click down-range to enter harvest mode."
		Beat.HARVEST_PICK:
			if mobile:
				return "Tap balls to pick them up."
			return "Use the cursor to select and click balls to pick them up."
		Beat.HARVEST_FIND_HINT:
			if mobile:
				return "They're on the range. Drag and pinch to find them, then tap with the ring."
			return "They're on the range. Drag and zoom to find them, then click with the ring."
		Beat.HARVEST_DONE:
			return "When you're done picking up, we can hit more."
		Beat.HARVEST_RETURN:
			if mobile:
				return "Can't find one? Tap this bottom-right control to return leftovers. Careful. No pay for returned lost balls."
			return "Can't find one? Click this bottom-right control to return leftovers. Careful. No pay for returned lost balls."
		Beat.UPGRADES_STUCK:
			return "We're stuck here. Forever. Just hitting balls. So we get stronger."
		Beat.UPGRADES_SPEND:
			return "Ball cash buys upgrades. Tiny steps to strongest golfer. Allegedly."
		Beat.UPGRADES:
			return "Top-right. Click here."
		Beat.UPGRADES_MENU_BROKE:
			return "Looks like we're pretty broke. Do we even have enough for one upgrade?"
		Beat.UPGRADES_MENU_CLICK:
			return "Let's click this square and see what happens."
		Beat.KEEP_GOING:
			return "Keep going. Back to the bucket. Let's make more cash."
		_:
			return ""


static func shot_reaction_line(timing_tier: int) -> String:
	## First swing only. Never interjected again during the bucket.
	match timing_tier:
		Balance.TimingTier.PERFECT, Balance.TimingTier.GREAT:
			return "Ooh. Nice shot."
		Balance.TimingTier.BAD, Balance.TimingTier.MISS:
			return "Tempo. Take me all the way to the top of the backswing... then let go."
		_:
			return "Not bad. We'll dial it in."


static func pick_welcome_back_line(rng: RandomNumberGenerator = null) -> String:
	## One random line for returning players after title Play.
	if WELCOME_BACK_LINES.is_empty():
		return "Welcome back. Let's hit some balls."
	var i: int
	if rng != null:
		i = rng.randi() % WELCOME_BACK_LINES.size()
	else:
		i = randi() % WELCOME_BACK_LINES.size()
	return WELCOME_BACK_LINES[i]


static func is_welcome_back_line(text: String) -> bool:
	return WELCOME_BACK_LINES.has(text)


static func continue_hint(mobile_override: Variant = null) -> String:
	if _resolve_mobile(mobile_override):
		return "Tap"
	return "Space"


static func preview_kind_for(beat: int, mobile_override: Variant = null) -> int:
	var mobile := _resolve_mobile(mobile_override)
	match beat:
		Beat.HARVEST_ENTER:
			if mobile:
				return TutorialUiPreviews.Kind.SHAG_BAG
			return TutorialUiPreviews.Kind.NONE
		Beat.HARVEST_RETURN:
			return TutorialUiPreviews.Kind.BUCKET
		Beat.UPGRADES:
			return TutorialUiPreviews.Kind.UPGRADES
		_:
			return TutorialUiPreviews.Kind.NONE


static func is_upgrades_menu_beat(beat: int) -> bool:
	return beat == Beat.UPGRADES_MENU_BROKE or beat == Beat.UPGRADES_MENU_CLICK


static func is_upgrades_story_beat(beat: int) -> bool:
	return (
		beat == Beat.UPGRADES_STUCK
		or beat == Beat.UPGRADES_SPEND
		or beat == Beat.UPGRADES
	)


static func _resolve_mobile(mobile_override: Variant) -> bool:
	if mobile_override == null:
		return UiLayout.is_mobile_touch()
	return bool(mobile_override)
