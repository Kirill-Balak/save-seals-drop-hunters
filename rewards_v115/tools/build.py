"""Play a sharper ice crack when the separated ice first animates."""

import argparse
from functools import partial
import json
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v115"
v114 = run_path(str(VERSION.parent / "rewards_v114/tools/build.py"))
v113, v112, v111, v108, v105, v101, v107 = (
    v114[name] for name in ("v113", "v112", "v111", "v108", "v105", "v101", "v107")
)
builder = v114["builder"]


def overlay(program):
    program = v114["overlay"](program)
    early = "ice=newice\n\tsfx(1,2)"
    visible = "ghostlife=16"
    assert program.count(early) == program.count(visible) == 1
    return program.replace(early, "ice=newice").replace(visible, visible + "\n\tsfx(1,2)")


def compile_code(frames, cart, stars, scratch):
    v113["compile_code"](frames, cart, stars, scratch)
    recipe = json.loads((VERSION / "assets/ice_crack.json").read_text(encoding="utf-8"))
    row = v113["effect_row"](recipe)
    effect = builder.read_cart_from_source(builder.HEADER + "__sfx__\n" + row + "\n")
    start, size = v111["SFX_START"], v111["SFX_STRIDE"]
    cart.rom[start + size:start + 2 * size] = effect.rom[start:start + size]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    frames = v112["saw_frames"]()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v107["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    v111["compile_code"].__globals__.update(
        import_music=v114["music_with_cues"], install_atlas=v114["install_atlas"],
    )
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(v112["source_code"], scope["source_code"], frames),
        compile_code=partial(compile_code, frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v115-") as directory:
        build(None, Path(directory), args.output)
