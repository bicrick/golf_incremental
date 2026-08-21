class_name TutorialCopy
extends RefCounted
## First-session dialogue lines — desktop vs mobile.
## Progress checkpoints (persisted): WELCOME→HOLD→FIRST_BUCKET→HARVEST_ENTER→HARVEST_RETURN→UPGRADES→KEEP_GOING.
## Intermediate beats chain in-session and are not durable checkpoints.

const TUTORIAL_VERSION := 3
const FINAL_BEAT := 10

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
}


## Remap pre-expanded (v1) progress 0–4 onto durable v2+ checkpoints.
static func remap_legacy_progress(progress: int) -> int:
	match progress:
		0, 1:
			return progress
		2: # old TEMPO — past first-swing tip, finishing bucket
			return Beat.FIRST_BUCKET
		3: # old PICKUP — tip done, waiting harvest→strike
			return Beat.HARVEST_RETURN
		4: # old UPGRADES / completed marker
			return Beat.UPGRADES
		_:
			return progress


static func line_for(beat: int, mobile_override: Variant = null) -> String:
	var mobile := _resolve_mobile(mobile_override)
	match beat:
		Beat.WELCOME:
			return "Hey — welcome to Range Rat."
		Beat.HOLD:
			if mobile:
				return "Alright — press and hold to take a cut."
			return "Alright — press Space to take a cut."
		Beat.FIRST_BUCKET:
			return "Okay — let's knock out our first bucket."
		Beat.OUT_OF_BALLS:
			return "Shoot — empty already. Now what?"
		Beat.HARVEST_ENTER:
			if mobile:
				return "Tap the bag to enter harvest mode."
			return "Click down-range to enter harvest mode."
		Beat.HARVEST_PICK:
			if mobile:
				return "Tap balls to pick them up."
			return "Use the cursor to select and click balls to pick them up."
		Beat.HARVEST_DONE:
			return "When you're done picking up, we can hit more."
		Beat.HARVEST_RETURN:
			if mobile:
				return "Can't find one? Tap this bottom-right control to return leftovers. Careful — no pay for returned lost balls."
			return "Can't find one? Click this bottom-right control to return leftovers. Careful — no pay for returned lost balls."
		Beat.UPGRADES:
			return "Need more cash. Top-right — time to buy an upgrade."
		Beat.KEEP_GOING:
			return "Keep going! Back to the bucket — let's make more cash."
		_:
			return ""


static func shot_reaction_line(timing_tier: int) -> String:
	## First swing only — never interjected again during the bucket.
	match timing_tier:
		Balance.TimingTier.PERFECT, Balance.TimingTier.GREAT:
			return "Ooh — nice shot!"
		Balance.TimingTier.BAD, Balance.TimingTier.MISS:
			return "Tempo. Take me all the way to the top of the backswing... then let go."
		_:
			return "Not bad. We'll dial it in."


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


static func _resolve_mobile(mobile_override: Variant) -> bool:
	if mobile_override == null:
		return UiLayout.is_mobile_touch()
	return bool(mobile_override)
