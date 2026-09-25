# Agent Instructions

**Design source of truth:** [`docs/v8/README.md`](docs/v8/README.md) (index: [`docs/README.md`](docs/README.md)).

**Engine:** Godot 4.7 + GDScript, GL Compatibility renderer, 480×270 viewport.

Before implementing a feature:

1. Read [`docs/v8/README.md`](docs/v8/README.md). Update it when the design changes.
2. Keep data in data files: `scripts/tour/tour_data.gd` (ranges, greens, upgrades), `tour_story.gd` (dialogue), `tour_looks.gd` (palettes, props, weather).
3. Shot and money math goes in `scripts/tour/tour_physics.gd` only.

## Verify

```bash
godot --headless --path . --import                                    # after adding/changing assets
godot --headless --path . --script res://tools/verify_tour.gd         # data, physics, save, a scripted run
SKILL=good godot --headless --path . --script res://tools/sim_tour_pacing.gd   # pacing (target 20–30 min)
xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/tour_autoplay.gd   # full real-input run
xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/tour_shot.gd       # screenshots (RANGE=0..4)
```

Tool scripts that `extends SceneTree` must not reference `TourWorld` or other classes that use the `Tour` / `Audio` autoloads at parse time (autoloads aren't registered yet). Use plain values instead.

## Art

Pixel art is drawn procedurally by `tools/art/*.py` (PIL): `draw_tour_backdrops.py`, `draw_tour_props.py`, `draw_tour_sprites.py`, `draw_tour_map.py`. Re-run them and re-import after changing them. Keep `.png.import` files lossless (`compress/mode=0`, `detect_3d/compress_to=0`).

## PixelLab (pixel art MCP)

For PixelLab-generated sprites, read https://api.pixellab.ai/mcp/docs first. Project MCP config: [`.cursor/mcp.json`](.cursor/mcp.json). Rule: [`.cursor/rules/pixellab.mdc`](.cursor/rules/pixellab.mdc).

Run game: open the project in the Godot editor and press **F5**.
