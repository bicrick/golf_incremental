# v5 · Balance and crew refactor

## The problem (measured)

`tools/sim_story_pacing.gd` plays the real economy, upgrade graph and story with a modeled player. Before v5 tuning, a "good" player **finished the whole game, every find and the ending, in about 9 minutes** with ~400 purchases. Value per ball went from $3 to $243,000.

Cause: pay per ball = `base_amount × (1 + pay_per_yard × yards) × pickup × combo`. Base Pay (×1.15/lv), Yardage Pay (×1.20/lv), pickup and distance all compounded, while each node's cost grew on a single exponential (1.22–1.40). Every "round" of purchases paid for itself faster than the last. On top of that, the spoon/driver finds gave instant carry multipliers that pushed the fog past the next finds (a chain reaction through Act III).

## The fix

- **Distance is the engine.** Pure money multipliers are small: Base Pay ×1.06/lv, Yardage Pay ×1.06/lv (0.1 → ~0.43 $/yd), Pickup ×1.03/lv. Income grows mainly because you hit farther.
- **Costs outgrow effects** on every node (growth 1.34–2.24, plus the existing per-level stretch).
- **Clubs are nodes, not jumps.** Finding Barley's Spoon / Persimmon Driver opens a tree node (+3% carry per level, 10 levels each) instead of an instant ×1.15 / ×1.20.
- **Big one-shot buys throttled:** More Balls (base $300, growth 2.24) and Golden Balls (base $400) no longer double income the moment their gate opens.
- Early finds pulled in (bag 54 yd, bell 74, cart 105) so Act I has a beat every ~10–15 minutes.

## Result (sim, cheapest-first buying)

| Player | Ending |
|---|---|
| casual (10% Perfect) | ~150 min |
| good (30% Perfect) | ~115 min |
| pro (60% Perfect) | ~90 min |

Finds are spread across the run, with Act III speeding up toward the green like a climax. Re-run after any economy change:

```
SKILL=good godot --headless --path . --script res://tools/sim_story_pacing.gd
```

## Crew refactor

The crew was built but dormant because it broke the loop: Rattlings made harvesting pointless, and Ratina drew from your bucket for passive income. v5 keeps their animations doing what they were drawn for, but changes *whose* balls they touch:

- **Ratina: a standing challenge.** She hits one ball *from her own pocket*, and it becomes a pink flag at a distance inside your reach. It stays until one of your balls comes to rest within `ratina_mark_radius`; that ball pays × `ratina_mark_bonus` at pickup. Then she plants the next one. From the tee she calls it out ("Land it 94 yd"); in harvest the flag and ring mark the spot. Her tree is now Coaching (bonus), Bigger Flag (radius) and Lucky Flag (golden chance). No passive income, no bucket stealing, and her swing stays special.
- **Rattlings: the safety net.** They never touch balls while you're harvesting. Balls you leave behind (early exit, or "return leftovers") become leftovers, and Rattlings fetch those at `rattling_leftover_share` of full pay (40% base, Finder's Fee +10%/lv). Leftovers already refilled for free still pay but aren't double-counted. Picking up yourself stays the best money.
