"""Use one icon axis for the magnet placement panel."""

import argparse
from functools import partial
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "save_seals_drop_hunters_v123"
v122 = run_path(str(VERSION.parent / "rewards_v122/tools/build.py"))
v120, v119, v117, v114, v112, v111, v108, v105, v101 = (
    v122[name] for name in ("v120", "v119", "v117", "v114", "v112", "v111", "v108", "v105", "v101")
)


def overlay(program):
    program = v122["overlay"](program)
    # The compact keyboard hint fits left of the shared placement axis.
    for old, new in (
        ('print("(",110,y_17_4,col_17_7) print("z)",113,y_17_4,col_17_7)',
         'print("\\^:429d9189859d4200",110,y_17_4-1,col_17_7)'),
        ("magnet_icon(k_17_3==4 and 124 or 120,y_17_8,", "magnet_icon(122,y_17_8,"),
        ("line(124-5,y_17_8+6,124-5+hold_o/2", "line(122-5,y_17_8+6,122-5+hold_o/2"),
        ("circ(120,y_17_8,3,9)", "circ(122,y_17_8,3,9)"),
    ):
        assert program.count(old) == 1, old
        program = program.replace(old, new, 1)
    return program


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
    with TemporaryDirectory(prefix="seal-drift-v123-") as directory:
        build(None, Path(directory), args.output)
