# v2 Characters and Crew

## Range Rat (player)

- Down-the-line striker and **range superintendent**
- Sprites: idle loop, 17-frame swing (contact = frame 9), follow-through hold
- Does not walk fairway in **v2.0** pickup (click-only); optional walk anim in v2.1

## Gnome (v2.1)

| Property | Value |
|----------|-------|
| Role | Litter janitor — picks up balls that would be gopher food |
| Visual | Small sprite on fairway edge during harvest |
| Behavior | Auto-grabs 1 ball per N seconds or 1 guaranteed per bucket |
| Upgrades | Speed, radius, "runs from gopher" comedy anim |
| Income | Does not swing for $ early; saves pickup bonus |

## Gophers (v2.1)

| Property | Value |
|----------|-------|
| Role | Soft pressure on **uncollected litter** |
| Behavior | After ball ages on fairway, steal 1 — comedic pop, no $ already banked lost |
| Counter | Scarecrow upgrade, faster pickup, gnome |

Tone: Miyazaki mischief, not punishment.

## Rat friends (v2.2)

- Second bay, mediocre timing, volume swings for passive $
- Upgrades: clubs, cadence — player still contact-swing primary
- Optional synergy: player bucket combo → friend +25% that cycle

## v1 golf friend

Superseded by **Crew** branch in v2 docs. Do not implement lawn-chair friend separately.

## Related docs

- Pickup: [06-pickup-minigame.md](06-pickup-minigame.md)
- Upgrades: [04-upgrade-tree.md](04-upgrade-tree.md)
