# v2 Acceptance Criteria

Testable done gates per implementation phase. See [07-implementation-phases.md](../07-implementation-phases.md).

## Phase B — Proportional flight (visual carry floor removed)

- [ ] Visual landing distance equals gameplay yards exactly for every tier (no floor, no cap)
- [ ] Miss/whiff: landing distance proportional to its (low) computed yards, near tee
- [ ] Distance visibly increases across the ladder: Miss < Bad < Okay < Good < Great < Perfect
- [ ] `verify_ball_flight.gd` passes headless

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
- [ ] First-run rat dialogue overlay: Welcome → Hold → first-shot reaction (once) → first bucket → empty/harvest tips (desktop: down-range; mobile: shag bag) → Upgrades (pulse + preview; does not complete) → Keep going after first `upgrade_purchased` + upgrades panel close → complete; typewriter; Space/tap advance; slide-out dismiss; no Skip
- [ ] `tutorial_completed` persists; old saves with swings skip intro; wipe replays
- [ ] `verify_tutorial.gd` passes headless

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
