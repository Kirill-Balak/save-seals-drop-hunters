"""Build Seal Drift v88 with higher contrast for seals, reward icons and saws."""

import argparse
import json
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
BASE = VERSION.parent / "rewards_v87"
NAME = "seal_drift_v88"
v87 = run_path(str(BASE / "tools/build.py"))
v85, v84, v83 = v87["v85"], v87["v84"], v87["v83"]
builder, pipeline = v87["builder"], v87["pipeline"]
inline = builder.inline_program
set_pixel = v87["v86"]["set_pixel"]
HEADINGS = {"e": (0, 4), "ne": (1, 3), "n": (2,), "se": (7, 5), "s": (6,)}


def inline_with_results(program):
    module = "src/08_rewards.lua"
    old = (BASE / module).read_text(encoding="utf-8").rstrip()
    new = (VERSION / module).read_text(encoding="utf-8").rstrip()
    assert program.count(old) == 1
    return inline(program.replace(old, new, 1))


def replace_blue(rom, x, y, w, h):
    for py in range(y, y + h):
        for px in range(x, x + w):
            shift = px % 2 * 4
            if ((rom[py * 64 + px // 2] >> shift) & 15) == 12:
                set_pixel(rom, px, py, 7)


def install_seal_pixels(rom, asset):
    poses = json.loads((VERSION / "assets" / asset).read_text(encoding="utf-8"))
    assert poses.keys() == HEADINGS.keys()
    for heading, frames in poses.items():
        assert len(frames) == 4
        for mirror, face in enumerate(HEADINGS[heading]):
            for phase, rows in enumerate(frames):
                tile = 4 + 4 * face + phase
                dx, dy = tile % 16 * 8, tile // 16 * 8
                for row, pixels in rows.items():
                    assert 0 <= int(row) < 8 and 1 <= len(pixels) <= 8 and set(pixels) <= set(".017")
                    for x, ink in enumerate(pixels):
                        if ink != ".":
                            set_pixel(rom, dx + (7 - x if mirror else x), dy + int(row), int(ink))


def compile_code(cart, stars, scratch):
    v87["compile_code"](cart, stars, scratch)
    for i in range(4, 36):
        replace_blue(cart.rom, i % 16 * 8, i // 16 * 8, 8, 8)
    install_seal_pixels(cart.rom, "seal-hind-flippers.json")
    install_seal_pixels(cart.rom, "seal-muzzles.json")
    for x, y, w, h, _, _ in pipeline["SAW"]:
        replace_blue(cart.rom, x, y, w, h)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    builder.inline_program = inline_with_results
    gfx_tail = v87["GFX_TAIL"]
    v83["build"].__globals__.update(
        NAME=NAME, install_poachers=v84["install_poachers"], source_code=v87["source_code"],
        compile_code=compile_code, GFX_TAIL=gfx_tail,
        ROM_LITERAL_SIZE=v83["MAP_END"] - gfx_tail, load_literals=v85["load_literals"],
    )
    with TemporaryDirectory(prefix="seal-drift-v88-") as directory:
        v83["build"](args.label, Path(directory), args.output)
