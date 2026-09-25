# v5 · Systems (code map)

| Piece | File | Notes |
|---|---|---|
| Finds catalog | `scripts/game/story/story_finds.gd` (`StoryFinds`) | id, act, yards, x, kind, sprite(s), reward, persist, radius, pixel_size. `apply_rewards` / `apply_rattling_rewards` fold rewards into stats. |
| Script | `scripts/game/story/story_script.gd` (`StoryScript`) | Notes, per-find lines, target hints, Ratina-aware extras, reveal hint, ending lines, postgame welcome lines. |
| State | `scripts/autoload/game_state.gd` | `story_found`, `story_triggered`, `story_announced`, `story_intro_seen`, `story_finale_armed`, `story_complete`, `play_time_sec`. API: `is_find_revealed/claimable`, `trigger_find`, `discover_find`, `consume_finale_ball`, `complete_story`. `revealed_yards()` returns 460 once complete. |
| Signals | `scripts/autoload/event_bus.gd` | `story_find_found`, `story_find_triggered`, `story_finale_armed`, `story_final_shot`, `story_completed`. |
| Save | `scripts/autoload/save_manager.gd` | Save **v6**. Story keys saved as id arrays; loading re-derives `ratina_unlocked` / `rattlings_unlocked` from finds. |
| World props | `scripts/range/story_finds_director.gd` | Child of `RangeView/Foreground` named `StoryFinds`. Hidden → silhouette (36 yd into the bank, fog-washed) → revealed (sparkle) → found. Target rings on the ground; `EventBus.fairway_impact` within radius triggers. Found persistent props scale up with distance in strike view (horizon landmarks). Flat green disc + flagstick for the finale. |
| Click | `RangeView._try_story_find_click` | Runs before bird / ball pickup in harvest. Emits `find_clicked(id, claimable)`. |
| Dialogue | `scripts/ui/story_dialogue.gd` | Mounted by Main at `UI/UIRoot/StoryDialogue`. Queues `[speaker, text]` lines through a second thought box. Speakers: `rat`, `ratina` (idle sheet portrait + name tag), `note` (scorecard portrait, pencil ink). Announces newly revealed finds and the first-mist intro on harvest entry. |
| Journal | `scripts/ui/story_journal.gd` | `UI/UIRoot/StoryJournal`; HUD button (appears after first find) or **J**. Lists acts, notes, rewards; hints for unfound finds by fog state; "Read the ending again" in postgame. |
| Ending | `scripts/ui/story_ending.gd` | `StoryEndingLayer/StoryEnding` (CanvasLayer 40). See [04-finale.md](04-finale.md). |
| Upgrade gates | `scripts/game/upgrades/graph.gd` | `STORY_GATES` (node → find). Ratina (`ratina_base_pay` under `base_pay`) and Rattling (`rattling_more` under `pickup`) subtrees are registered in the unified graph and **hidden until found**; other gated nodes show locked with a "Hidden in the mist (~N yd)" hint. |
| Carry | `scripts/game/economy.gd` | `yards_from_quality` now multiplies by `stats.carry_multiplier` (clubs). |
| Input blocking | `RangeView._tutorial_blocks_input` | Checks `tutorial_overlay`, `story_dialogue`, `story_ending` groups. |
| Sprites | `tools/art/draw_story_sprites.py` → `assets/sprites/story/` | Procedural pixel art (Pillow). Re-run after edits. |
| Tests | `tools/verify_story.gd` | Catalog integrity, reveal/claim, rewards, gates, save roundtrip, target landing, finale. |

Story finds only appear once the tutorial is complete.
