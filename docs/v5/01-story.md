# v5 · Story

## Premise

**Mistmeadow Links** was a small eighteen-hole course at the edge of the forest. Its driving range was where everyone warmed up, argued about grips, and bought a bucket from **Barley**, the old pro who ran the whole place: pro, greenskeeper, and teller of terrible jokes.

Then people stopped coming. The course went quiet, and **the mist** rolled in the way it does over any grass nobody plays to. One evening Barley shouldered his bag, said he was going to "go wake up the first hole", and walked into it. He didn't come back.

The **Range Rat** (you) stayed and kept the range open. *"Somebody has to keep the lights on."* That's why the tutorial says *"We're stuck here. Forever. Just hitting balls."* It's a joke, and it isn't.

### The mist (the rule of the world)

The mist isn't weather, it's **forgetting**. Grass forgets it's a fairway if nobody plays to it. A ball landing on it is a reminder. So the mist sits exactly one step past the farthest ball anyone has ever hit, and every new personal best pushes it back.

This is already how the harvest fog works in code (`GameState.revealed_yards()`). v5 just says it out loud and puts things inside it.

## Tone

- Ghibli-adjacent: quiet, warm, a little melancholy, never scary.
- The Range Rat is soft-spoken and dry ("Allegedly."). Short lines. No exclamation-mark spam.
- Barley speaks only through pencil notes: warm, cryptic, a bit smug.
- Ratina is brighter, chattier, and slightly competitive.

## Characters

| Character | Role in story | Mechanic |
|---|---|---|
| **Range Rat** | Stayed behind to keep the range. Narrator of every find. | Player |
| **Barley** | The old pro. Walked into the mist to wake the course. Leaves scorecards. | Never seen; notes in the Journal |
| **Ratina** | Came looking for Mistmeadow years ago, got turned around in the mist, and has been sitting on her bag at 64 yd waiting for it to lift. She's been counting your shots. | Found → second bay + her upgrade subtree |
| **Rattlings** | Shy gnome-rats who lived in the course rough and hid in burrows when the mist came. Love shiny round things. | Burrow found → ball-fetching crew + subtree |

## Arc

1. **Act I · The Range (0–100 yd).** Routine. A torn scorecard in Barley's pencil hints at Hole 1, 400 yards out. Then someone in the mist says "you slice": it's Ratina. The rusted range bell only rings if you *hit* it.
2. **Act II · The Mist (100–250 yd).** The range turns into a place. A buried picker cart, a burrow of Rattlings, Barley's old wooden spoon stuck in the turf, a stone lantern, and a birdhouse. The second note explains the mist.
3. **Act III · The Old Course (250–400 yd).** It stops being a range: a persimmon driver, a footbridge over a creek no one remembers, then a carved sign, **HOLE 1 · PAR 4 · 385 YDS**. The third note says Barley can hear your balls landing.
4. **Finale (~400 yd).** The first green, Barley's cap on the flagstick, and his last note. One ball. The mist lifts off the entire course.

## Script

Lines live in code at `scripts/game/story/story_script.gd`. Keep this table and that file in sync. Speaker `rat` uses the rat portrait; `ratina` uses Ratina's.

### Barley's notes (Journal)

| Key | Text |
|---|---|
| `note_1` | *HOLE 1 · PAR 4 · 385 YDS. Practice the swing you'll need, not the one you have. —B* |
| `note_2` | *The mist isn't weather. It's forgetting. Grass forgets it's a fairway if nobody plays to it. Every ball is a reminder. —B* |
| `note_3` | *Left the range to you. Knew you'd grumble. Knew you'd stay. Keep swinging. I can hear them landing from here. —B* |
| `note_tee` | *(carved)* *HOLE 1 · PAR 4 · 385 YDS. Tee it high. —B* |
| `note_last` | *Took you long enough. Green's awake. Went on ahead to wake up the second. See you at the turn. Hole 1: your honor. —B* |

### Find dialogue

| Find | Lines |
|---|---|
| **Torn Scorecard** | rat: "A scorecard. Barley's pencil." · rat: "He always wrote in pencil. Said it made lying easier." · rat: "Hole 1. Three hundred eighty-five yards. ...There's no Hole 1. There's just mist." |
| **Someone's Golf Bag** | ratina: "Oh! You can SEE me?" · ratina: "I've been sitting here for ages. You slice, by the way." · rat: "...Do you want a bay? We have bays." · ratina: "Do I want a bay. Yes. Obviously." |
| **Range Bell** (clicked, not rung) | rat: "The old range bell. Rusted stiff." · rat: "Barley used to ring it for last bucket. A good shot might knock it loose." |
| **Range Bell** (rung) | rat: "...DONNNG." · rat: "Last bucket. Except it isn't. Feels quicker out here now." |
| **Picker Cart** | rat: "The old ball-picker cart. Half buried." · rat: "Still has a basket on it. That's more balls per bucket." |
| **Rattling Burrow** | rat: "A burrow. Something's blinking at me." · rat: "Rattlings. They lived in the rough before the mist." · rat: "They like shiny round things. We have a lot of shiny round things." |
| **Scorecard, again** | rat: "Another one." · rat: "The mist isn't weather. ...Huh." · rat: "So every ball I've hit was... a reminder." |
| **Barley's Spoon** | rat: "Barley's old spoon. Wooden head. Stuck in the turf like a flag." · rat: "He said it flew farther than it had any right to. He was right." |
| **Stone Lantern** | rat: "A stone lantern. There used to be two of these at the first tee." · rat: "It still has a little light in it. The balls near it look... golden." |
| **Birdhouse** (clicked, not knocked) | rat: "A birdhouse. Empty. Maybe somebody's asleep in there." · rat: "Knock with a ball. Gently. Ish." |
| **Birdhouse** (knocked) | rat: "Oh. Oh, that's a lot of birds." · rat: "Some of them are shiny. Keep an eye out." |
| **Scorecard, third** | rat: "Third one." · rat: "...He can hear them landing." · rat: "Okay, Barley. Louder, then." |
| **Persimmon Driver** | rat: "His driver. The persimmon one. He never let anyone touch it." · rat: "Sorry, Barley. Finders keepers." |
| **Footbridge** | rat: "A footbridge. There's a creek under the mist." · rat: "I didn't know there was a creek. That means we're off the range." · rat: "We're on the course." |
| **Hole 1 Tee Sign** | rat: "Hole one. Par four. Three eighty-five." · rat: "'Tee it high.' ...Fine." · rat: "The green's out there. One more good one." |
| **The First Green** | rat: "A flag. A real flag. On a real green." · rat: "His cap's on the flagstick. He never leaves the cap." · rat: "There's a note." · *(note_last)* · rat: "...Your honor." · rat: "Okay. One ball." |

### Target-find hint (shown when a new find is revealed)

rat: "The mist pulled back. Something's out there, past the {yards} sign."

### Postgame welcome-back lines

- "Course is awake. Range is still ours."
- "Somebody has to keep the lights on. Might as well be us."
- "Ratina says she heard a 'FORE!' past the second green."
- "Hit a few. Barley can hear them."
