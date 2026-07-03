#!/usr/bin/env python3
"""Regenerate base_cell and ratina_bay_cell from player_bay_cell.tscn."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYER = ROOT / "scenes/range/cells/player_bay_cell.tscn"
RANGE_VIEW = ROOT / "scenes/range/range_view.tscn"
BASE_OUT = ROOT / "scenes/range/cells/base_cell.tscn"
RATINA_OUT = ROOT / "scenes/range/cells/ratina_bay_cell.tscn"

GOLFER_NODE_MARKER = '[node name="Golfer" type="AnimatedSprite3D"'
BALL_NODE_MARKER = '[node name="Ball" type="AnimatedSprite3D"'
GOLFER_ATLAS_MARKER = '[sub_resource type="AtlasTexture" id="AtlasTexture_emnp3"]'


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines(keepends=True)


def write_lines(path: Path, lines: list[str]) -> None:
    path.write_text("".join(lines), encoding="utf-8")


def build_base_cell() -> None:
    lines = read_lines(PLAYER)
    out: list[str] = []
    skip = False
    for line in lines:
        if line.startswith(GOLFER_NODE_MARKER) or line.startswith(BALL_NODE_MARKER):
            skip = True
            continue
        if skip:
            if line.startswith("[node ") and "Golfer" not in line and "Ball" not in line:
                skip = False
                out.append(line)
            continue
        line = line.replace("PlayerBayCell", "BaseCell")
        line = line.replace(
            "res://scripts/range/player_bay_cell.gd",
            "res://scripts/range/base_cell.gd",
        )
        out.append(line)
    write_lines(BASE_OUT, out)


def extract_ratina_golfer_block(range_lines: list[str]) -> list[str]:
    start = next(
        i
        for i, line in enumerate(range_lines)
        if line.startswith('[sub_resource type="AtlasTexture" id="AtlasTexture_rrjv2"]')
    )
    end = next(
        i
        for i, line in enumerate(range_lines)
        if line.startswith('[sub_resource type="SpriteFrames" id="SpriteFrames_tr6kw"]')
    )
    block = range_lines[start:end]
    return [
        line.replace("ExtResource(\"20_30071\")", 'ExtResource("3_8hsr7")')
        .replace("ExtResource(\"21_rlhax\")", 'ExtResource("4_emnp3")')
        .replace("ExtResource(\"22_qghjw\")", 'ExtResource("5_mdwt5")')
        for line in block
    ]


def build_ratina_bay_cell() -> None:
    player_lines = read_lines(PLAYER)
    range_lines = read_lines(RANGE_VIEW)

    header_end = next(
        i for i, line in enumerate(player_lines) if line.startswith(GOLFER_ATLAS_MARKER)
    )
    ball_frames_start = next(
        i
        for i, line in enumerate(player_lines)
        if line.startswith('[sub_resource type="SpriteFrames" id="SpriteFrames_8icwl"]')
    )
    nodes_start = next(
        i for i, line in enumerate(player_lines) if line.startswith("[node name=\"PlayerBayCell\"")
    )

    header = player_lines[:header_end]
    header[2] = header[2].replace(
        "res://scripts/range/player_bay_cell.gd",
        "res://scripts/range/ratina_bay_cell.gd",
    )
    header[4] = (
        '[ext_resource type="Texture2D" uid="uid://c4uo8nl7rg8yq" '
        'path="res://assets/sprites/ratina/ratina-swing-sheet.png" id="3_8hsr7"]\n'
    )
    header[5] = (
        '[ext_resource type="Texture2D" uid="uid://c4nlq8esrjkiy" '
        'path="res://assets/sprites/ratina/ratina-idle-sheet.png" id="4_emnp3"]\n'
    )
    header[6] = (
        '[ext_resource type="Texture2D" uid="uid://bx6uqxm3jx1fu" '
        'path="res://assets/sprites/ratina/ratina-waiting-sheet.png" id="5_mdwt5"]\n'
    )

    golfer_block = extract_ratina_golfer_block(range_lines)
    ball_and_nodes = player_lines[ball_frames_start:nodes_start]
    nodes = player_lines[nodes_start:]
    nodes = [
        line.replace("PlayerBayCell", "RatinaBayCell")
        .replace("SpriteFrames_1ksdi", "SpriteFrames_pwaj0")
        for line in nodes
    ]

    write_lines(RATINA_OUT, header + golfer_block + ball_and_nodes + nodes)


if __name__ == "__main__":
    build_base_cell()
    build_ratina_bay_cell()
    print("Wrote", BASE_OUT.relative_to(ROOT))
    print("Wrote", RATINA_OUT.relative_to(ROOT))
