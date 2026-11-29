"""Build the revised level layouts with the shared Seal Drift pipeline."""

import argparse
import json
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v107"
base = run_path(str(VERSION.parent / "rewards_v105/tools/build.py"))


def load_levels():
    return json.loads((VERSION / "assets/levels.json").read_text(encoding="utf-8"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    build = base["configure"]()
    base["campaign_source"].__globals__["load_levels"] = load_levels
    build.__globals__["NAME"] = NAME
    with TemporaryDirectory(prefix="seal-drift-v107-") as directory:
        build(None, Path(directory), args.output)
