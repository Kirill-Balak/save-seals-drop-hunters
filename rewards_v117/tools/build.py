"""Build Seal Drift with wider bridges in the campaign layouts."""

import argparse
from functools import partial
import json
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v117"
v116 = run_path(str(VERSION.parent / "rewards_v116/tools/build.py"))
v114, v112, v111, v108, v105, v101, v115 = (
    v116[name] for name in ("v114", "v112", "v111", "v108", "v105", "v101", "v115")
)


def load_levels():
    return json.loads((VERSION / "assets/levels.json").read_text(encoding="utf-8"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    frames = v112["saw_frames"]()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = load_levels
    v105["v104"]["overlay"].__globals__["assemble"] = v116["overlay"]
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    v111["compile_code"].__globals__.update(
        import_music=v114["music_with_cues"], install_atlas=v114["install_atlas"],
    )
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(v112["source_code"], scope["source_code"], frames),
        compile_code=partial(v115["compile_code"], frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v117-") as directory:
        build(None, Path(directory), args.output)
