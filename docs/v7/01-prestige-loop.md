# v7 Prestige Loop

## Flow

```text
Play (cash tree) → bank cash on hand
        ↓
 cash >= prestige_threshold (default $500)
        ↓
 Open Upgrade Menu → Prestige tab → Prestige button
        ↓
 Confirm → grant cheese → wipe run progress → keep cheese + cheese-tree levels
        ↓
 New climb (faster if OP unlocked)
```

## Gate

| Field | Default | Notes |
|-------|---------|-------|
| `prestige_threshold` | **500** | Cash **on hand** (`GameState.currency`) |
| Shown when | Always on Prestige tab | Greyed out + tooltip while `cash < threshold` |
| Can prestige early? | **Yes** | Before meaningfully maxing the Play tree |

**Ambition** (cheese node) raises `prestige_threshold` and multiplies cheese payout (see [04-cheese-tree.md](04-cheese-tree.md)).

## On prestige (reset)

| Wipes | Keeps |
|-------|-------|
| Cash (entirely — cash out the run) | Cheese balance |
| All **Play** (cash) upgrade levels | All **Prestige** (cheese) upgrade levels |
| Shop / ball_count levels tied to this run | `prestige_count` (incremented) |
| Bucket back to default capacity (unless Deep Bucket cheese applies) | Perfect Chain / other cheese-driven flags |
| Harvest/strike transient state as needed for a clean restart | Save-compatible prestige fields |

**Ratina / Rattling:** if any residual state exists in save, clear active hire / counts on prestige; they are not offered on the Play tree in v7.

## Cheese payout

Always grant cheese on a successful prestige (never zero). Extra cash above the threshold does **not** grant bonus cheese.

**Formula:**

```text
base_cheese = PRESTIGE_CHEESE_BASE + cheese_press_levels   # default base 3
total_cheese = base_cheese × 2^ambition_level
```

| Constant (starting point) | Value | Intent |
|---------------------------|-------|--------|
| `PRESTIGE_CHEESE_BASE` | 3 | Always get something at $500 |
| Cheese Press levels | +1 base per level | Root meta node |
| Ambition | ×2 cheese (and ×2 threshold) per level | Optional bigger dumps |

**Feel goal:** Prestiging at exactly $500 is the goal. Banking more cash only helps you buy Play upgrades before cash-out — not more cheese.

## Confirm UX

- Prestige button disabled (grey) when under threshold; tooltip: need $X more / “Requires $500 on hand” (or current threshold).
- When affordable: short confirm dialog — you will lose cash and Play upgrades; keep cheese and Prestige upgrades.
- After confirm: close or stay on Prestige tab; HUD cash shows 0 (or starting float if any — **none in v7**).

## Anti-goals for this loop

- No “only prestige after losing”
- No primers as the prestige reward
- No spending cheese on the Play tree
