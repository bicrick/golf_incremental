# Range Rat — Documentation

**Design source of truth.** The current game is v8, *The Longest Hole*: [`v8/README.md`](v8/README.md).

## One-liner

A short pixel-art golf incremental. A rat who's hit a million range balls follows a missing friend across five driving ranges, from dawn to the next sunrise, to play one real hole. About 25 minutes, with a real ending.

## Doc map

| Doc | Read if you are working on… |
|-----|----------------------------|
| [v8/README.md](v8/README.md) | Everything: pitch, loop, the five ranges, story, upgrades, economy, look & feel, controls, code map |

Earlier designs (v1–v7: the bucket/harvest loop, upgrade tree, crew, isometric build view, prestige, mist finds) were retired in the v8 rebuild. They're in git history if you need them.

## Rules

1. **Data-driven.** Ranges, greens, hazards, keepsakes and upgrades live in `scripts/tour/tour_data.gd`; every line of dialogue lives in `scripts/tour/tour_story.gd`; per-range looks live in `scripts/tour/tour_looks.gd`. Scenes don't hard-code any of it.
2. **One math path.** Shot and money math live in `scripts/tour/tour_physics.gd`, which the game, the pacing sim and the autoplayer all share.
3. **Crisp pixels.** The screen is 480×270. Anything that must read (flags, balls, reticle, rat, text) is drawn in 2D at 1×. Backdrops are painted at native width by `tools/art/`.
4. **Verify before claiming done.** See [`../AGENTS.md`](../AGENTS.md).

## Third-party assets

- **Cuelume** UI cues: `assets/audio/sfx/ui/cuelume/LICENSE-cuelume.txt`.
- **Mixkit** golf hit sounds: `assets/audio/sfx/golf/`.
- Press Start 2P font (OFL): `assets/fonts/`.
