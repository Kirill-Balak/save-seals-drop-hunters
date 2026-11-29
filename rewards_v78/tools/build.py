"""Build the single-file narrative cartridge from the readable Lua and ROM assets."""

import argparse
from fractions import Fraction
import json
from math import ceil, floor
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE_VERSION = ROOT.parent / "rewards_v74"
PREVIOUS = ROOT.parent / "rewards_v77"
sys.path.insert(0, str(BASE_VERSION / "tools"))
from inline_code import inline_program
from pico_cart import CartFormat, read_cart, read_cart_from_source, write_cart, write_cart_to_rom
from pico_compress import get_compressed_size
from pico_defs import from_p8str, to_p8str
from pico_srcdefs import Source
from pico_tokenize import count_tokens, tokenize
from utils import BinaryReader, BytesIO


SHRINKO = ROOT.parent / "rewards_v20/tools/vendor/shrinko8-main/shrinko8.py"
BASE = ROOT.parent / "rewards_v64/base_assets.p8"
ART = ROOT.parent / "rewards_v75/assets/shore-details.json"
COVER = ROOT.parent / "rewards_v76/seal_drift_v76.p8"
CART_NAME = "seal_drift_v78"
LITERAL_START, LITERAL_END = 0x0B80, 0x1000
EXTRA_ROWS = range(26, 46)
EXTRA_ROW_OFFSET = 30  # The legacy effects in these rows occupy x < 60.
HEADER = "pico-8 cartridge // http://www.pico-8.com\nversion 43\n__lua__\n"
BLOCKS = (
    ("function save_progress(", "-->8\n--gameplay"),
    ("gamestate.endgame = ", "-->8\n--objects"),
    ("function action_icon(", "atlas = split"),
    ("function lesson_setup(", "function ease("),
    ("function tutorial_draw(", "-->8\n--rewards"),
)

PALETTE = {
    (29, 43, 83): "1",
    (194, 195, 199): "6",
    (255, 241, 232): "7",
    (255, 0, 77): "8",
    (255, 163, 0): "9",
    (41, 173, 255): "c",
}


def sfx(speed, wave, notes, volume=5, effect=0, loop=0):
    return (
        f"00{speed:02x}00{loop:02x}"
        + "".join(f"{pitch:02x}{wave:x}{volume:x}{effect:x}" for pitch in notes)
        + "00000" * (32 - len(notes))
    )


def install_assets(cart):
    rows = [list(row) for row in (BASE_VERSION / "src/atlas.gfx").read_text().splitlines()]
    with Image.open(BASE_VERSION / "assets/atlas.png") as source:
        atlas = source.convert("RGBA")
        assert atlas.size == (128, 32)
        pixels = atlas.load()
        for y in range(atlas.height):
            assert all(c == "0" for c in rows[y + 64])
            for x in range(atlas.width):
                r, g, b, a = pixels[x, y]
                assert a in (0, 255)
                rows[y + 64][x] = PALETTE[(r, g, b)] if a else "0"
    install_seal_frames(rows)
    sounds = [
        sfx(2, 7, [17, 19, 15, 18], 4, 0, 4),
        sfx(4, 6, [30, 19, 16, 12], 6, 3),
        sfx(7, 2, [21, 24, 21, 24], 5),
        sfx(3, 6, [34, 30, 23, 16], 5, 3),
        sfx(6, 3, [29, 16, 12], 6, 3),
        sfx(5, 0, [28, 33, 40, 45], 5),
        sfx(6, 2, [22, 28, 34, 40], 5, 2),
        sfx(4, 2, [17, 19, 17], 3, 2),
        sfx(9, 0, [28, 32, 35, 40, 47], 6, 3),
        sfx(10, 3, [35, 27, 23, 16], 5, 3),
    ]
    resources = read_cart_from_source(
        HEADER + "__gfx__\n" + "\n".join(map("".join, rows))
        + "\n__sfx__\n" + "\n".join(sounds) + "\n"
    )
    cart.rom[:0x1800] = resources.rom[:0x1800]
    cart.rom[0x3200:] = resources.rom[0x3200:]


def install_seal_frames(rows):
    poses = {}
    for group in (ROOT / "assets/seal-frames.txt").read_text().strip().split("\n\n"):
        direction, *pixels = group.splitlines()
        if direction.startswith("#"):
            continue
        assert len(pixels) == 8 and all(len(row.split()) == 4 for row in pixels)
        poses[direction] = list(zip(*(row.split() for row in pixels)))

    # The other three headings mirror the corresponding east-facing art.
    headings = ("e", "ne", "n", "ne", "e", "se", "s", "se")
    # Cells 0-15 held legacy triangles. The active result stars start at y=9.
    for face, heading in enumerate(headings):
        for base, pose in zip((128, 136, 0, 8), poses[heading]):
            slot = base + face
            x, y = slot % 16 * 8, slot // 16 * 8
            for row, pixels in zip(rows[y:y+8], pose):
                assert len(pixels) == 8 and set(pixels) <= set("0167")
                row[x:x+8] = pixels[::-1] if face in (3, 4, 5) else pixels


def run(*args, **kwargs):
    subprocess.run([sys.executable, "-B", *map(str, args)], check=True, **kwargs)


def ice_art_lua():
    levels = json.loads(ART.read_text())
    assert len(levels) == 6

    def pack_shape(shade, points):
        data = [shade]
        for point in points:
            data.extend(point)
        lines, line = [], ""
        for value in data:
            assert 0 <= value < 128
            character = chr(value + 40)
            candidate = line + character
            if len(from_p8str(candidate)) > 27 or "]]" in candidate:
                lines.append(from_p8str(line))
                line = character
            else:
                line = candidate
        lines.append(from_p8str(line))
        return "\n".join(lines)

    encoded = []
    for level in levels:
        snow = []
        for polygon in level["snow"]:
            edges = list(zip(polygon, polygon[1:] + polygon[:1]))
            for y in range(12, 124):
                xs = [
                    x0 + Fraction((y-y0)*(x1-x0), y1-y0)
                    for (x0, y0), (x1, y1) in edges if (y0>y) != (y1>y)
                ]
                if xs:
                    left, right = max(4, ceil(min(xs))), min(99, floor(max(xs)))
                    if left <= right:
                        snow.append((left, y, right))
        shapes = [pack_shape(7, snow)]
        chips = [point for cluster in level["chips"] for point in cluster]
        if chips:
            shapes.append(pack_shape(0, chips))
        encoded.append("\n!\n".join(shapes))
    return 'ice_art=split([[\n' + '#\n'.join(encoded) + '\n]],"#",false)\n'


def build(label, scratch):
    modules = {path.name: path for path in (BASE_VERSION / "src").glob("*.lua")}
    modules.update({path.name: path for path in (PREVIOUS / "src").glob("*.lua")})
    modules.update({path.name: path for path in (ROOT / "src").glob("*.lua")})
    code = "\n".join(modules[name].read_text(encoding="utf-8").rstrip() for name in sorted(modules))
    code = code.replace("function save_progress(", ice_art_lua() + "function save_progress(", 1)
    source = scratch / "source.p8"
    source.write_text(inline_program(HEADER + code + "\n"), encoding="utf-8")
    compact, pretty = (scratch / name for name in ("compact.p8", "native.p8"))
    run(SHRINKO, source, compact, "--minify", "--focus-tokens", "--no-minify-rename",
        "--no-minify-lines", "--no-minify-spaces", "--no-minify-comments")
    run(SHRINKO, compact, pretty, "--unminify", "--unminify-indent", "1")
    native = from_p8str(read_cart(str(pretty)).code)
    blocks = [(native.index(start), native.index(end, native.index(start))) for start, end in BLOCKS]
    for a, b in sorted(blocks, reverse=True):
        opts = "rom_ranges=0x2000:0x3000,0x1800:0x2000,0x3000:0x3100 compress"
        native = native[:a] + f"--$switch-compiler: parens8 {opts}\n" + native[a:b] + "--$switch-compiler: none\n" + native[b:]

    cart = read_cart(str(BASE))
    install_assets(cart)
    assert not any(cart.rom[0x3000:0x3100])
    cart.code = to_p8str(native)
    prepared, hybrid = (scratch / name for name in ("hybrid-source.p8", "hybrid.p8"))
    write_cart(str(prepared), cart, CartFormat.p8)
    env = os.environ.copy()
    env["PYTHONPATH"] = os.environ.get(
        "SEAL_DRIFT_TOOLCHAIN", str(ROOT.parent / "rewards_v66/checks/toolchain")
    )
    run("-m", "shrinko.shrinko8", prepared, hybrid, "--minify-transform-only", "--count", env=env)
    wrapped = scratch / "wrapped.p8"
    literals = scratch / "packed-literals.bin"
    run(PREVIOUS / "tools/wrap.py", hybrid, wrapped, literals,
        LITERAL_START, LITERAL_END, EXTRA_ROWS.start, EXTRA_ROWS.stop, EXTRA_ROW_OFFSET)
    packaged = read_cart(str(hybrid))
    assert packaged.rom[:0x1800] == cart.rom[:0x1800]
    assert packaged.rom[0x3100:] == cart.rom[0x3100:]
    data = literals.read_bytes()
    ranges = [(LITERAL_START, LITERAL_END)]
    ranges.extend((y * 64 + EXTRA_ROW_OFFSET, (y + 1) * 64) for y in EXTRA_ROWS)
    literal_capacity = sum(end - start for start, end in ranges)
    assert len(data) <= literal_capacity, (len(data), literal_capacity)
    offset = 0
    for start, end in ranges:
        assert not any(packaged.rom[start:end])
        part = data[offset:offset + end - start]
        packaged.rom[start:start + len(part)] = part
        offset += len(part)
    packaged.code = read_cart(str(wrapped)).code
    if label:
        packaged.label = read_cart(str(label), CartFormat.label).label
    else:
        packaged.label = read_cart(str(COVER)).label
    tokens, errors = tokenize(Source(CART_NAME, packaged.code))
    assert not errors, errors
    rom = write_cart_to_rom(packaged)
    metrics = {
        "tokens": count_tokens(tokens),
        "compressed_bytes": get_compressed_size(BinaryReader(BytesIO(rom[len(packaged.rom):]), big_end=True)),
        "longest_line": max(map(len, packaged.code.split("\n"))),
    }
    assert metrics["tokens"] <= 8192 and metrics["compressed_bytes"] < 15360 and metrics["longest_line"] <= 30, metrics
    text = ROOT / f"{CART_NAME}.p8"
    write_cart(str(text), packaged, CartFormat.p8)
    decoded = read_cart(str(text))
    assert decoded.code == packaged.code and decoded.rom == packaged.rom
    print(metrics)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    with TemporaryDirectory(prefix="seal-drift-build-") as folder:
        build(parser.parse_args().label, Path(folder))
