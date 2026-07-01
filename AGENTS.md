# Agent Instructions

**Design source of truth:** [`docs/README.md`](docs/README.md)

**Engine:** Godot 4.x + GDScript

Before implementing any feature:

1. Read the relevant doc from the [doc map](docs/README.md#doc-map). **New loop work:** [`docs/v2/README.md`](docs/v2/README.md). **Balance / long-tail progression:** [`docs/v3/README.md`](docs/v3/README.md).
2. Follow [agent workstreams](docs/technical/03-agent-workstreams.md) for parallel work — do not edit files outside your workstream
3. Freeze autoloads (`EventBus`, `GameState`) and `PlayerStats` before parallel splits (Workstream 0)
4. Parallax layer tree lives in `scenes/range/range_view.tscn` — only Workstream A edits it
5. Do not edit Cursor plan files — update `docs/` when design changes

v1 done criteria: [`docs/specs/v1-acceptance.md`](docs/specs/v1-acceptance.md)

v2 redesign (bucket, pickup, contact swing): [`docs/v2/README.md`](docs/v2/README.md) and phased rollout [`docs/v2/07-implementation-phases.md`](docs/v2/07-implementation-phases.md)

Run game: open project in Godot Editor → **F5**
