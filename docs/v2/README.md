# Golf Incremental — v2 Design

**Design source of truth for the v2 redesign.** v1 docs under [`docs/design/`](../design/) remain the record of what shipped first; this folder describes where the game is going.

## One-liner

You are a **range rat superintendent** restoring a busted down-the-line driving range: hit **small buckets** of balls with **contact timing**, watch every good shot **look** like real golf, **collect litter** from the fairway, and reinvest in **range upgrades**, **sweet-spot clubs**, and eventually **crew + new zones**.

## Relationship to v1

| v1 (shipped / in progress) | v2 (this doc set) |
|----------------------------|-------------------|
| Hold-to-charge + release at peak | Contact timing at downswing (frame 9) |
| Infinite tee reload | **Bucket** → strike burst → **pickup** → refill |
| Yards drive visual depth | **Visual carry floor**; yards ≠ screen depth early |
| 3 branches: Rhythm, Distance, Economy | **Range**, **Pickup**, **Sweet spot / clubs**, Economy, Crew |
| Golf friend passive swings (planned) | **Gnome / rat crew** tied to litter & range tycoon |
| Single fairway scene | Same scene first; **zones** unlock later |

Implementation is **incremental**. See [07-implementation-phases.md](07-implementation-phases.md).

## Doc map

| Doc | Read if you are working on… |
|-----|----------------------------|
| [00-vision.md](00-vision.md) | Pillars, tone, superintendent fantasy |
| [01-core-loop.md](01-core-loop.md) | Bucket, swing phases, session rhythm |
| [02-ball-flight-and-camera.md](02-ball-flight-and-camera.md) | Down-the-line scatter, visual floor, landing cluster |
| [03-economy.md](03-economy.md) | Hit vs pickup vs passive income, payout formula |
| [04-upgrade-tree.md](04-upgrade-tree.md) | v2 branches and example upgrades |
| [05-characters-and-crew.md](05-characters-and-crew.md) | Rat, gnome, gophers, rat friends |
| [06-pickup-minigame.md](06-pickup-minigame.md) | Bucket empty → collect litter (v2.0 MVP) |
| [07-implementation-phases.md](07-implementation-phases.md) | Phased rollout, migration from v1 code |
| [specs/v2-acceptance.md](specs/v2-acceptance.md) | Testable done criteria per phase |

## Reading order

1. [00-vision.md](00-vision.md)
2. [01-core-loop.md](01-core-loop.md)
3. [06-pickup-minigame.md](06-pickup-minigame.md) — **v2.0 vertical slice**
4. [02-ball-flight-and-camera.md](02-ball-flight-and-camera.md)
5. [03-economy.md](03-economy.md) + [04-upgrade-tree.md](04-upgrade-tree.md)
6. [07-implementation-phases.md](07-implementation-phases.md)

## Agent rules (v2 additions)

1. **Bucket before infinite swing** — no endless tee unless debug or late upgrade.
2. **Visual carry floor** — OK+ contacts must look like golf; do not ship early hop shots.
3. **Down-the-line scatter** — expect litter clusters; pickup UX must work with overlapping landings.
4. **Separate visual depth from payout yards** — see [02-ball-flight-and-camera.md](02-ball-flight-and-camera.md).
5. **Range upgrades change the diorama** — passive income tied to visible range quality when that phase ships.
6. v1 docs are not deleted; mark superseded sections in code comments when migrating.

## Third-party / assets

Unchanged from [main README](../README.md#third-party-assets). Range Rat sprites live in `assets/sprites/range_rat/`.
