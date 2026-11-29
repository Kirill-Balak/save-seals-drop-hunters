"""Build Seal Drift v90 with v86 side poses and blue result screens."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v90"
v89 = run_path(str(ROOT / "rewards_v89/tools/build.py"))
builder = v89["builder"]
v88, v87, v85, v84, v83 = (v89[version] for version in ("v88", "v87", "v85", "v84", "v83"))


def inline_with_results(program):
    module = v89["RESULTS"]
    old = (v88["BASE"] / module).read_text(encoding="utf-8").rstrip()
    new = (VERSION / module).read_text(encoding="utf-8").rstrip()
    assert program.count(old) == 1
    return v88["inline"](program.replace(old, new, 1))


def compile_code(cart, stars, scratch):
    v88["compile_code"](cart, stars, scratch)
    legacy = builder.read_cart(str(ROOT / "rewards_v86/seal_frames.p8"))
    for first_tile in (4, 20):  # Four east frames, then four west frames.
        x_byte = first_tile % 16 * 4
        y = first_tile // 16 * 8
        for row in range(y, y + 8):
            start = row * 64 + x_byte
            end = start + 16
            v87["recolor"](legacy.rom, start, end, {6: 7})
            cart.rom[start:end] = legacy.rom[start:end]


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
    with TemporaryDirectory(prefix="seal-drift-v90-") as directory:
        v83["build"](args.label, Path(directory), args.output)
