"""Name the pause-menu shortcuts and show both magnet controls in training."""

import argparse
from functools import partial
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "save_seals_drop_hunters_v121"
v120 = run_path(str(VERSION.parent / "rewards_v120/tools/build.py"))
v119, v117, v114, v112, v111, v108, v105, v101 = (
    v120[name] for name in ("v119", "v117", "v114", "v112", "v111", "v108", "v105", "v101")
)


def overlay(program):
    program = v120["overlay"](program)
    for old, new in (
        ('menuitem(0x301,"★",', 'menuitem(0x301,"levels",'),
        ('menuitem(0x302,"⬅️➡️",', 'menuitem(0x302,"tutorial",'),
    ):
        occurrences = program.count(old)
        assert occurrences, old
        program = program.replace(old, new)
    for old, new in (
        ("\tlocal selecting_17_1=magnet_lesson_17_0 and placing\n", ""),
        ("(not selecting_17_1 or k_17_3!=5) and\n\t\t\t", ""),
        ("selecting_17_1 and k_17_3==4 and 5 or k_17_3", "k_17_3"),
        ('print("z",110,y_17_4,col_17_7)', 'print("(z)",109,y_17_4,col_17_7)'),
        ("magnet_icon(120,y_17_8,", "magnet_icon(k_17_3==4 and 124 or 120,y_17_8,"),
        ("line(120-5,y_17_8+6,120-5+hold_o/2", "line(124-5,y_17_8+6,124-5+hold_o/2"),
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
    with TemporaryDirectory(prefix="seal-drift-v121-") as directory:
        build(None, Path(directory), args.output)
