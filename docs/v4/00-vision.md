# v4 Vision

## Elevator pitch

The range stops being a backdrop you upgrade through menus and becomes a small **lot you build out** — click an empty bay slot, hire a rat, watch it start swinging next to you. Same cozy contact-swing loop, same bucket/pickup/economy spine, but the "superintendent" fantasy becomes literal: you can *see* the range fill up with hitters as you grow, RollerCoaster Tycoon-style, in miniature.

## Creative north star

**Keep v2/v3's soul, make the crew layer physical.**

| Pillar | v4 meaning |
|--------|------------|
| **Superintendent fantasy, made literal** | Hiring crew used to be a stat unlock; now it's placing a visible bay on a grid. The range visibly grows. |
| **Contact swing stays king** | The one-hand timing swing is still the only way to earn actively. v4 adds more *places* to do it, not a new way to do it. |
| **Small, curated roster — not a park sim** | The buildable strip holds a small handful of bays (player + a few crew), not a sprawling park. This is a range, not a theme park. |
| **Calm default, jackpot spikes** | Unchanged from [design/07-art-and-atmosphere.md](../design/07-art-and-atmosphere.md) — multiple simultaneous bays should still read as calm ambience, not visual noise. |
| **Wayward shots are charm, not chaos** | Existing lateral scatter can drift a shot toward a neighboring lane. That's a feature — a driving range where every ball behaves identically down a rail would look sterile. |
| **Static crew, no sim-wandering** | Rats are stationary in their assigned bay, animated in place — not Sims-style pathing. Keeps scope and performance sane. |

## What we are not

- Not a growing/expanding world — the range is full-size (50×300 yd grid) from day one; only a small near-edge strip is buildable
- Not a general park-builder — no placeable pickers, amenities, decorations, or paths in v4 scope (those stay abstract upgrade-tree purchases)
- Not Sims-style autonomy — no wandering, no needs, no pathing between cells
- Not a rewrite of the swing/economy loop — v2/v3 mechanics and balance targets carry forward unchanged
- Not a second codebase — same repo, in-place migration (see [05-migration-and-phasing.md](05-migration-and-phasing.md))
- Not purple-heavy UI or a neon casino aesthetic (unchanged house rule)

## Player identity

Still the **range rat superintendent** from v2/v3 — you hit when the bucket allows, pick up when it's empty, spend on clubs and range upgrades. v4 adds: you also decide *where* your hired crew stands, one click at a time, in a small strip you can watch fill up.

## Design decisions (resolved / in progress)

| Topic | Status | Decision |
|-------|--------|----------|
| Camera angle | **Locked** | True 2:1 dimetric (`-26.565° / 45° / 0°`) in `V4CameraConfig.LOCKED_BASIS`; position/size tunable per scene. PixelLab-compatible. See [01-camera-and-world.md](01-camera-and-world.md). |
| Grid scope | **Resolved** | Full range: 25×150 cells (50×300 yd). Buildable bays: near-edge row only. See [02-grid-and-placement.md](02-grid-and-placement.md). |
| Depth cue under ortho | **Resolved (baseline)** | Flat sprite size; depth via grid position. Revisit if playtest fails. |
| Atomic cell | **Locked** | `player_bay_cell.tscn` — camera + sprite layout. See [03-crew-and-bays.md](03-crew-and-bays.md). |
| Buildable strip capacity | Open | Planning target 3–6 bays including player; confirm during economy pass. |
| Context-menu contents | Open | Click empty cell → menu; exact crew types TBD. |

## Related docs

- Camera/world: [01-camera-and-world.md](01-camera-and-world.md)
- Grid/placement: [02-grid-and-placement.md](02-grid-and-placement.md)
- Atomic cell: [03-crew-and-bays.md](03-crew-and-bays.md)
- v2 core loop (unchanged): [../v2/01-core-loop.md](../v2/01-core-loop.md)
- v3 economy pacing (unchanged): [../v3/findings/economy-progression-findings.md](../v3/findings/economy-progression-findings.md)
