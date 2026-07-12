# v7 Prestige Loop

## Flow

```text
Play (cash tree) → bank cash on hand
        ↓
 cash >= prestige_threshold (default $5,000)
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
| `prestige_threshold` | **5000** | Cash **on hand** (`GameState.currency`) |
| Shown when | Always on Prestige tab | Greyed out + tooltip while `cash < threshold` |
| Can prestige early? | **Yes** | Before meaningfully maxing the Play tree |

**Ambition** (cheese node) raises `prestige_threshold` and increases base cheese payout (see [04-cheese-tree.md](04-cheese-tree.md)).

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

Always grant cheese on a successful prestige (never zero).

**Proposed formula (tune in Balance):**

```text
base_cheese = cheese_press_base + cheese_press_bonus_from_tree
surplus = max(0, cash_on_hand - prestige_threshold)
surplus_cheese = floor(surplus / SURPLUS_PER_CHEESE)   # e.g. 2500
total_cheese = base_cheese + surplus_cheese
```

| Constant (starting point) | Value | Intent |
|---------------------------|-------|--------|
| `cheese_press_base` | 1 | Always get something at 5k |
| `SURPLUS_PER_CHEESE` | 2500 | Chunky bonus for banking over threshold |
| Cheese Press levels | +1 base per level (or +% — pick in implementation, document in Balance) | Root meta node |

**Feel goal:** Prestiging at exactly 5k is fine. Banking to 7.5k–10k feels a little greedier. Ambition makes “wait for a higher threshold” a real choice later.

## Confirm UX

- Prestige button disabled (grey) when under threshold; tooltip: need $X more / “Requires $5,000 on hand” (or current threshold).
- When affordable: short confirm dialog — you will lose cash and Play upgrades; keep cheese and Prestige upgrades.
- After confirm: close or stay on Prestige tab; HUD cash shows 0 (or starting float if any — **none in v7**).

## Anti-goals for this loop

- No “only prestige after losing”
- No primers as the prestige reward
- No spending cheese on the Play tree
