# Range Rat v9 — *Fortune Range*

**Design source of truth.** v9 replaces v8's story tour with a Fortune Mill–style incremental: rooms of simple, juicy golf minigames that feed each other, dozens of upgrades, hired helpers, and cross-room synergies, all racing to one number.

> Barley's old driving range is going under. Make **$1,000,000** and it's yours.

That line is the whole story. No dialogue trees, no forced beats.

## Pillars

1. **Dopamine first.** Every action pays instantly and loudly: numbers fly, coins burst, and jackpots shake the screen. Something new is always almost affordable.
2. **Numbers explode.** The first swing pays about $1. By the end, one swing pays thousands, and a triples roll makes $1M look small.
3. **Rooms feed rooms.** Every room has a synergy that boosts another, so the rooms work as one machine.
4. **Hire help.** Every room gets a helper that plays it for you. You watch it get busier and busier.
5. **Short.** $1M in about 30 minutes, then keep going if you like.

## Rooms

Tabs across the top (or keys **1–4**). A room unlocks when you pay for it, and **every room keeps earning while you're in another**. The tabs only choose which one you play by hand.

| Room | Unlock | The toy | Helper | What it gives the others |
|---|---|---|---|---|
| **Tee Line** | free | Hold Space (or the mouse), release when the ring closes. Balls land on a giant target painted on the fairway: rings ×1 / ×2 / ×5 and the **PIN ×15**. A miss pays ×0.2. Perfect ×2, Great ×1.3. | **Ratina**, then up to six **cousins**, swing from bays down the line. | A PIN hit drops golden putts (×5) onto the Putting Green. |
| **Putting Green** | $500 | Pachinko: click to drop a putt through the pegs into eight cups (×0.3 … ×2). A golden **JACKPOT** hole slides along the bottom: ×25 and a permanent bonus (2%, then 1.4%, 1.2%… each one a little less). | Putt Rattler drops putts. | Permanent % to everything. |
| **Scorecards** | $3,000 | Scratchers: buy a card, drag to scratch the foil hole by hole (Space scratches the next). Par ×0.1, birdie ×0.5, eagle ×2.5, **hole in one** ×12 of the price, plus a permanent +3%. About 2.7× the price back on average. | The Old Owl buys and scratches whole cards. | Every birdie or better adds Tee Line **FRENZY** (double-speed swings). |
| **19th Hole** | $25,000 | Roll the dice; pips pay. **Doubles** ×2 everything for 12 s; **boxcars** ×5 for 10 s; **snake eyes** +3% forever; with the Third Die, **triples** ×10 for 30 s. | Toad the barkeep rolls for you. | Global multipliers for every room. |

**Renovations** (Tee Line, four levels): each one is ×1.5 Tee Line income and rebuilds the range somewhere grander: Barley's Range → Saltwind Cliffs → Redrock Mesa → Frostline → The Edge. The music follows. They reuse v8's environments as visible progress.

## Upgrades

27 upgrades, listed per room in the right-hand panel. Cost = `base × growth^level`. All data lives in `scripts/fortune/fortune_data.gd`; every derived number lives in `scripts/fortune/fortune_econ.gd`.

## Economy

- **Tee Line ball** = `(1 + Ball Value) × 1.5^Renovate × ring × tier bonus × golden (×10) × global`.
- **Global** = `(1 + permanent) × active buffs` (doubles, boxcars, triples).
- **Why the value lines are additive:** an income multiplier bought with exponentially rising costs compounds with every other line. The growth exponent is roughly Σ ln(gain)/ln(cost growth), and above ~0.7 it runs away (early builds hit $1M in under a minute). Value lines add a flat amount per level instead, and the multiplicative lines are capped and steep. The big jumps come from Renovations, dice buffs and permanents.
- **Pacing** (`tools/fortune_autoplay.gd`, greedy cheapest-first buyer that saves near the goal):

| Player | $10K earned | $100K | Dice room | Buys the range |
|---|---|---|---|---|
| sharp (45 ms σ) | 3.5 min | 11.7 min | 20 min | 32 min |
| average (70 ms σ) | 3.6 min | 11.8 min | 19 min | 30.5 min |
| loose (110 ms σ) | 4.9 min | 13.6 min | 23 min | 34 min |

  About one purchase every 15 s across the run.

## Controls

| Input | Does |
|---|---|
| Space / Enter / mouse | Swing (Tee Line), drop (Green), scratch next / buy card (Scorecards), roll (19th Hole) |
| Drag | Scratch foil (Scorecards) |
| 1–4 | Rooms (buys a locked room if you can afford it) |
| Esc | Pause: volume, save & quit |

## Presentation

- 480×270. A cash counter up top with rolling digits, room tabs, and an upgrade panel on the right for the current room.
- **Tee Line** keeps v8's 3D range: over-the-shoulder camera, raised tee, giant props, painted skies, light and weather, music-reactive sway, and ball flight with tracers. Balls pop into coins where they land.
- The other rooms are 2D, painted at native resolution, with smooth motion and particle bursts.
- Buffs show as chips under the cash; jackpots get a screen flash, a shake and a fanfare.

## Code map

| Path | What |
|---|---|
| `scripts/fortune/fortune_state.gd` (autoload `Game`) | Cash, upgrades, rooms, buffs, permanent bonus, save |
| `scripts/fortune/fortune_data.gd` | Rooms and upgrades |
| `scripts/fortune/fortune_econ.gd` | Every derived number (values, rates, odds) |
| `scripts/fortune/fortune_main.gd` | Shell: tabs, cash, panel, rooms, juice |
| `scripts/fortune/rooms/*` | Tee Line, Putting Green, Scorecards, 19th Hole |
| `scripts/fortune/ui/*` | Top bar (cash, $/s, buffs, tabs, goal), upgrade panel, banner, title, ending, pause |
| `scripts/tour/*` | Reused v8 visuals: backdrop, looks, shaders, audio (autoload `Audio`), UI kit |
| `tools/fortune_autoplay.gd` | Plays every room headless; pacing report (`SKILL`, `SEED`, `SPEED`, `DWELL`) |
| `tools/fortune_shot.gd` | Screenshot harness (`ROOM`, `CASH`, `LEVELS`, `ROOMS`, `OPEN`, `SHOT_AT`, `SWING_AT`) |
