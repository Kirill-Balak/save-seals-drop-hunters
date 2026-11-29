"""Tighten the keyboard and magnet labels in the right panel."""

import argparse
from functools import partial
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "save_seals_drop_hunters_v120"
TITLE = "Save Seals, Drop Hunters!"
SAVE_ID = "save_seals_drop_hunters"
v119 = run_path(str(VERSION.parent / "rewards_v119/tools/build.py"))
v117, v114, v112, v111, v108, v105, v101 = (
    v119[name] for name in ("v117", "v114", "v112", "v111", "v108", "v105", "v101")
)


def overlay(program):
    program = v119["overlay"](program)
    for old, new in (
        ('print("(z)",109,y_17_4,col_17_7)', 'print("z",110,y_17_4,col_17_7)'),
        ("magnet_icon(124,y_17_8,", "magnet_icon(120,y_17_8,"),
        ("line(124-5,y_17_8+6,124-5+hold_o/2", "line(120-5,y_17_8+6,120-5+hold_o/2"),
        ('cartdata("seal_drift_audio_v110")', f'cartdata("{SAVE_ID}")'),
    ):
        assert program.count(old) == 1, old
        program = program.replace(old, new, 1)
    return program


def compile_code(frames, cart, stars, scratch):
    v119["compile_code"](frames, cart, stars, scratch)
    assert cart.code.startswith("--seal drift\n")
    cart.code = "--" + TITLE + "\n" + cart.code.split("\n", 1)[1]


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
        compile_code=partial(compile_code, frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v120-") as directory:
        build(None, Path(directory), args.output)
