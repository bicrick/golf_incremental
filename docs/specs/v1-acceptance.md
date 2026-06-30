# v1 Acceptance Criteria

Testable checklist for v1 completion. Each item must pass without interpretation dispute.

**Design reference:** [../design/05-progression.md](../design/05-progression.md)  
**Architecture reference:** [../technical/01-architecture.md](../technical/01-architecture.md)

---

## Boot and platform

- [ ] Project opens in **Godot 4.x** without errors
- [ ] **F5** runs `scenes/main.tscn` from Godot Editor
- [ ] Viewport 480×270 with **integer scale** (no blurry sprites)
- [ ] `textures/canvas_textures/default_texture_filter` = Nearest (or per-sprite Nearest)
- [ ] At least **3 `Parallax2D` layers** visible with distinct `scroll_scale` values

---

## Parallax 2.5D

- [ ] Down-the-line range: sky/background recedes toward horizon
- [ ] Foreground golfer/tee/ball on anchor layer (not scrolling with sky)
- [ ] Ball flight moves **up-screen** toward horizon
- [ ] Ball **scales down** during flight (depth illusion)
- [ ] Parallax layers unchanged during jackpot feedback (when implemented)

---

## Rhythm core loop

- [ ] Beat indicator pulses at fixed BPM (60–72 range, configured in `balance.gd`)
- [ ] Single mouse click or spacebar registers a swing attempt
- [ ] Click aligned with beat → `perfect` or `good` tier
- [ ] Click far from beat → `miss` tier with **non-zero** pity payout
- [ ] Swing cooldown prevents spamming faster than cadence allows
- [ ] "Faster follow-through" upgrade measurably reduces cooldown

---

## Ball flight and feedback

- [ ] On swing resolve, ball flight `Tween` plays toward range
- [ ] Distance display or log reflects upgraded yard stats
- [ ] `$` amount appears on screen per swing
- [ ] Perfect hit uses `warm` feedback tier (visual or audio distinguishable from OK)
- [ ] Combo counter increments on Perfect, resets on Miss (unless combo keeper owned)

---

## Economy

- [ ] Payout formula uses multiplicative stats (documented in [03-economy.md](../design/03-economy.md))
- [ ] Currency increments after each swing
- [ ] Upgrade purchase deducts correct exponential cost: `floor(baseCost × growthRate^level)`
- [ ] Cannot purchase when currency insufficient
- [ ] At least **3 upgrades per v1 branch** exist (Rhythm, Distance, Economy)
- [ ] Purchasing upgrade visibly changes stats (yards, window, $/yard, etc.)

---

## Upgrade UI

- [ ] Side panel lists upgrades grouped by branch (`Control` nodes)
- [ ] Each row shows: name, level, cost, buy button
- [ ] Unaffordable upgrades visually disabled or clear feedback on click
- [ ] Player can identify 3+ affordable upgrades across branches mid-session

---

## Save / load

- [ ] Currency persists after game restart (`user://save.json`)
- [ ] Upgrade levels persist after restart
- [ ] Autosave occurs within 30 seconds of play without manual action
- [ ] Save includes `version` field
- [ ] Corrupted/missing save starts fresh game without crash

---

## Progression arc (manual playtest)

- [ ] New player can earn money within first 3 swings
- [ ] First upgrade purchasable within ~2 minutes
- [ ] ~20 minute session reaches "absurd" numbers relative to start (orders of magnitude growth)
- [ ] No soft-lock: always at least one purchasable or earnable path forward

---

## Explicitly NOT required for v1

These should **not** block v1 sign-off:

- Golf friend / passive income
- Bullseye zone art or mechanics
- Outfit sprite layers
- Time-of-day cycle (static palette OK)
- Jackpot spike full implementation (warm tier sufficient; jackpot stub OK)
- GodotSteam / Steam export
- HTML5 itch export
- Unit test suite (nice-to-have)
- Real pixel art (placeholder ColorRects OK)

---

## Smoke test script

1. Fresh load → click on beat 10 times → confirm currency > 0
2. Buy cheapest upgrade → confirm level incremented, currency reduced
3. Close and reopen game → confirm state restored from `user://`
4. Play 15 minutes → confirm numbers grew exponentially
5. Buy upgrade in each of 3 branches → confirm distinct stat effects
6. Scroll camera or observe parallax → confirm layers move at different speeds (if scroll test implemented)

---

## Sign-off

| Role | Name | Date | Pass |
|------|------|------|------|
| Dev | | | |
| Design | | | |
