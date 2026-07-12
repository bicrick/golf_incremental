# v7 Acceptance Criteria

All must pass before calling prestige v7 done.

## Prestige loop

- [ ] With `currency >= prestige_threshold` (default 5000), Prestige tab button is enabled.
- [ ] Below threshold, button is greyed out and tooltip explains the cash-on-hand requirement.
- [ ] Confirming prestige: cash → 0 (or fully consumed); all Play upgrade levels → 0; cheese increases by formula; `prestige_count` += 1.
- [ ] Prestige upgrades and cheese balance survive prestige and save/load.
- [ ] Surplus above threshold grants additional cheese (chunky steps per Balance).

## Currencies & UI

- [ ] Prestige tab header shows **cheese**, not cash.
- [ ] Prestige tab shows **prestige #**.
- [ ] Play tab still shows cash.
- [ ] Cheese cannot purchase Play nodes; cash cannot purchase Prestige nodes.

## Play tree

- [ ] Quick Reset and Combo Bonus are not on the Play tree.
- [ ] Ratina and Rattlings are not visible / purchasable on the Play tree.
- [ ] Default bucket capacity is 6 without Deep Bucket.
- [ ] Fresh save can reach $5k on hand in a short session relative to pre-v7 (playtest sign-off).

## Cheese tree

- [ ] Cheese Press increases base cheese on prestige.
- [ ] Ambition raises threshold and improves payout.
- [ ] Quick Reset / Combo Hands / Deep Bucket / Golden Tee apply persistent effects across runs.
- [ ] Perfect Chain: after 3 Perfects in a row, balls are golden until the Perfect streak breaks.

## Regression

- [ ] `$GODOT --headless --path . --quit-after 2` exits 0.
- [ ] Relevant verify scripts pass (`verify_upgrade_tree`, `verify_upgrade_effects`, new `verify_prestige` if added).
- [ ] Strike / harvest / contact swing still function.

## Explicit non-criteria (not required for v7)

- Landlord / day cycle
- Field consumables
- Ratina/Rattling rework (beyond hidden)
- Main HUD cheese display
