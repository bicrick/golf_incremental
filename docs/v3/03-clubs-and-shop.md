# v3 Clubs & Shop

**Design intent:** Yards are **capped and taper** (~400 max effective). Money scales through **`pay_per_yard` and `$` upgrades**, not infinite carry. Clubs are **shop purchases** that trade forgiveness for distance — **stats first, art optional**.

**Shipped note:** The separate Pro Shop panel was removed. `ball_count` and `golden_ball` live on the unified upgrade tree. Ratina and Rattlings are hire nodes on that tree. Club equipment below remains **planned**, not implemented.

## Player fantasy

| Club | Feel | Mechanical trade |
|------|------|------------------|
| **Range rental** (default) | Forgiving, modest | Wide Perfect window, low carry, baseline `pay_per_yard` |
| **Bent Pin Driver** | Bombs or bust | High carry potential, **narrow** Perfect window |
| **Old Blades** (example) | Consistent mid | Medium carry, wider Great band, no jackpot thin/fat drama |

Skill stays central: a driver rewards **Perfect contact**; the default club rewards **steady Good/Great** play.

## Yards cap (~400 effective)

Raw formula today:

```
raw_yards = base_yards × carry_multiplier × strike_quality
```

v3 adds a **soft cap** so upgrades and clubs can keep stacking internally without breaking the fairway:

```
effective_yards = carry_cap × (1 − exp(−raw_yards / carry_cap))
```

| `carry_cap` | Role |
|-------------|------|
| `400` (default target) | Endgame asymptote — never “gazillion yards” |
| Club modifiers | Driver raises cap slightly (e.g. 450) or raises raw mult before cap |
| Power tree | Small `base_yards` / `carry_multiplier` steps — not the main income axis |

**Payout uses `effective_yards`** (or stored capped value on litter at contact) for Distance Pay:

```
bonus = base_amount × pay_per_yard × effective_yards
```

Income growth mid/late game = **`pay_per_yard` + Base Pay + Quality + Pickup**, not more raw carry.

## Shop vs upgrade tree

| System | Role |
|--------|------|
| **Upgrade tree** | Range superintendent — pay spine, harvest, timing QoL, modest carry |
| **Shop (clubs)** | Equipment identity — 3–5 named clubs, one-time or tier unlocks |
| **Future shop** | Balls, outfits (deferred — more art) |

Clubs live in shop data (`scripts/game/shop/` or `.tres` resources), not the 14-node polygon tree.

### Example club stat block

```gdscript
{
  "id": "bent_pin_driver",
  "display_name": "Bent Pin Driver",
  "carry_multiplier": 1.35,
  "timing_window_perfect_ms": -6.0,   # narrower
  "pay_per_yard_mult": 1.0,
  "carry_cap_bonus": 50.0,            # optional: 450 vs 400
}
```

Apply on equip to `PlayerStats` (same pattern as upgrade effects).

## Art & animation — keep it simple

**You do not need new swing animations for v3 clubs.**

The Range Rat swing sheet is **one generic club silhouette** baked into 52×52 frames. Clubs are a **stat identity**, not a mesh swap.

| Approach | Art cost | Ship in |
|----------|----------|---------|
| **Stats + HUD card** | Zero — icon or text “Equipped: Driver” | v3.0 |
| **Ball tint / trail color** per club | Minimal — existing flight trail | v3.0 optional |
| **Tiny held-item overlay** on contact frame only | 1 sprite × 3 clubs | v3.1 |
| **Full per-club swing sheets** | 17 frames × N clubs | v4+ if ever |

Recommended path: **ship clubs as data + UI**; add visuals when a club proves fun in playtest.

## Power tree reframing (v3)

Current Power branch (`power`, `iron_set`, `power_surge`) doubles carry — **conflicts with 400 cap + $/yard focus**.

Target:

- **Keep** Distance Pay unlock on Power branch — links flight to money.
- **Nerf** carry upgrades to slow growth (see [findings/economy-progression-findings.md](findings/economy-progression-findings.md)).
- **Shift late Power nodes** toward `pay_per_yard` bonuses or carry-cap efficiency, not raw mult.
- **Driver club** supplies the “I can rip it” spike; tree supplies baseline improvement.

## Session target: ~2 hours to max tree

178 level purchases + tree unlock. At ~16 s/bucket:

| Avg payback (whole run) | Session length |
|-------------------------|----------------|
| 2.0 buckets | ~96 min |
| **2.5 buckets** | **~120 min** ← v3 target |
| 3.0 buckets | ~144 min |

Tune `costRate / effectRate` so early purchases ~1–2 buckets, mid ~2–4, deep nodes ~4–8 — **average ~2.5** over the full tree.

Clubs are **side purchases** during the run (milestones or shop unlock), not all required for “100% tree complete.”

## Related docs

- [findings/economy-progression-findings.md](findings/economy-progression-findings.md)
- [01-economy-and-progression.md](01-economy-and-progression.md)
- v1 club flavor names: [design/04-upgrade-tree.md](../design/04-upgrade-tree.md) Branch 3
- `PlayerStats.club_multiplier` — already stubbed in code
