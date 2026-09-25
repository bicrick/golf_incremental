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

## Catalog

World position: `x` yards across (+ = right of tee), `yards` down range (`z = tee_z − yards`).

| # | id | Name | Act | yards | x | kind | persist | Reward |
|---|---|---|---|---|---|---|---|---|
| 1 | `scorecard_1` | Torn Scorecard | I | 32 | 3.5 | find | no | Journal `note_1` |
| 2 | `ratina_bag` | Someone's Golf Bag | I | 64 | −6 | find | no | **Ratina joins** (second bay + Ratina subtree) |
| 3 | `range_bell` | Range Bell | I | 92 | 2 | target r7 | yes | Swing cooldown ×0.85 |
| 4 | `picker_cart` | Buried Picker Cart | II | 118 | −8 | find | yes | +2 balls per bucket; gates **More Balls** |
| 5 | `rattling_burrow` | Burrow at the Edge | II | 146 | 11 | find | yes | **Rattlings join** (first Rattling free + subtree) |
| 6 | `scorecard_2` | Another Scorecard | II | 168 | −3 | find | no | Journal `note_2` |
| 7 | `barley_spoon` | Barley's Spoon | II | 190 | 5 | find | no | Carry ×1.15 |
| 8 | `stone_lantern` | Stone Lantern | II | 222 | −9 | find | yes | +3% golden balls; gates **Golden Balls** |
| 9 | `birdhouse` | Birdhouse | II | 248 | −1.5 | target r7 | yes | Golden bird chance ×2 |
| 10 | `scorecard_3` | A Third Scorecard | III | 275 | 4 | find | no | Journal `note_3` |
| 11 | `persimmon_driver` | Persimmon Driver | III | 305 | −4 | find | no | Carry ×1.20 |
| 12 | `footbridge` | Footbridge | III | 335 | 0 | find | yes | Pickup pay ×1.25; gates **Perfect Chain** |
| 13 | `tee_sign` | Hole 1 Tee Sign | III | 365 | −10 | find | yes | Journal `note_tee` |
| 14 | `first_green` | The First Green | Finale | 398 | 0 | finale | yes | Arms **the last ball** ([04-finale.md](04-finale.md)) |

## Pacing notes

- The two *target* finds sit near the centerline (|x| ≤ 2) because landing scatter is only ±3 yd. Hitting one means **controlling distance**: throttling timing to land ~92 or ~248 yd. It's a skill test that a maxed Perfect streak can't brute-force.
- Carry rewards (spoon ×1.15, driver ×1.20) arrive right where Raw Power's +3 yd steps start feeling slow, and they're what makes 400 yd reachable before Raw Power and Perfect Pop are both maxed.
- Carry needed for the finale ≈ `base_yards × perfect_pop × clubs`: e.g. Raw Power 25 (105 yd) × Perfect Pop 12 (2.52) × 1.38 ≈ 365 yd on a Perfect, plus bounce runout. Ratina's shots count toward the fog line too.
