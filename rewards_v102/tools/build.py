"""Build Seal Drift with an isolated campaign save."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
BASE = VERSION.parent / "rewards_v101"
NAME = "seal_drift_v102"
v101 = run_path(str(BASE / "tools/build.py"))
assemble = v101["original_inline"]


def overlay(program):
    for path in sorted((VERSION / "src").glob("*.lua")):
        old = (BASE / "src" / path.name).read_text(encoding="utf-8").rstrip()
        new = path.read_text(encoding="utf-8").rstrip()
        if path.name == "01_splashscreen.lua":
            marker = "--campaign data"
            original = (v101["v94"]["VERSION"] / "src" / path.name).read_text(encoding="utf-8")
            data = v101["campaign_source"](original)
            art = v101["builder"].ice_art_lua()
            old = old.replace(marker, data, 1).replace("function load_progress(", art + "function load_progress(", 1)
            new = new.replace(marker, data, 1).replace("function load_progress(", art + "function load_progress(", 1)
        assert program.count(old) == 1, path
        program = program.replace(old, new, 1)
    return assemble(program)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    v101["configure"]()
    v101["overlay"].__globals__["original_inline"] = overlay
    build = v101["v83"]["build"]
    build.__globals__["NAME"] = NAME
    with TemporaryDirectory(prefix="seal-drift-v102-") as directory:
        build(None, Path(directory), args.output)
