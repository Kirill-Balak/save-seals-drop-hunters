"""Draw two copies of the single-poacher icon on the combo result row."""

import argparse
from functools import partial
from pathlib import Path
import re
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v118"
v117 = run_path(str(VERSION.parent / "rewards_v117/tools/build.py"))
v116, v115, v114, v112, v111, v108, v105, v101 = (
    v117[name] for name in ("v116", "v115", "v114", "v112", "v111", "v108", "v105", "v101")
)


def overlay(program):
    program = v116["overlay"](program)
    source = (VERSION / "src/result_reward_icon.lua").read_text(encoding="utf-8").rstrip()

    def bind(m):
        icons = re.sub(r"\b(row|y)\b", lambda name: m[name[0]], source)
        return icons.replace("-- count_label", m["count_label"])

    pattern = (
        r"reward_icon\((?P<row>j_\d+_\d+)\+1,22,(?P<y>y_\d+_\d+)\)\n"
        r"\t\tif (?P=row)!=2 then\n\t\t\t(?P<count_label>print\([\s\S]*?)\n\t\tend"
    )
    program, count = re.subn(pattern, bind, program)
    assert count == 1
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
        import_music=v114["music_with_cues"], install_atlas=v114["install_atlas"],
    )
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(v112["source_code"], scope["source_code"], frames),
        compile_code=partial(v115["compile_code"], frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v118-") as directory:
        build(None, Path(directory), args.output)
