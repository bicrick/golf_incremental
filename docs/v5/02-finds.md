# v5 · Finds catalog

A **find** is a story object placed on the fairway at a fixed yardage. Data lives in `scripts/game/story/story_finds.gd`, sprites in `assets/sprites/story/`.

## Lifecycle

```
HIDDEN ──fog within 36 yd──▶ SILHOUETTE ──fog passes it──▶ REVEALED ──click (harvest)──▶ FOUND
                                                               │
                                           (target kind) ──ball lands within radius──▶ TRIGGERED ──click──▶ FOUND
```

- **Hidden:** more than `STORY_SILHOUETTE_YARDS` (36) past the fog line. Not drawn.
- **Silhouette:** inside the mist bank. Drawn as a pale, fog-washed shape in harvest; not clickable. It tells you there's something to chase.
- **Revealed:** `find.yards + 2 <= GameState.revealed_yards()`. Drawn with a slow sparkle; clickable in harvest (same pointer path as golden birds). The first time a find is revealed, the rat says so on the next harvest entry.
- **Target finds** (`kind = "target"`) must first be *hit*: any ball (player or Ratina) whose rest position lands within `radius` yards triggers them via `EventBus.fairway_impact`. Clicking an untriggered target plays its hint lines.
- **Found:** reward applied, lines played, note added to the Journal. Decor finds (`persist = true`) stay on the range as set dressing; pickups (`persist = false`) vanish.

Finds are hidden in strike view until found (the strike camera has no fog). Persistent finds show in both views once found.

## Design rule: Barley's trail

Every find is something Barley left on his last walk from the range to the first green, in the order he left it, plus the two things that walk *caused* (Ratina and the Rattlings). Each find must do three jobs:

1. **Story:** it tells you something new about Barley, Ratina, or the mist.
2. **World:** persistent finds stay on the range as set dressing (and show as landmarks on the strike-view horizon). Over the run, the empty range becomes Hole 1.
3. **Play:** it changes how you play, and the change fits the object.

## Catalog

World position: `x` yards across (+ = right of tee), `yards` down range (`z = tee_z − yards`). The fairway ground ends ~390 yd from the tee, so the green sits at 382.

| # | id | yards | kind | Story beat | World change | Play change |
|---|---|---|---|---|---|---|
| 1 | `scorecard_1` | 30 | find | Barley's plan: Hole 1, 385 yd. Sets the goal. | → Journal | Nothing. It sets the goal. |
| 2 | `ratina_bag` | 54 | find | Her abandoned bag + note: Ratina followed a light into the mist and never came back. | → Journal | +1 ball/bucket (her spare balls) |
| 3 | `range_bell` | 74 | target r7 | Barley's "last bucket" bell. Ringing it = the range isn't closing. | Bell rung/shiny | Swing cooldown ×0.85; gates Quick Reset |
| 4 | `picker_cart` | 105 | find | Abandoned when the mist got thick | Cart stays | +2 balls/bucket; gates More Balls |
| 5 | `rattling_burrow` | 146 | find | They've kept Barley's **B** balls safe; they watched him pass | Burrow stays | **Rattlings join**: fetch leftovers at partial pay (first free) + subtree |
| 6 | `scorecard_2` | 168 | find | The mist rule, stated | → Journal | Nothing. It explains the mechanic. |
| 7 | `barley_spoon` | 190 | find | Stuck upright as a trail marker: "I went this way" | → your bag | Opens **Barley's Spoon** node (+3% carry/lv) |
| 8 | `stone_lantern` | 222 | find | **The light Ratina followed**: a pink ribbon on the post. | Lantern glows | +3% golden; gates Golden Balls |
| 9 | `birdhouse` | 248 | target r7 | The birds left with the mist | More (golden) birds | Golden bird chance ×2 |
| 10 | `scorecard_3` | 275 | find | "I can hear them landing." | → Journal | Nothing. It's the emotional beat. |
| 11 | `persimmon_driver` | 305 | find | Left on purpose where you'd see it | → your bag | Opens **Persimmon Driver** node (+3% carry/lv) |
| 12 | `footbridge` | 330 | find | The range ends; the course begins | Bridge + creek | Rattlings scurry ×1.3 |
| 12b | `ratina_found` | 342 | find | **Ratina**, stranded across the creek since the bridge vanished. | Joins the next bay | Tempo tips: Perfect window +6 ms |
| 13 | `tee_sign` | 356 | find | The goal, carved: "Tee it high." | Sign stays | Gates Perfect Chain |
| 14 | `first_green` | 382 | finale | Cap on the flag, last note | Green + flag | Arms **the last ball** |

## Pacing notes

- The two *target* finds sit near the centerline (|x| ≤ 2) because landing scatter is only ±3 yd. Hitting one means **controlling distance**: throttling timing to land ~74 or ~248 yd. It's a skill test that a maxed Perfect streak can't brute-force.
- Clubs open carry nodes instead of instant multipliers; instant multipliers chain-reacted through Act III (see [06-balance.md](06-balance.md)).
- Carry needed for the finale ≈ `base_yards × perfect_pop × clubs`: e.g. Raw Power 25 (105 yd) × Perfect Pop 12 (2.52) × 1.38 ≈ 365 yd on a Perfect, plus bounce runout. Ratina's shots count toward the fog line too.
