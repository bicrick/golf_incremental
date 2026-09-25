# v5 · Finale, ending, postgame

1. **Find the first green** (382 yd, harvest click). The lines play; `story_finale_armed = true`.
2. The dialogue hand-off returns to the tee (`exit_harvest_early`) and guarantees at least one ball: *"One ball. Take your time."*
3. **The last ball.** In `Swing._resolve_swing`, an armed swing is floored to Great quality and at least `FINALE_CARRY_YARDS` (380), so it always reaches the green. Timing skill can't block the ending. Emits `story_final_shot`.
4. **Ending** (`StoryEnding`): waits for the flight (~3.4 s), fades in the mist, shows the four closing lines one at a time, then the title card: logo, "The End", run stats (swings, Perfects, best carry, finds, time), credits, and **Keep swinging**.
5. `GameState.complete_story()`: the mist is gone for good (`revealed_yards() = 460`), the green, flag and landmarks stay, and welcome-back lines switch to the postgame set. The Journal offers "Read the ending again".
