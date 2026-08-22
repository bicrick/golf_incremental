# Golf Incremental — Documentation

**Design source of truth for this project.** Implementation checklists live in Cursor plans; all game design, economy rules, and agent boundaries live here.

## One-liner

A cozy, Miyazaki-adjacent pixel art golf incremental on a driving range, rendered in **real 3D with billboarded pixel-art sprites**: one-hand rhythm swings, multiplicative upgrades, calm atmosphere with jackpot spikes — Fortune Mill mechanics, Ghibli soul. Built with **Godot 4 + GDScript**.

## Doc map

| Doc | Read if you are working on… |
|-----|----------------------------|
| **[v2/ README](v2/README.md)** | **v2 redesign — bucket, pickup, contact swing, range tycoon (cash tree + late OP nodes; current progression)** |
| **[v3/ README](v3/README.md)** | **v3 polish — economy tuning, long-tail progression, crew (start here for balance)** |
| **[v4/ README](v4/README.md)** | **v4 redesign — orthographic camera, buildable grid, physical crew bays (design phase)** |
| **[v7/ README](v7/README.md)** | **Superseded — prestige / cheese experiment (folded into late cash tree)** |
| [design/00-vision.md](design/00-vision.md) | Project pillars, tone, inspiration, north star |
| [design/01-core-loop.md](design/01-core-loop.md) | Rhythm swing, timing tiers, swing cadence |
| [design/02-world-and-range.md](design/02-world-and-range.md) | Real-3D range world, camera, targets, time-of-day |
| [design/03-economy.md](design/03-economy.md) | Payout formula, cost curves, currency, milestones |
| [design/04-upgrade-tree.md](design/04-upgrade-tree.md) | All 8 upgrade branches, outfit stat pieces |
| [design/05-progression.md](design/05-progression.md) | v1 / v1.5 / v2 scope, session arcs |
| [design/06-characters.md](design/06-characters.md) | Golfer, golf friend (v2), sprite layers |
| [design/07-art-and-atmosphere.md](design/07-art-and-atmosphere.md) | Palette, parallax art, calm default, jackpot spikes |
| [technical/00-stack.md](technical/00-stack.md) | Godot 4, GDScript, export, Steam path |
| [technical/01-architecture.md](technical/01-architecture.md) | Scenes, autoloads, 3D range scene tree |
| [technical/02-data-model.md](technical/02-data-model.md) | GDScript types, signals, save format |
| [technical/03-agent-workstreams.md](technical/03-agent-workstreams.md) | Parallel development splits |
| [specs/v1-acceptance.md](specs/v1-acceptance.md) | Testable v1 done criteria |

## Agent rules (non-negotiable)

1. **Data-driven upgrades** — definitions in `scripts/game/upgrades/`, not hardcoded in scenes.
2. **Multiplicative economy** — payout stacks across branches; see [03-economy.md](design/03-economy.md).
3. **One-hand rhythm** — single click per swing; no drag, no multi-bar golf.
4. **Real 3D world, pixel-art billboards** — the range is a real `Node3D`/`Camera3D` scene (world unit = 1 yard, tee at origin, `-Z` down the fairway); depth, scale, and vanishing-point convergence come from Camera3D projection, not hand-rolled perspective math. Golfer/ball/litter stay pixel art via `AnimatedSprite3D`/`Sprite3D` billboards.
5. **Calm default, jackpot spikes** — see [07-art-and-atmosphere.md](design/07-art-and-atmosphere.md).
6. **Contract-first parallel work** — freeze autoloads + `PlayerStats` + `EventBus` before splitting agents; see [03-agent-workstreams.md](technical/03-agent-workstreams.md).
7. **Do not edit Cursor plan files** — this `docs/` folder is authoritative for design.

## Reading order for new contributors

1. [00-vision.md](design/00-vision.md)
2. [02-world-and-range.md](design/02-world-and-range.md) — real-3D world model
3. [01-core-loop.md](design/01-core-loop.md)
4. [03-economy.md](design/03-economy.md)
5. [technical/02-data-model.md](technical/02-data-model.md)
6. Your workstream in [technical/03-agent-workstreams.md](technical/03-agent-workstreams.md)
7. [specs/v1-acceptance.md](specs/v1-acceptance.md) before marking v1 done

## Third-party assets

- **Dinky Tiny Golf** — Mike Moore ([pixelbitsnbytes.com](https://www.pixelbitsnbytes.com)), free commercial use with credit. See [`assets/imported/CREDITS.txt`](../assets/imported/CREDITS.txt) and [`assets/imported/dinky_tiny_golf/Dinky_Tiny_Golf_Free/license.txt`](../assets/imported/dinky_tiny_golf/Dinky_Tiny_Golf_Free/license.txt).
- **Free Basic Pixel Art UI for RPG** — Craftpix.net (#255216), freebie license. See [`assets/imported/CREDITS.txt`](../assets/imported/CREDITS.txt) and [`assets/imported/rpg_ui_kit/LICENSE.txt`](../assets/imported/rpg_ui_kit/LICENSE.txt).

## Implementation status

| Phase | Scope | Doc |
|-------|-------|-----|
| v1 | Rhythm + 3 upgrade branches + parallax + save | [v1-acceptance.md](specs/v1-acceptance.md) |
| v1.5 | Bullseyes on range, outfit sprite layers | [05-progression.md](design/05-progression.md) |
| **v2 redesign** | **Bucket, pickup, contact swing, range tycoon** | **[v2/README.md](v2/README.md)** |
| **v3 polish** | **Economy rebalance, milestones, crew, range amenities** | **[v3/README.md](v3/README.md)** |
| **v4 redesign (design phase)** | **Orthographic camera, buildable grid strip, physical crew bays** | **[v4/README.md](v4/README.md)** |
| ~~v7 prestige~~ | ~~$500 prestige, cheese, OP tab~~ — **superseded;** OP nodes live on the late cash tree | [v7/README.md](v7/README.md) (history) |
| v2 (legacy note) | Golf friend passive income | superseded by [v2/05-characters-and-crew.md](v2/05-characters-and-crew.md) |
| Later | GodotSteam, Steam release | [00-stack.md](technical/00-stack.md) |
