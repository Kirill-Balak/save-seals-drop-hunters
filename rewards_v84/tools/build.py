"""Build the v83 game with 8x8 poachers and named PICO-8 editor tabs."""

import argparse
import json
from pathlib import Path
import re
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
BASE = VERSION.parent / "rewards_v83"
NAME = "seal_drift_v84"
base = run_path(str(BASE / "tools/build.py"))
builder = base["builder"]

TAB_STARTS = (
    ("ice_art =", "campaign"),
    ("function ps8_const(", "parens-8 vm"),
    ("gamestate.gameplay =", "gameplay"),
    ("function collide(", "objects"),
    ("function length(", "ice geometry"),
    ("function draw_scene(", "ui"),
    ("function lesson_setup(", "tutorial"),
)


def install_poachers(cart):
    # Preserve the original installer and its removal of the v82 sprites.
    base["install_poachers"](cart)
    recipe = json.loads((VERSION / "assets/poacher.pixel.json").read_text(encoding="utf-8"))
    assert (recipe["width"], recipe["height"]) == (8, 8)
    expected = [f"{head}-{phase}" for head in base["HEADINGS"] for phase in base["PHASES"]]
    assert [frame["name"] for frame in recipe["frames"]] == expected
    palette = base["PALETTE"]
    for key, index in palette.items():
        if index != "0":
            color = base["k_palette"][int(index, 16)]
            assert recipe["palette"][key].lower() == f"#{color.r:02x}{color.g:02x}{color.b:02x}"
    rows = [list("0" * 128) for _ in range(128)]

    for i, frame in enumerate(recipe["frames"]):
        grid, = frame["ops"]
        assert frame["anchor"] == [4, 4] and grid["op"] == "grid" and grid["x"] == grid["y"] == 0
        pixels = grid["rows"]
        assert len(pixels) == 8 and all(len(row) == 8 for row in pixels)
        (gx, gy), = [(x, y) for y, row in enumerate(pixels) for x, c in enumerate(row) if c == "g"]
        dx, dy = i % 16 * 8, 64 + i // 16 * 8
        for j, row in enumerate(pixels):
            rows[dy + j][dx:dx + 8] = [palette[c] for c in row]
        rows[80][i + 64], rows[81][i + 64] = format(gx, "x"), format(gy, "x")

    sprites = builder.read_cart_from_source(builder.HEADER + "__gfx__\n" + "\n".join(map("".join, rows)) + "\n")
    cart.rom[0x1000:base["MAP_START"]] = sprites.rom[0x1000:base["MAP_START"]]


def source_code(stars):
    code = base["source_code"](stars)
    previous = (BASE / "src/12_poacher.lua").read_text(encoding="utf-8").rstrip()
    current = (VERSION / "src/12_poacher.lua").read_text(encoding="utf-8").rstrip()
    assert code.count(previous) == 1
    return code.replace(previous, current, 1)


def compile_code(cart, stars, scratch):
    base["compile_code"](cart, stars, scratch)
    # The minifier drops comments. Restore tab breaks at statement boundaries
    # after wrapping so they cannot split an instruction or packed literal.
    code = cart.code
    for start, title in TAB_STARTS:
        code, count = re.subn(rf"(?m)^(?={re.escape(start)})", f"-->8\n--{title}\n", code)
        assert count == 1, start
    calls = list(re.finditer(r"(?m)^run_ps8\(", code))
    assert len(calls) == 5
    at = calls[-3].start()
    cart.code = code[:at] + "-->8\n--packed code\n" + code[at:]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    # Install the v84 stages in the isolated copy of the v83 pipeline.
    base["build"].__globals__.update(
        NAME=NAME, install_poachers=install_poachers, source_code=source_code, compile_code=compile_code
    )
    with TemporaryDirectory(prefix="seal-drift-v84-") as directory:
        base["build"](args.label, Path(directory), args.output)
