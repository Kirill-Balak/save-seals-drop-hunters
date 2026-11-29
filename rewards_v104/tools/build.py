"""Build the silhouette, magnet-preview and scoring experiment."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v104"
v103 = run_path(str(ROOT / "rewards_v103/tools/build.py"))
v102, v101 = v103["v102"], v103["v101"]
assemble = v103["assemble"]
base_campaign_source = v101["campaign_source"]
BASES = {
    "01_splashscreen.lua": 102,
    "02_gameplay.lua": 85,
    "06_ui.lua": 101,
    "07_tutorial.lua": 101,
    "08_rewards.lua": 102,
    "11_rescue.lua": 103,
}


def campaign_source(previous):
    scope = base_campaign_source.__globals__
    original = scope["VERSION"]
    scope["VERSION"] = VERSION
    try:
        return base_campaign_source(previous)
    finally:
        scope["VERSION"] = original


def overlay(program):
    for name, version in BASES.items():
        old = (ROOT / f"rewards_v{version}/src" / name).read_text(encoding="utf-8").rstrip()
        new = (VERSION / "src" / name).read_text(encoding="utf-8").rstrip()
        if name == "01_splashscreen.lua":
            previous = (ROOT / "rewards_v94/src" / name).read_text(encoding="utf-8")
            data = campaign_source(previous)
            art = v101["builder"].ice_art_lua()
            entry = "function load_progress("
            old = old.replace("--campaign data", data, 1).replace(entry, art + entry, 1)
            new = new.replace("--campaign data", data, 1).replace(entry, art + entry, 1)
        assert program.count(old) == 1, name
        program = program.replace(old, new, 1)
    return assemble(program)


def configure():
    v101["configure"]()
    v101["overlay"].__globals__["campaign_source"] = campaign_source
    v101["campaign_source"] = campaign_source
    v101["overlay"].__globals__["original_inline"] = v102["overlay"]
    v102["overlay"].__globals__["assemble"] = v103["overlay"]
    v103["overlay"].__globals__["assemble"] = overlay
    build = v101["v83"]["build"]
    build.__globals__["NAME"] = NAME
    return build


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    build = configure()
    with TemporaryDirectory(prefix="seal-drift-v104-") as directory:
        build(None, Path(directory), args.output)
