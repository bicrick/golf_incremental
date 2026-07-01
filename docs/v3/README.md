# Golf Incremental — v3 Design

**Design source of truth for long-tail polish and progression tuning.** v2 docs under [`docs/v2/`](../v2/) describe the shipped core loop (bucket, contact swing, pickup, upgrade tree). This folder captures **where the game goes next** now that that foundation feels right.

## One-liner

Keep the **range rat superintendent** fantasy, fix the **economy pacing** so sessions last, and grow the **tycoon layer** (crew, range amenities, zones) without turning a cozy skill game into a spreadsheet that ends in five minutes.

## Relationship to v2

| v2 (current foundation) | v3 (this doc set) |
|-------------------------|-------------------|
| Bucket → swing → pickup → spend | Same loop — **tune curves**, don’t rewrite loop |
| 14-node upgrade tree, ×2 paired curves in code | **Per-branch growth rates** — see [findings](findings/economy-progression-findings.md) |
| Passive crew deferred | **Rat friends / crew** as session-2+ hook |
| Range diorama mostly static | **Visible range upgrades** tied to milestones |
| Shop / equipment deferred | Optional **shop layer** when economy is stable |

v2 implementation docs remain authoritative for **what exists in code today**. v3 docs are authoritative for **balance targets and next-phase scope**.

## Doc map

| Doc | Read if you are working on… |
|-----|----------------------------|
| [00-vision.md](00-vision.md) | v3 pillars, scope boundaries, what we are not changing |
| [findings/economy-progression-findings.md](findings/economy-progression-findings.md) | **Economy audit, research, simulations, recommended curves** |
| [01-economy-and-progression.md](01-economy-and-progression.md) | High-level v3 direction (summary pointer to findings) |
| [02-long-tail-content.md](02-long-tail-content.md) | Crew, range amenities, zones, milestones |
| [specs/v3-acceptance.md](specs/v3-acceptance.md) | Testable done criteria for v3 phases |

## Reading order

1. [00-vision.md](00-vision.md)
2. [findings/economy-progression-findings.md](findings/economy-progression-findings.md) — **start here for balance work**
3. [01-economy-and-progression.md](01-economy-and-progression.md)
4. [02-long-tail-content.md](02-long-tail-content.md)
5. [specs/v3-acceptance.md](specs/v3-acceptance.md)

## Agent rules (v3 additions)

1. **Do not rewrite v2 loop** — rebalance numbers and add long-tail systems only.
2. **Payback period is the primary balance metric** — see findings doc.
3. **Cost growth must exceed effect growth** per upgrade (`costRate / effectRate > 1.0`).
4. **Power curves slower than money curves** — flight is spectacle; `$` is dopamine.
5. **Preserve skill variance** — timing tiers and harvest combo must stay meaningful at mid-game.
6. v2 docs are not deleted; note superseded sections when code catches up to v3 targets.

## Related docs

- v2 core: [v2/README.md](../v2/README.md)
- Original design pillars: [design/00-vision.md](../design/00-vision.md)
- Upgrade data: `scripts/game/upgrades/definitions.gd`
