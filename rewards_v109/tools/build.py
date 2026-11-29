"""Build Seal Drift with the harpoon transition limited to up-right."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v109"
BASE = VERSION.parent / "rewards_v108"
v108 = run_path(str(BASE / "tools/build.py"))
v105, v101, v107 = (v108[name] for name in ("v105", "v101", "v107"))


def overlay(program):
    program = v108["overlay"](program)
    module = "src/12_poacher.lua"
    old = (BASE / module).read_text(encoding="utf-8").rstrip()
    new = (VERSION / module).read_text(encoding="utf-8").rstrip()
    assert program.count(old) == 1, module
    return program.replace(old, new, 1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v107["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    build.__globals__.update(NAME=NAME, compile_code=v108["compile_code"])
    with TemporaryDirectory(prefix="seal-drift-v109-") as directory:
        build(None, Path(directory), args.output)
