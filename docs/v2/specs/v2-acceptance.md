# v2 Acceptance Criteria

Testable done gates per implementation phase. See [07-implementation-phases.md](../07-implementation-phases.md).

## Phase B — Visual carry floor

- [ ] Default stats, OK tier contact: ball landing Y ≥ configured floor (not near tee hop)
- [ ] Perfect contact: landing at or above first fairway depth band
- [ ] Miss/whiff: landing within dribble radius of tee
- [ ] `verify_ball_flight.gd` extended or `verify_v2_visual_floor.gd` passes headless

## Phase C — Bucket strike gate

- [ ] New game starts with `bucket_remaining == bucket_capacity` (default 6)
- [ ] Each resolved swing decrements bucket by 1
- [ ] Space does not start swing when bucket is 0
- [ ] HUD shows bucket count

## Phase D — Pickup MVP (v2.0 playable)

- [ ] Bucket 0 triggers harvest phase; prompt visible
- [ ] Each litter sprite clickable; removes on collect
- [ ] Bucket UI increments per collect
- [ ] Full bucket returns to strike phase with bucket refilled
- [ ] Pickup payout + bucket bonus applied to currency
- [ ] Combo increases with rapid collects
- [ ] Overlapping litter cluster still collectable (hitbox rule documented)
- [ ] Headless or scene test for phase transitions

## Phase E — Contact swing

- [ ] Swing quality derived from release timing vs contact window (not hold-to-peak)
- [ ] Sweet spot upgrade increases Perfect window measurably
- [ ] Charge power bar not required for MVP tutorial text

## Phase F — Upgrade tree v2 data

- [ ] At least 3 purchasable upgrades in Sweet spot + Pickup + Economy
- [ ] No required early purchase of raw `base_yards` × mult only

## Phase G+ (v2.1+)

Deferred — document when scheduled:

- Range visual changes on purchase
- Gnome + gopher
- Passive income > 0
- Zone 2 unlock

## Regression

Always run before marking a phase done:

```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
$GODOT --headless --path . --quit-after 2
```

Relevant verify scripts per touched systems.
