"""Build Seal Drift v108 with the supplied poacher and harpoon sprites."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory

from PIL import Image


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v108"
v107 = run_path(str(ROOT / "rewards_v107/tools/build.py"))
v105 = v107["base"]
v101 = v105["v101"]
set_pixel = v105["set_pixel"]
base_unused_spans = v101["unused_spans"]
INKS = {
    (0, 0, 0, 0): 0,
    (29, 43, 83, 255): 1,
    (255, 241, 232, 255): 7,
    (255, 0, 77, 255): 8,
    (255, 163, 0, 255): 9,
    (255, 255, 255, 255): 7,
}
PROJECTILES = (
    # Number, size and offset. The trailing pixel lands at (3, 3).
    (2, (6, 5), (2, 1)),
    (3, (6, 5), (2, 0)),
    (4, (5, 6), (1, -1)),
    (1, (6, 5), (2, 2)),
)
FIRST_PROJECTILE = 40
RECOIL_GRIPS = ((4, 3), (4, 4), (3, 4), (4, 4), (3, 4))


def overlay(program):
    for name, version in (("11_rescue.lua", 104), ("12_poacher.lua", 94)):
        old = (ROOT / f"rewards_v{version}/src" / name).read_text(encoding="utf-8").rstrip()
        new = (VERSION / "src" / name).read_text(encoding="utf-8").rstrip()
        assert program.count(old) == 1, name
        program = program.replace(old, new, 1)
    return v105["overlay"](program)


def unused_spans(rom, stars):
    # Reserve every byte of the four tiles, including the transparent pixels.
    available = {addr for start, size in base_unused_spans(rom, stars)
                 for addr in range(start, start + size)}
    masked = bytearray(rom)
    x, y = FIRST_PROJECTILE % 16 * 4, FIRST_PROJECTILE // 16 * 8
    width = 4 * len(PROJECTILES)
    for row in range(y, y + 8):
        start = row * 64 + x
        assert all(addr in available for addr in range(start, start + width))
        masked[start:start + width] = bytes([255]) * width
    return base_unused_spans(masked, stars)


def install_sprite(rom, tile, path, size=(8, 8), offset=(0, 0)):
    with Image.open(VERSION / "assets" / path) as source:
        assert source.size == size, path
        pixels = source.convert("RGBA").get_flattened_data()
    tx, ty = tile % 16 * 8, tile // 16 * 8
    for index, pixel in enumerate(pixels):
        assert pixel in INKS, (path, pixel)
        ink = INKS[pixel]
        x, y = index % size[0] + offset[0], index // size[0] + offset[1]
        if 0 <= x < 8 and 0 <= y < 8:
            set_pixel(rom, tx + x, ty + y, ink)
        else:
            assert ink == 0, (path, x, y)


def compile_code(cart, stars, scratch):
    v105["compile_code"](cart, stars, scratch)
    for tile in range(128, 168):
        install_sprite(cart.rom, tile, f"poacher/{tile}.png")
    for tile, (number, size, offset) in enumerate(PROJECTILES, FIRST_PROJECTILE):
        install_sprite(cart.rom, tile, f"harpoon/{number}.png", size, offset)
    # Phase 6 metadata still supplies the v107 magnet model.
    for row, (x, y) in enumerate(RECOIL_GRIPS):
        column = 64 + 8 * row + 7
        set_pixel(cart.rom, column, 80, x)
        set_pixel(cart.rom, column, 81, y)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v107["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = unused_spans
    build.__globals__.update(NAME=NAME, compile_code=compile_code)
    with TemporaryDirectory(prefix="seal-drift-v108-") as directory:
        build(None, Path(directory), args.output)
