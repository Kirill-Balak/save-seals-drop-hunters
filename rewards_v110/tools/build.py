"""Build the clean-start Seal Drift cart with four editable SFX slots."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v110"
v109 = run_path(str(VERSION.parent / "rewards_v109/tools/build.py"))
v108, v105, v101, v107 = (v109[name] for name in ("v108", "v105", "v101", "v107"))
SFX_FIRST_FREE = 60
FLAGS_START = 0x3000
FLAGS_END = 0x3100


def overlay(program):
    program = v109["overlay"](program)
    old = 'cartdata("seal_drift_campaign")'
    assert program.count(old) == 1
    return program.replace(old, 'cartdata("seal_drift_audio_v110")', 1)


def compile_code(cart, stars, scratch):
    v108["compile_code"](cart, stars, scratch)
    pipeline = v101["pipeline"]
    sfx_base = pipeline["SFX_BASE"]
    stride, notes = pipeline["SFX_STRIDE"], pipeline["SFX_NOTES"]
    first, end = pipeline["SFX_FIRST"], pipeline["SFX_END"]
    old = (
        f"for i = {first}, {end - 1} do\n"
        f"\tsfx_data ..= chr(peek({sfx_base}\n"
        f"\t+ i * {stride}, {notes}))\nend"
    )
    assert cart.code.count(old) == 1
    new = old.replace(f"{first}, {end - 1}", f"{first}, {SFX_FIRST_FREE - 1}", 1)
    new += f"\nsfx_data..=chr(peek({FLAGS_START},\n {FLAGS_END - FLAGS_START}))"
    cart.code = cart.code.replace(old, new, 1)

    assert not any(cart.rom[FLAGS_START:FLAGS_END])
    payload = bytearray()
    for slot in range(SFX_FIRST_FREE, end):
        address = sfx_base + slot * stride
        payload.extend(cart.rom[address:address + notes])
        cart.rom[address:address + stride] = bytes(stride)
    assert len(payload) == FLAGS_END - FLAGS_START
    cart.rom[FLAGS_START:FLAGS_END] = payload


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v107["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    build.__globals__.update(NAME=NAME, compile_code=compile_code)
    with TemporaryDirectory(prefix="seal-drift-v110-") as directory:
        build(None, Path(directory), args.output)
