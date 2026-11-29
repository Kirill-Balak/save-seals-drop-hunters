"""Leave a one-pixel gap between O and the opening parenthesis."""

import argparse
from functools import partial
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "save_seals_drop_hunters_v122"
v121 = run_path(str(VERSION.parent / "rewards_v121/tools/build.py"))
v120, v119, v117, v114, v112, v111, v108, v105, v101 = (
    v121[name] for name in ("v120", "v119", "v117", "v114", "v112", "v111", "v108", "v105", "v101")
)


def overlay(program):
    program = v121["overlay"](program)
    old = 'print("(z)",109,y_17_4,col_17_7)'
    new = 'print("(",110,y_17_4,col_17_7) print("z)",113,y_17_4,col_17_7)'
    assert program.count(old) == 1
    return program.replace(old, new, 1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    frames = v112["saw_frames"]()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v117["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    v111["compile_code"].__globals__.update(
        import_music=v114["music_with_cues"], install_atlas=v119["install_atlas"],
    )
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(v112["source_code"], scope["source_code"], frames),
        compile_code=partial(v120["compile_code"], frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v122-") as directory:
        build(None, Path(directory), args.output)
