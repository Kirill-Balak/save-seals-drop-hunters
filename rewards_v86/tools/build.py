"""Build Seal Drift v86 with shared reward icons and orange stars."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v86"
v85 = run_path(str(ROOT / "rewards_v85/tools/build.py"))
v84, v83 = v85["v84"], v85["v83"]
builder, pipeline = v85["builder"], v85["pipeline"]
GFX_TAIL = v85["GFX_TAIL"]


def source_code(stars):
    modules = {}
    for version in (74, 77, 80, 82, 83, 84, 85, 86):
        modules.update({path.name: path for path in (ROOT / f"rewards_v{version}/src").glob("*.lua")})
    code = "\n".join(modules[name].read_text(encoding="utf-8").rstrip() for name in sorted(modules))
    marker = "function save_progress("
    code = code.replace(marker, builder.ice_art_lua() + marker, 1)
    code = builder.inline_program(builder.HEADER + code + "\n")
    blocks = pipeline["BLOCKS"] + (("-->8\n--rewards", "function release_line("),)
    spans = [(code.index(start), code.index(end) if end else len(code)) for start, end in blocks]
    start = pipeline["PAYLOAD_START"]
    options = f"rom_ranges={start}:{start + pipeline['PAYLOAD_SIZE']} compress"
    for left, right in sorted(spans, reverse=True):
        code = code[:left] + f"--$switch-compiler: parens8 {options}\n" + code[left:right] + "\n--$switch-compiler: none\n" + code[right:]
    table = pipeline["atlas_table"]
    atlas = table("saw_atlas", pipeline["SAW"]) + table("star_atlas", stars)
    return code.replace("--core\n", "--core\n" + atlas, 1)


def set_pixel(rom, x, y, ink):
    addr = y * 64 + x // 2
    shift = x % 2 * 4
    rom[addr] = (rom[addr] & ~(15 << shift)) | (ink << shift)


def install_rewards(rom, stars):
    """Retain the sprite-animation geometry and change only its palette indices."""
    outlines = {stars[0][:4], stars[10][:4]}
    earned = {frame[:4] for i, frame in enumerate(stars) if i not in (0, 10)}
    assert outlines.isdisjoint(earned)
    for rectangles, ink in ((outlines, 13), (earned, 9)):
        for x, y, w, h in sorted(rectangles):
            for py in range(y, y + h):
                for px in range(x, x + w):
                    color = (rom[64 * py + px // 2] >> (4 * (px % 2))) & 15
                    assert color in (0, 7)
                    if color:
                        set_pixel(rom, px, py, ink)

    rows = (VERSION / "assets/ice-reward.txt").read_text(encoding="ascii").splitlines()
    assert len(rows) == 8 and all(len(row) == 8 for row in rows)
    for y, row in enumerate(rows, 16):
        assert not any(rom[64 * y + 16:64 * y + 20])
        for x, color in enumerate(row, 32):
            set_pixel(rom, x, y, int(color, 16))


def compile_code(cart, stars, scratch):
    install_rewards(cart.rom, stars)
    v84["compile_code"](cart, stars, scratch)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    v83["build"].__globals__.update(
        NAME=NAME, install_poachers=v84["install_poachers"], source_code=source_code,
        compile_code=compile_code, GFX_TAIL=GFX_TAIL,
        ROM_LITERAL_SIZE=v83["MAP_END"] - GFX_TAIL, load_literals=v85["load_literals"],
    )
    with TemporaryDirectory(prefix="seal-drift-v86-") as directory:
        v83["build"](args.label, Path(directory), args.output)
