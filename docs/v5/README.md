# Golf Incremental — v5 Design: *The Range at the Edge of the Mist*

**Design source of truth for story, discovery, and the ending.** v2/v3/v4 remain authoritative for the core loop (bucket → contact swing → harvest), economy formulas, and the range world. v5 layers a **story told through the harvest fog**, a **finds system** that turns distance into exploration, **story-gated upgrades/crew**, and a **definitive ending** with an open postgame.

## One-liner

Every ball you hit farther pushes the mist back a little — and the mist has been hiding a golf course, a lost friend's bag, a burrow full of shy Rattlings, and the old Pro's scorecards. Hit your way to the first green, take one last shot, and walk off the range.

## Doc map

| Doc | Read if you are working on… |
|-----|----------------------------|
| [01-story.md](01-story.md) | Premise, characters, tone, the full script (every line) |
| [02-finds.md](02-finds.md) | Finds catalog: yardage, kind, reward, dialogue key, sprite |
| [03-systems.md](03-systems.md) | Code map: `StoryFinds`, `GameState.story_*`, save v6, fog props, dialogue, story gates |
| [04-finale.md](04-finale.md) | The last ball, ending overlay, credits, postgame |
| [05-upgrade-menu.md](05-upgrade-menu.md) | Upgrade menu aesthetic refresh |
| [06-balance.md](06-balance.md) | Economy rebalance (measured) + crew refactor (Ratina's flag, Rattling leftovers) |

## Pillars (v5 additions)

1. **Distance is exploration.** The fog line *is* the progress bar. Nothing new appears on the tree without something new appearing on the range first.
2. **Discoveries, not spreadsheet rows.** Every story gate is an object you can click in the world, with a line of dialogue and a visible consequence.
3. **Cozy mystery, never dread.** The mist is the course *asleep* — grass forgets it's a fairway when nobody plays to it. No horror, no loss states.
4. **A real ending, then keep playing.** Credits roll once; the range (and numbers) keep going afterward.
5. **Reuse the loop.** Finds are clicked in harvest mode with the same pointer as balls and birds. Target finds are triggered by *landing* balls, so accuracy finally matters.

## Acts at a glance

| Act | Fog line (max carry) | Beats |
|---|---|---|
| **I · The Range** | 0 – 100 yd | First scorecard; **Ratina** found sitting on her bag; ring the old bell |
| **II · The Mist** | 100 – 250 yd | Picker cart; **Rattling burrow**; the Pro's spoon; stone lantern; birdhouse |
| **III · The Old Course** | 250 – 400 yd | Persimmon driver; footbridge; the Hole 1 tee sign |
| **Finale** | ~400 yd | **The first green.** One ball. The mist lifts. |

## Implementation status

| Piece | Status |
|---|---|
| Story + finds docs | ✅ this folder |
| Finds system (data, save, fog props, harvest click, target landings) | ✅ `scripts/game/story/`, `scripts/range/story_finds_director.gd` |
| Story dialogue (rat + Ratina portraits) + Journal | ✅ `scripts/ui/story_dialogue.gd`, `scripts/ui/story_journal.gd` |
| Story-gated upgrades; crew reachable via finds | ✅ `scripts/game/upgrades/graph.gd` |
| Finale + ending + postgame | ✅ `scripts/ui/story_ending.gd` |
| Upgrade menu refresh | ✅ see [05-upgrade-menu.md](05-upgrade-menu.md) |
