# Range Rat v8 — *The Longest Hole*

**Design source of truth for the v8 rebuild.** v8 is a new game built from the ground up on the same idea (a rat hitting balls on a driving range). It replaces the v2–v5 loop, the upgrade tree, the crew and the mist-finds story. The old code stays in the repo but the game boots into v8 (`scenes/tour/tour_main.tscn`).

## Pitch

> Range Rat has hit a million balls and never once played a hole.

At dawn, Ratina's bag is sitting on the mat with a note. She took old Barley's scorecard: five holes, five ranges, one day. The last one is the **Longest Hole**, which tees off at the edge of the world at sunrise. She's going to play it, and she wants you there. You follow her pink-ribbon flags across five ranges, from dawn, through a whole day and night, to the next sunrise.

**One run takes about 25 minutes** (target 20–30) and has a real ending. Each range is a new place with its own song, its own backdrop and one new twist on the swing.

## Pillars

1. **Every shot pays now.** Money lands with the ball, on screen, with a sound. There is no waiting on a harvest to get paid.
2. **Aim for something.** Every range has greens at set distances and a flag to reach. Distance matters because there's a target out there, not because a number goes up.
3. **Every range is new.** Each range brings a new place, time of day, song, hazard and mechanic. A range is about 5 minutes, which is short enough that nothing gets stale.
4. **Short and finished.** 25 minutes, one story, credits, then a free-play postgame.
5. **Crisp pixels.** Backdrops are drawn at the game's native 480×270, in 2D parallax layers behind a 3D ground. There are no scaled posters and no clumpy sprite fog. Mist is a shader.

## The loop (one bucket ≈ 30–45 s)

1. **Swing** (strike view, behind the rat). Hold Space or the mouse and let go on the contact frame. The ring around the ball closes; let go when it meets the ball.
   - Timing sets the tier (Perfect, Great, Good, Okay, Bad, Miss), and the tier sets power.
   - Timing also sets **direction**, like real golf. Too early pulls the ball left, too late pushes it right, and a Perfect goes straight. This is how you aim, and on the cliffs it's how you fight the wind.
2. **Watch it fly.** The camera eases up with the ball. On landing, a yardage tag pops at the spot and the pay pops with it.
3. **Greens.** Every range has 3–4 greens at set distances. A ball that stops on a green pays **×Green**. Stopping within 2 yd of the pin is an **ACE** (×10, fireworks). The first ball onto each green pays a one-time *first-green* bonus and ticks a star.
4. **Ratina's flag.** Each range's last green has her pink-ribbon flag on it. It's out of reach when you arrive. Land on it and you get her note, a new club, and the road to the next range.
5. **Sweep.** When the bucket is empty, the view drops to top-down and your picker cart follows the mouse (or WASD). Balls inside its radius get sucked in. Each pickup refills the bucket, and a fast chain pays a little tip that grows (+$ ×chain) with rising plinks. **Keepsakes** (two per range, Barley's old things) lie in the rough and only show up in the sweep. Space ends the sweep: leftovers are scooped up automatically, with no tip.
6. **Shop** (Tab/E, anytime). A compact card list; one purchase should land every ~20–30 s.

## The five ranges

| # | Range | Time / song | Twist | Ratina's flag |
|---|---|---|---|---|
| I | **Barley's Range**: a home meadow with pines and a white barn | Dawn · *Sunrise*, *Early Riser* | Just the basics. Ground mist at dawn. | 138 yd |
| II | **Saltwind Cliffs**: a fairway on sea cliffs, with a lighthouse and gulls | Late morning · *Midday*, *Main Theme* | **Wind** (gusts: tail, head, cross) + **the sea** (a ball that lands in water is lost; the flag sits on an island green) | 212 yd |
| III | **Redrock Mesa**: red strata, cacti and a canyon | Dusk · *Dusk* | **Roll** (hardpan; greens are judged where the ball stops) + **the canyon** (carry it or lose it) | 300 yd |
| IV | **Frostpine**: snowy pines, aurora and lanterns | Night · *Night*, *Midnight* | **Dark.** Lantern greens light up when hit, and every lit lantern adds +pay for the range. Light all four and Ratina's flag appears. Snow means no roll. | 400 yd |
| V | **The Edge**: above the clouds before dawn | Small hours · *Final* → *Sunrise* | **The Longest Hole.** Warm up until it's in reach, then land Barley's ball on it. Misses are free. | 610 yd |

Every range keeps its own greens, stars and keepsakes. Clubs, upgrades and money carry over. After the ending, the **Map** lets you go back to any range.

## Story

The story is told in short dialogue boxes with portraits: the Rat (`rat-speaking-sheet`), Ratina (`ratina-waiting-sheet`), and notes (paper portrait). There is no wall of text; every beat is 1–4 lines. The full script is in `scripts/tour/tour_story.gd`, and every line is quoted here.

**Theme.** A *range rat* is someone who lives at the driving range and never goes out on the course. The ending is the rat playing a real hole for the first time, with a friend.

**Barley** ran the range for forty years. He retired to the coast and left his scorecard on the counter: five holes, and the last one blank except *"Hole 5 — play it with somebody."*

- **Opening (I, dawn).** Ratina's bag is on the mat.
  Note: *"Rat — I took Barley's old scorecard. Five holes, five ranges, one day. The last is the Longest Hole. It tees off at the edge of the world when the sun comes up. You've hit a million balls here and never once played a hole. Come play this one with me. Follow my pink flags. —R"*
  Rat: *"She knows I don't leave the range."* · *"...One bucket at a time, then."*
- **I cleared.** Note on the flag: *"Told you you could reach it. Next: Saltwind Cliffs. The wind there always blows toward the sea. —R"* Reward: **Barley's Spoon** (+25% carry).
- **II arrival.** *"Salt in the air. The sea eats golf balls here."* Wind and water tutorial lines.
- **II cleared (island green).** *"Barley played this in a gale in '79 and wrote KEEP IT LOW in the margin. I did not keep it low. Lost six balls. Next is the Mesa. The ground is hard as a skillet, so let it roll. —R"* Reward: **Persimmon Driver** (+30% carry).
- **III arrival.** *"Everything out here is red. Even the ground's hot."*
- **III cleared (far mesa).** *"Barley's card says: Hole 3, the canyon. Carry it or cry. I carried it on the ninth try. It's getting dark, and I'm heading up the mountain. Bring a light. —R"* Reward: **Barley's Lantern** (the Frostpine lanterns can be lit).
- **IV arrival.** *"Can't see past my own nose."* · *"Those lanterns... if I could light them."*
- **IV cleared.** *"The last hole on Barley's card is blank. No yardage, no par. Just: play it with somebody. I'm at the top. Hurry. It's almost morning. —R"* Reward: **Barley's Ball**.
- **V arrival.** Ratina is on the tee (her waiting sprite).
  Ratina: *"You came."* · Rat: *"You took my scorecard."* · Ratina: *"Barley's scorecard. He said the green on the Longest Hole is wherever the sun comes up. Nobody's ever reached it."* · Rat: *"Nobody's ever tried from a range."* · Ratina: *"It's not a range. It's a hole. You don't get a bucket. You get one ball. ...Warm up first. I'll wait."*
- **The shot.** One ball, with the sunrise behind the green. A Great or better carries it. Anything less, and Ratina says: *"Again. Nobody counts the first one."*
- **Ending.** The ball drops on the green as the sun comes up behind it.
  Ratina: *"What's par on the Longest Hole?"* · Rat: *"Whatever it took to get here."* · Ratina: *"Then we made par."*
  Then **Barley's scorecard**, filled in with the swings you took on each range and signed *Rat & Ratina*. Then the logo, credits and **Keep swinging** (postgame, with the Map open).

**Keepsakes** (optional lore, found while sweeping; each gives a small permanent bonus):

| Range | Keepsake | Line | Bonus |
|---|---|---|---|
| I | Carved tee "B." | *"Barley whittled his own tees. Said store tees had no manners."* | +5% pay |
| I | Barn key | *"The barn's where he kept the good balls. It's empty now."* | +1 ball |
| II | Gull feather | *"Barley said gulls are just rats that learned to fly."* | +5% carry |
| II | Message in a bottle | *"'Keep it low.' —B. He wrote it everywhere."* | −25% crosswind drift |
| III | Rattlesnake rattle | *"Hollow. He used it to scare crows off the greens."* | +5% pay |
| III | Postcard from the coast | *"'Retired. The fishing's terrible. Who's running my range?' —B."* | +10% roll |
| IV | Mitten | *"Pink. Ratina's. She was here not long ago."* | wider Perfect window |
| IV | Thermos | *"Still warm. Cocoa."* | +1 ball |
| V | Barley's cap | *"It still smells like cut grass."* | +5% carry |
| V | Old photo | *"Barley, Ratina and you, all younger, on the range. You were holding a bucket."* | +10% pay |

## Upgrades (the Pro Shop)

All upgrades carry across ranges. Venue upgrades appear when you reach their range. Costs are `base × growth^level`.

| Id | Name | Effect/level | Max | Shows |
|---|---|---|---|---|
| power | Club Speed | +5% reach | 60 | start |
| fee | Range Fee | +50% base pay (additive) | 60 | start |
| bucket | Bigger Bucket | +2 balls | 6 | start |
| sweet | Sweet Spot | +12% timing windows | 6 | 1st upgrade bought |
| greens | Green Reader | +0.5× green mult | 6 | first green hit |
| streak | Hot Streak | +2 streak cap (Great+ in a row, +10% each) | 5 | 2 stars |
| golden | Golden Balls | +2% chance (×5 pay) | 8 | reached range II |
| cart | Picker Cart | +20% sweep radius and speed, longer tip chains | 6 | first sweep |
| wind | Wind Reader | shows the wind landing, aims into it, −15% drift, +tailwind | 5 | reached range II |
| roll | Run-Up | +20% roll, shows the roll, rolled yards pay double | 5 | reached range III |
| oil | Lamp Oil | +10% per lit lantern (base +15% each) | 5 | reached range IV |

Barley's things are story rewards, not purchases: **Spoon** (+6% reach) → **Persimmon Driver** (+6% reach) → **Lantern** (the Frostpine lanterns can be lit) → **Barley's Ball** (+5% reach, for the Longest Hole).

## Economy (tuned with `tools/tour_autoplay.gd` and `tools/sim_tour_pacing.gd`)

All of it lives in `scripts/tour/tour_physics.gd` and `tour_data.gd`.

- **Reach** (the longest a Perfect carries, and the aim cap) = `92 × 1.05^ClubSpeed × club rewards × keepsakes`.
- **Where it lands.** A Perfect lands within ~2.5 yd of the aim point at any distance. Worse tiers come up short (`[1, .965, .91, .82, .66, .38]` of the aim) and start off line by `[—, 1.4°, 3.2°, 5.8°, 9.5°, 15°]`, left if you were early and right if you were late. Wind adds carry and drift, and roll adds `range roll × (1 + Run-Up)`.
- **Pay** = `(0.05 + 0.0025·yards) × (1 + 0.5·Range Fee) × range pay × tier [1.5, 1.2, 1, .8, .55, .3] × streak × green (×3 +0.5/level) × ace (×10, ≤0.7 yd) × golden (×5) × lanterns`.
- **First ball on a green** pays a one-time bonus (4 balls' worth ×green) and earns a star.
- **Range pay** multipliers are 1 / 3.6 / 17 / 9 / 30. Frostpine is low because its lanterns multiply pay.
- **Costs** = `base × growth^level`. Club Speed and Range Fee are cheap and steep (×1.35 / ×1.4); the rest are few-level perks (×2.3–2.4).
- **Target:** ~25 min for a steady player (autoplayer at ~2 s per swing: 20–30 min). The first range takes about 3–5 minutes.

## Look & feel

- **Backdrops.** Each range has 3–4 parallax layers (sky, far, mid, near) drawn procedurally at 480 px wide by `tools/art/draw_tour_backdrops.py`. The horizon row matches the 3D camera's horizon exactly. Layers drift a little when the camera eases up with the ball.
- **Ground.** One shader (`tour_ground.gdshader`) with per-range palette uniforms: mown stripes, fairway, rough, outer ground, hazards (sea, canyon), and a soft distance haze in the range's sky color.
- **Mist** (`tour_mist.gdshader`). There are no sprites. Low, translucent veils float just above the ground: fbm noise, posterized into 3 alpha steps, with Bayer dithering, a drift, and a soft top. They always stay below eye height, so they can't cross the backdrop. Dawn at Barley's has ground mist; at The Edge they're a sea of clouds.
- **Weather.** Particles per range: pollen and butterflies (I), spray and gulls (II), dust and a tumbleweed (III), snow and aurora shimmer (IV), star motes and drifting clouds (V).
- **Travel.** Clearing a range opens *The Road*, a hand-drawn map of the five ranges with a dotted line that draws itself to the next stop, and then an arrival card.

## Controls

Space / left mouse: swing (hold and release). Tab or E: shop. M: map (after range I). J: journal. Esc: pause. In the sweep, the cart follows the mouse (or WASD / arrows) and Space finishes.

## Code map

| Path | What |
|---|---|
| `scripts/tour/tour_state.gd` (autoload `Tour`) | Run state, money, upgrades, ranges, save/load (`user://tour_save.json`) |
| `scripts/tour/audio/tour_audio.gd` (autoload `Audio`) | Music per range, sound effects, ambience; settings in `user://settings.json` |
| `scripts/tour/tour_data.gd` | Ranges, greens, hazards, keepsakes, upgrade defs |
| `scripts/tour/tour_looks.gd` | Per-range ground palette, haze, mist, props, weather |
| `scripts/tour/tour_story.gd` | Every line of dialogue |
| `scripts/tour/tour_physics.gd` | Reach, shot resolution, hazards/greens, payout |
| `scripts/tour/tour_main.gd` | Boots title → range, UI layers, input, and the story director |
| `scripts/tour/tour_world.gd` | 3D ground + camera framing, swing, flight, roll, props, sweep, wind |
| `scripts/tour/tour_overlay.gd` | Crisp 2D layer: rat, flags, reticle, balls, cart, critters, weather |
| `scripts/tour/tour_backdrop.gd` | Painted parallax sky/horizon layers |
| `scripts/tour/tour_ground.gdshader` | The whole ground: fairway, rough, sea, canyon, greens, lantern light, mist, haze |
| `scripts/tour/ui/*` | HUD, shop, dialogue, map, journal, ending, title, pause |
| `tools/art/*.py` | Backdrops, props, sprites and the map, drawn procedurally |
| `tools/verify_tour.gd` | Regression check |
| `tools/sim_tour_pacing.gd` · `tools/tour_autoplay.gd` · `tools/tour_shot.gd` | Pacing sim · real-input autoplayer · screenshots |
