# Characters

## Player golfer

### Presentation

- Down-the-line view: golfer seen from behind, slightly simplified silhouette
- **Rounded, readable** Miyazaki-adjacent proportions — not realistic PGA anatomy
- Expressive idle: subtle sway, breathing, weight shift on beat

### Sprite layers (v1.5+)

Composite sprite from slots — draw order back to front:

1. Body / base
2. Pants
3. Shirt
4. Shoes
5. Gloves
6. Hat
7. Accessory

v1: single placeholder rectangle or one static sprite sheet.

### Animations

| Animation | Trigger |
|-----------|---------|
| Idle | Default loop |
| Wind-up | Beat approaches |
| Swing | Click registered |
| Follow-through | Ball launches |
| Celebrate | Jackpot tier (brief) |

Keep swing animation **short** (≤500ms) to respect swing cadence.

### Outfits

Cosmetic + small stat per slot — see [04-upgrade-tree.md](04-upgrade-tree.md) Branch 6.

Each equipped piece updates visual layer and applies stat effect.

---

## Golf friend (v2)

### Fantasy

Buddy sitting in a **lawn chair** or leaning on a **golf cart** at the sideline of the range. Maybe tea thermos, sunglasses, relaxed posture. They are not stressed about the grind — contrast/comic relief to player's rhythm focus.

### Mechanics

| Property | Description |
|----------|-------------|
| Visibility | Appears after `hire_buddy` upgrade |
| Behavior | Auto-swings on timer (no player input) |
| Payout | Lower per-swing than active player, but infinite consistency |
| Animation | Small swing loop synced loosely to global beat (visual only) |
| Upgrades | Cadence, form, additional crew members |

### Synergy with player

**"In the groove"** — while player combo ≥ threshold:

- Friend payout +25%
- Optional: friend animation becomes more enthusiastic

### Design rules

- Zero micromanagement — hire and upgrade only
- Friend never blocks or interrupts player swings
- Friend income uses `passiveIncome` stream in economy

---

## NPCs / creatures (future)

Optional flavor for range edge — not v1:

- Distant birds (ambient, not NPC)
- Range attendant at shack (dialogue / milestones)
- Spirit tree on hill (subtle fantasy, Miyazaki tone)

Keep grounded by default; fantasy elements subtle.

---

## Related docs

- Outfit stats: [04-upgrade-tree.md](04-upgrade-tree.md)
- Passive income: [03-economy.md](03-economy.md)
- Art style: [07-art-and-atmosphere.md](07-art-and-atmosphere.md)
