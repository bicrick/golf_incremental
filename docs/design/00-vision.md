# Vision

## Elevator pitch

Hit golf balls on a cozy driving range to the rhythm of the beat. Earn money, buy upgrades across a wide tree, watch numbers explode — all in a calm, Miyazaki-adjacent pixel world that goes **nuts** only when you hit it big.

## Creative north star

**Fortune Mill for mechanics. Ghibli for soul.**

| Pillar | Meaning |
|--------|---------|
| **One-hand simplicity** | Single click per swing. Playable with mouse only, like Fortune Mill. |
| **Rhythm, not reflex hell** | Fixed slow BPM (~60–72). Progression widens timing windows, not speed. |
| **Wide upgrade tree** | Many parallel branches that **multiply** together — always 3–5 affordable next buys. |
| **Calm default** | Pastoral range, wind, soft ambient audio, gentle feedback most of the time. |
| **Jackpot spikes** | Bullseyes, crits, combo milestones → brief MONEY MONEY MONEY stim, then back to calm. |
| **Exponential forever** | Costs and payouts scale so upgrades never truly "end." |
| **Parallax 2.5D** | Layered 2D sprites simulate depth toward the horizon — not flat canvas, not full 3D. |

## What we are not

- Constant casino / slot-machine noise as baseline
- Horror or dread (unlike Fortune Mill's tonal edges)
- Purple-heavy palettes or neon arcade aesthetic
- Complex multi-click golf (three-bar power/accuracy)
- Flat single-plane 2D with no depth illusion

## Engine

**Godot 4 + GDScript** — native parallax, pixel art, desktop export, and Steam path via GodotSteam.

## Inspiration

### Mechanics: Fortune Mill (Lavaflame2)

- Interconnected incremental systems with multiplicative synergies
- Simple inputs, absurd late-game numbers
- Named unlocks that feel like discoveries, not spreadsheet rows
- One-hand, low-friction play sessions

### Atmosphere: Miyazaki / Ghibli-adjacent

- Warm, hand-crafted pixel art with limited palettes per scene
- Nature always alive: clouds, grass sway, small details (birds, flags)
- Nostalgic, pastoral, quietly magical — a range at the edge of a meadow
- Contrast: serenity makes jackpot moments hit harder

## Platform north star

1. **v1:** Playable desktop build (Godot Editor F5; export optional)
2. **v1.5+:** Visual polish, bullseyes, outfits, time-of-day
3. **v2:** Passive golf friend automation
4. **Release:** Steam via Godot native export + GodotSteam; optional itch.io HTML5 demo

## Target player experience

> "I open the game, hear wind and soft music, tap on the beat, watch my ball fly farther each session. Sometimes I nail a perfect combo and the screen erupts with gold — then it settles back to peaceful. I always have another upgrade to chase."

## Success criteria (high level)

- Core loop fun for 20+ minutes without new features
- Numbers feel exponential by end of first session
- Atmosphere reads as cozy, not arcade — except deliberate jackpot spikes
- Codebase supports parallel agent work on rhythm, economy, UI, and platform layers

## Related docs

- Core mechanics: [01-core-loop.md](01-core-loop.md)
- Feel and juice: [07-art-and-atmosphere.md](07-art-and-atmosphere.md)
- Scope by phase: [05-progression.md](05-progression.md)
