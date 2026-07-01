# Economy

> **v2 overhaul:** Pickup-time progressive formula and new upgrade tree are authoritative in [v2/03-economy.md](../v2/03-economy.md). This doc retains v1 reference material.

## Currency

**Working name: Range Bucks (`$`)** — display with `$` prefix. Rename later if desired (Par Points, etc.); keep internal key as `currency: number`.

## Payout formula

Multiplicative stacking across branches — this is the Fortune Mill spike.

```
payout = baseYards
       × rhythmTierMult
       × clubMult
       × ballMult
       × targetZoneMult
       × outfitMult        (v1.5+)
       × globalMult
       × dollarsPerYard
       + flatBonusPerSwing  (optional, from upgrades)
```

> **v1 note:** Combo multiplier stacking removed for rework. Payout is tier × stat mults only.

### Variable definitions

| Variable | Source | Default (v1) |
|----------|--------|--------------|
| `baseYards` | Swing resolution + distance upgrades | 5–20 early |
| `rhythmTierMult` | Perfect/Good/OK/Miss | 1.0 / 0.7 / 0.4 / 0.1 |
| `clubMult` | Club branch | 1.0 |
| `ballMult` | Ball branch | 1.0 |
| `targetZoneMult` | Bullseye zone (v1.5+) | 1.0 |
| `outfitMult` | Outfit pieces (v1.5+) | 1.0 |
| `globalMult` | Economy branch | 1.0 |
| `dollarsPerYard` | Economy branch | 1.0 |
| `flatBonusPerSwing` | Tip jar etc. | 0 |

### Effect application order

1. Compute `baseYards` from stats + timing
2. Apply `targetZoneMult` (v1.5+)
3. Multiply all stat mults: `rhythmTierMult × clubMult × ballMult × outfitMult × globalMult`
4. Multiply by `dollarsPerYard`
5. Add `flatBonusPerSwing`
6. Round/display with appropriate formatting (K, M, B suffixes at scale)

### Jackpot payout detection

After computing `payout`, classify `FeedbackTier`:

| Condition | FeedbackTier |
|-----------|--------------|
| `payout < greatThreshold` | `whisper` or `warm` |
| Bullseye center OR crit | `jackpot` |
| `payout >= jackpotThreshold` | `jackpot` |
| Milestone event | `milestone` |

Thresholds live in `scripts/config/balance.gd`.

## Cost curve

Per upgrade level:

```
cost(level) = floor(baseCost × growthRate^level)
```

| Phase | Typical growthRate |
|-------|-------------------|
| Early branches | 1.12 – 1.18 |
| Late branches | 1.08 – 1.12 |

Tune per branch in `balance.gd`. Different branches can use different `baseCost` and `growthRate`.

## Income streams

| Stream | Phase | Description |
|--------|-------|-------------|
| `manual` | v1 | Player rhythm swings |
| `passive` | v2 | Golf friend auto-swings |

```
totalIncomePerSecond ≈ manualSwingsPerSec × avgPayout + passiveRate × passivePayout
```

v1: `passiveRate = 0`.

## Milestone gates

Unlock branches, visuals, or features at lifetime stats:

| Example milestone | Unlocks |
|-------------------|---------|
| 100 total yards | Club tier 2 |
| $50,000 lifetime | Golden evening time-of-day |
| $1,000,000 lifetime | Blue hour range |

Store lifetime stats in save: `lifetimeYards`, `lifetimeEarnings`, `perfectCount`, etc.

UI always surfaces **next milestone** prominently.

## Number formatting

Display large numbers with suffixes:

- 1,234 → `$1.23K`
- 1,234,567 → `$1.23M`

Use a shared `formatCurrency(n: number): string` utility.

## Save-relevant economy fields

```typescript
interface EconomyState {
  currency: number;
  lifetimeEarnings: number;
  lifetimeYards: number;
  perfectCount: number;
  upgradeLevels: Record<string, number>;
}
```

## Offline progress (v2+)

When passive income exists:

```
offlineEarnings = min(elapsedSeconds, maxOfflineSeconds) × passiveRate × avgPassivePayout
```

Cap at 8 hours (`maxOfflineSeconds = 28800`) to limit exploit.

v1: no offline earnings (or grant zero).

## Anti-patterns

- **Additive-only upgrades** for primary drivers — use multipliers
- **Zero payout on miss** — always grant pity amount
- **Single linear upgrade path** — wide tree with parallel options

## Related docs

- Upgrade branches: [04-upgrade-tree.md](04-upgrade-tree.md)
- Data types: [../technical/02-data-model.md](../technical/02-data-model.md)
- Feedback tiers: [07-art-and-atmosphere.md](07-art-and-atmosphere.md)
