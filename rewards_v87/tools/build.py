"""Build Seal Drift v87 with five visible palette colors."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v87"
v86 = run_path(str(ROOT / "rewards_v86/tools/build.py"))
v85, v84, v83 = v86["v85"], v86["v84"], v86["v83"]
builder, pipeline = v86["builder"], v86["pipeline"]
GFX_TAIL = v86["GFX_TAIL"]
INKS = {1, 7, 8, 9, 12}
ATLAS_COLORS = {5: 1, 6: 12, 13: 12}
POACHER_COLORS = {2: 8, 4: 9, 5: 1, 6: 7, 14: 8, 15: 7}


def source_code(stars):
    modules = {}
    for version in (74, 77, 80, 82, 83, 84, 85, 86, 87):
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


def recolor(rom, start, end, colors):
    ink = [colors.get(i, i) for i in range(16)]
    lookup = bytes(ink[byte & 15] | (ink[byte >> 4] << 4) for byte in range(256))
    pixels = bytes(rom[start:end]).translate(lookup)
    allowed = INKS | {0}
    assert all((byte & 15) in allowed and (byte >> 4) in allowed for byte in pixels)
    rom[start:end] = pixels


def compile_code(cart, stars, scratch):
    v86["install_rewards"](cart.rom, stars)
    recolor(cart.rom, 0, 64 * 64, ATLAS_COLORS)
    recolor(cart.rom, 64 * 64, 80 * 64, POACHER_COLORS)
    # Only the left half holds frames here. The right half holds grip coordinates.
    for y in range(80, 88):
        recolor(cart.rom, y * 64, y * 64 + 32, POACHER_COLORS)
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
    with TemporaryDirectory(prefix="seal-drift-v87-") as directory:
        v83["build"](args.label, Path(directory), args.output)
