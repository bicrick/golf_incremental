# v7 Acceptance Criteria

All must pass before calling prestige v7 done.

## Prestige loop

- [x] With `currency >= prestige_threshold` (default 5000), Prestige tab button is enabled.
- [x] Below threshold, button is greyed out and tooltip explains the cash-on-hand requirement.
- [x] Confirming prestige: cash → 0 (or fully consumed); all Play upgrade levels → 0; cheese increases by formula; `prestige_count` += 1.
- [x] Prestige upgrades and cheese balance survive prestige and save/load.
- [x] Surplus above threshold grants additional cheese (chunky steps per Balance).

## Currencies & UI

- [x] Prestige tab header shows **cheese**, not cash.
- [x] Prestige tab shows **prestige #**.
- [x] Play tab still shows cash.
- [x] Cheese cannot purchase Play nodes; cash cannot purchase Prestige nodes.

## Play tree

- [x] Quick Reset and Combo Bonus are not on the Play tree.
- [x] Ratina and Rattlings are not visible / purchasable on the Play tree.
- [x] Default bucket capacity is 6 without Deep Bucket.
- [ ] Fresh save can reach $5k on hand in a short session relative to pre-v7 (playtest sign-off).

## Cheese tree

- [x] Cheese Press increases base cheese on prestige.
- [x] Ambition raises threshold and improves payout.
- [x] Quick Reset / Combo Hands / Deep Bucket / Golden Tee apply persistent effects across runs.
- [x] Perfect Chain: after 3 Perfects in a row, balls are golden until the Perfect streak breaks.

## Regression

- [x] `$GODOT --headless --path . --quit-after 2` exits 0.
- [x] Relevant verify scripts pass (`verify_upgrade_tree`, `verify_upgrade_effects`, new `verify_prestige` if added).
- [ ] Strike / harvest / contact swing still function. (manual F5 smoke)

## Explicit non-criteria (not required for v7)

- Landlord / day cycle
- Field consumables
- Ratina/Rattling rework (beyond hidden)
- Main HUD cheese display
