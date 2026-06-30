# v2 Implementation Phases

Build in order. Each phase should be playable before starting the next.

## Phase A — Design only (this doc set)

- [x] v2 docs in `docs/v2/`
- [ ] Team agrees v2.0 scope = bucket + pickup MVP + contact swing retune

## Phase B — Visual carry floor (no bucket yet)

**Goal:** OK+ hits look like golf down-the-line.

| Task | Files (likely) |
|------|----------------|
| Minimum landing depth for non-whiff | `ball_flight_renderer.gd`, `balance.gd` |
| Whiff dribble near tee | `range_view.gd`, flight path |
| Retune arc minimum | `BallFlightRenderer.FlightConfig` |
| Verify | `verify_ball_flight.gd`, new asserts for floor |

**Exit:** Perfect shot at default stats reaches first depth band visually.

## Phase C — Bucket + strike gate (v2.0 core)

**Goal:** Finite balls per burst.

| Task | Files (likely) |
|------|----------------|
| `bucket_capacity`, `bucket_remaining` on GameState or session | `game_state.gd`, save |
| Decrement on swing resolve; block swing at 0 | `swing.gd`, `range_view.gd` |
| Bucket UI | `hud.gd` / new HUD nodes |
| Remove infinite `_respawn_ball_at_tee` until harvest complete | `range_view.gd` |

**Exit:** Player forced to stop after N swings.

## Phase D — Pickup mini-game (v2.0 MVP)

**Goal:** Click litter → refill bucket → earn pickup $.

| Task | Files (likely) |
|------|----------------|
| Harvest phase state machine | `range_view.gd` or `pickup_controller.gd` |
| Click collect + tween | litter children |
| Combo + bucket complete payout | `economy.gd`, `EventBus` |
| Upgrade stubs: bucket size, pickup bonus | `definitions.gd` |

**Exit:** [specs/v2-acceptance.md](specs/v2-acceptance.md) Phase D criteria.

## Phase E — Contact swing (replace hold-power UX)

**Goal:** Release at contact frame; deprecate charge bar primary feedback.

| Task | Files (likely) |
|------|----------------|
| Map release delta to quality (not hold duration) | `rhythm.gd` → `contact_swing.gd` or extend |
| Simplify charge meter / rings optional | `range_view.gd`, HUD |
| Sweet spot upgrades affect windows | `effects.gd`, `definitions.gd` |
| Wind-up frames 0–7 unchanged | existing rat anim |

**Exit:** No hold-to-peak required; contact window documented in HUD.

## Phase F — Upgrade tree v2 (data)

**Goal:** Replace early Distance spam with Sweet spot + Pickup branches.

| Task | Files |
|------|-------|
| New upgrade IDs per [04-upgrade-tree.md](04-upgrade-tree.md) | `definitions.gd` |
| UI labels in upgrade panel | `upgrade_panel.gd` |
| Deprecate or gate `leg_day` early | balance pass |

## Phase G — Range tycoon visuals (v2.1)

Passive $, crack patch, grass tiers, scarecrow prop.

## Phase H — Gnome + gophers (v2.1)

Harvest pressure + relief.

## Phase I — Targets / zone 2 (v2.2)

Depth band scoring, $100k gate, bullseye mult.

## Migration notes from v1

| v1 system | Action |
|-----------|--------|
| Hold charge `ChargeSwing` | Keep internally during Phase C; replace in E |
| `SWING_FRAME_COUNT` wind-up | Keep |
| Infinite tee reload | Remove in Phase C |
| Litter sprites | Reuse for pickup |
| `verify_swing_distance` | Update for contact quality curve |
| v1 docs `01-core-loop.md` | Add banner: superseded by v2 for new work |

## Related docs

- Acceptance: [specs/v2-acceptance.md](specs/v2-acceptance.md)
- Agent workstreams: update when Phase C starts — [../technical/03-agent-workstreams.md](../technical/03-agent-workstreams.md)
