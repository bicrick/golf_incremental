# Agent Instructions

**Design source of truth:** [`docs/v9/README.md`](docs/v9/README.md) (index: [`docs/README.md`](docs/README.md)).

**Engine:** Godot 4.7 + GDScript, GL Compatibility renderer, 480×270 viewport.

Before implementing a feature:

1. Read [`docs/v9/README.md`](docs/v9/README.md). Update it when the design changes.
2. Keep data in data files: `scripts/fortune/fortune_data.gd` (rooms, upgrades), `scripts/tour/tour_looks.gd` (venue palettes, props, weather).
3. Every derived number (values, rates, odds) goes in `scripts/fortune/fortune_econ.gd` only. After touching costs or payouts, re-run the autoplayer and update the pacing table in the doc.

## Verify

```bash
godot --headless --path . --import                                        # after adding/changing assets
godot --headless --path . --script res://tools/verify_fortune.gd          # data, econ, save, a scripted run through every room
SPEED=40 godot --headless --path . --script res://tools/fortune_autoplay.gd   # pacing to $1M (target ~30 min; SKILL=45/70/110)
xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/fortune_shot.gd   # screenshots (ROOM, CASH, LEVELS, ROOMS=all, OPEN)
```

Tool scripts that `extends SceneTree` must not reference classes that use the `Game` / `Audio` autoloads (`TeeLine`, the rooms, the UI) at parse time, because autoloads aren't registered yet. Reach them through the scene tree with plain `Node` types.

## Art

Pixel art is drawn procedurally by `tools/art/*.py` (PIL): `draw_tour_backdrops.py`, `draw_tour_props.py`, `draw_tour_sprites.py`. Re-run them and re-import after changing them. Keep `.png.import` files lossless (`compress/mode=0`, `detect_3d/compress_to=0`).

## PixelLab (pixel art MCP)

For PixelLab-generated sprites, read https://api.pixellab.ai/mcp/docs first. Project MCP config: [`.cursor/mcp.json`](.cursor/mcp.json). Rule: [`.cursor/rules/pixellab.mdc`](.cursor/rules/pixellab.mdc).

Run game: open the project in the Godot editor and press **F5**.
