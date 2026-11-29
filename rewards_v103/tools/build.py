"""Build Seal Drift with attempt-local charge restored on retry."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v103"
v102 = run_path(str(ROOT / "rewards_v102/tools/build.py"))
v101 = v102["v101"]
assemble = v102["assemble"]
BASES = {"03_endgame.lua": 101, "11_rescue.lua": 102}


def overlay(program):
    for name, version in BASES.items():
        old = (ROOT / f"rewards_v{version}/src" / name).read_text(encoding="utf-8").rstrip()
        new = (VERSION / "src" / name).read_text(encoding="utf-8").rstrip()
        assert program.count(old) == 1, name
        program = program.replace(old, new, 1)
    return assemble(program)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    v101["configure"]()
    v101["overlay"].__globals__["original_inline"] = v102["overlay"]
    v102["overlay"].__globals__["assemble"] = overlay
    build = v101["v83"]["build"]
    build.__globals__["NAME"] = NAME
    with TemporaryDirectory(prefix="seal-drift-v103-") as directory:
        build(None, Path(directory), args.output)
