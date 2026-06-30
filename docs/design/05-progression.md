# Progression

## Phase overview

| Phase | Focus | Upgrade branches (content) | Key features |
|-------|-------|---------------------------|--------------|
| **v1** | Prove rhythm + exponential loop | Rhythm, Distance, Economy | Beat swing, 3 branches, save, basic juice |
| **v1.5** | Visual depth + build variety | + Range/targets, Outfits | Bullseyes, time-of-day, outfit layers |
| **v2** | Idle layer | + Friends | Golf friend passive income |
| **v3+** | Long-term | All branches full content | Prestige, new seasons, Steam |

## v1 — detailed scope

### In scope

- Down-the-line driving range (placeholder art)
- Pulsing ring beat indicator, single click
- Timing tiers: Perfect / Good / OK / Miss (pity payout)
- Combo counter on Perfect streak
- Swing cadence cooldown between swings
- 3 upgrade branches with exponential costs
- Categorized upgrade side panel
- `user://save.json` save / load, autosave every 30s
- Basic feedback: ball tween, `$` floaties, tier text
- Calm default feedback; basic `warm` tier on Perfect

### Out of scope

- Golf friend / passive income
- Bullseye zone mechanics on range art
- Outfit sprite layers
- Time-of-day cycle (static palette OK)
- Full 8-branch upgrade content
- GodotSteam, prestige, multiplayer

### v1 architecture requirements

- Full upgrade **data model** for all branches (stubs OK)
- `passiveRate` in types defaults to 0
- `manualIncome` vs `passiveIncome` separation in economy
- `FeedbackTier` enum ready for jackpot system

## v1.5 — detailed scope

- Bullseye rings on range with `targetZoneMult`
- At least 2 time-of-day phases unlocked by milestones
- Outfit sprite layers (hat, shirt, pants, shoes, gloves, accessory)
- Jackpot feedback spikes fully implemented
- Range extension parallax

## v2 — detailed scope

- Golf friend visible on sideline, auto-swing animation
- Passive income stream + upgrades (Branch 8)
- "In the groove" synergy: combo active → friend +25%
- Offline earnings with 8-hour cap
- Additional club slots (irons, putter)

## v3+ — optional

- Prestige / "New season at the range" — reset currency, keep cosmetics, permanent mult
- Multiple rooms (Fortune Mill-style) — only if v1 loop proven
- Steam achievements, cloud saves

---

## First session arc (~20 minutes)

Target player journey for v1 balance tuning:

| Minute | Player state | Feel |
|--------|--------------|------|
| 0–3 | Learning beat, pity misses OK | "Easy, calming" |
| 3–8 | First upgrades: metronome, leg day, $/yard | "Numbers moving" |
| 8–14 | Combo play, faster follow-through | "I'm in a groove" |
| 14–20 | Multiple branches stacking, big Perfect payouts | "Absurd growth" |

End state: player should see next milestone and affordable upgrades still available.

---

## Milestone examples

| Milestone | Stat | Reward |
|-----------|------|--------|
| First drive | 50 yards single swing | Unlock club tier 2 |
| Combo apprentice | 5 Perfect combo | `perfect_bonus` visible |
| Range regular | $10,000 lifetime | Faster follow-through tier discount |
| Big hitter | 500 lifetime yards | Bullseye branch (v1.5) |
| Sunset golfer | $50,000 lifetime | Golden evening (v1.5) |

Always show in UI: **"Next: Golden evening at $50,000 lifetime ($12,400 to go)"**

---

## Exponential never-stop rules

1. **Costs** grow exponentially per level
2. **Effects** multiply across branches
3. **Milestones** gate new branches (horizontal expansion)
4. **Named unlocks** every few levels (qualitative bumps)
5. **Prestige** (v3+) optional infinite ceiling

---

## Related docs

- v1 acceptance tests: [../specs/v1-acceptance.md](../specs/v1-acceptance.md)
- Upgrade branches: [04-upgrade-tree.md](04-upgrade-tree.md)
- Characters / friend: [06-characters.md](06-characters.md)
