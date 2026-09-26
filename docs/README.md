# Range Rat — Documentation

**Design source of truth.** The current game is v9, *Fortune Range*: [`v9/README.md`](v9/README.md).

## One-liner

A pixel-art golf incremental. Barley's old driving range is going under: swing at a giant target, drop putts down a pachinko green, scratch scorecards and roll dice at the 19th hole until you've made $1,000,000 and the range is yours. About 30 minutes.

## Doc map

| Doc | Read if you are working on… |
|-----|----------------------------|
| [v9/README.md](v9/README.md) | Everything: rooms, upgrades, economy and pacing, presentation, controls, code map |

Earlier designs (v1–v8: the bucket/harvest loop, crew, isometric build view, prestige, the *Longest Hole* story tour) were retired. They're in git history if you need them.

## Rules

1. **Data-driven.** Rooms and upgrades live in `scripts/fortune/fortune_data.gd`; per-venue looks live in `scripts/tour/tour_looks.gd`. Scenes don't hard-code any of it.
2. **One math path.** Every derived number lives in `scripts/fortune/fortune_econ.gd`, which the game and the autoplayer share. Re-run `tools/fortune_autoplay.gd` after touching costs or payouts.
3. **Crisp pixels.** The screen is 480×270. Anything that must read (flags, balls, reticle, rat, text) is drawn in 2D at 1×. Backdrops are painted at native width by `tools/art/`.
4. **Verify before claiming done.** See [`../AGENTS.md`](../AGENTS.md).

## Third-party assets

- **Cuelume** UI cues: `assets/audio/sfx/ui/cuelume/LICENSE-cuelume.txt`.
- **Mixkit** golf hit sounds: `assets/audio/sfx/golf/`.
- Press Start 2P font (OFL): `assets/fonts/`.
