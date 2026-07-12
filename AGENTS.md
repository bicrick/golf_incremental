# Agent Instructions

**Design source of truth:** [`docs/README.md`](docs/README.md)

**Engine:** Godot 4.x + GDScript

Before implementing any feature:

1. Read the relevant doc from the [doc map](docs/README.md#doc-map). **Prestige / cheese (current):** [`docs/v7/README.md`](docs/v7/README.md). **New loop work:** [`docs/v2/README.md`](docs/v2/README.md). **Balance / long-tail progression:** [`docs/v3/README.md`](docs/v3/README.md). **Camera / world / buildable grid / crew bays:** [`docs/v4/README.md`](docs/v4/README.md).
2. Follow [agent workstreams](docs/technical/03-agent-workstreams.md) for parallel work — do not edit files outside your workstream. **v7 splits:** [`docs/v7/06-workstreams.md`](docs/v7/06-workstreams.md).
3. Freeze autoloads (`EventBus`, `GameState`) and `PlayerStats` before parallel splits (Workstream 0)
4. Parallax layer tree lives in `scenes/range/range_view.tscn` — only Workstream A edits it
5. Do not edit Cursor plan files — update `docs/` when design changes

v1 done criteria: [`docs/specs/v1-acceptance.md`](docs/specs/v1-acceptance.md)

v2 redesign (bucket, pickup, contact swing): [`docs/v2/README.md`](docs/v2/README.md) and phased rollout [`docs/v2/07-implementation-phases.md`](docs/v2/07-implementation-phases.md)

v4 redesign (orthographic camera, buildable grid, physical crew bays — design phase): [`docs/v4/README.md`](docs/v4/README.md) and phased rollout [`docs/v4/05-migration-and-phasing.md`](docs/v4/05-migration-and-phasing.md)

v7 prestige (cheese, OP tree, $5k cash-out): [`docs/v7/README.md`](docs/v7/README.md), acceptance [`docs/v7/specs/v7-acceptance.md`](docs/v7/specs/v7-acceptance.md)

Run game: open project in Godot Editor → **F5**

## PixelLab (pixel art MCP)

For sprites / tilesets / animations via PixelLab, read the tool overview first:

https://api.pixellab.ai/mcp/docs

Project MCP config: [`.cursor/mcp.json`](.cursor/mcp.json). Rule: [`.cursor/rules/pixellab.mdc`](.cursor/rules/pixellab.mdc).
