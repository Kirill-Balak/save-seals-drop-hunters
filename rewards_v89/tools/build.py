"""Build Seal Drift v89 with transparent, high-contrast result icons."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
BASE = VERSION.parent / "rewards_v88"
NAME = "seal_drift_v89"
RESULTS = "src/08_rewards.lua"
v88 = run_path(str(BASE / "tools/build.py"))
builder = v88["builder"]
v87, v85, v84, v83 = (v88[version] for version in ("v87", "v85", "v84", "v83"))


def inline_with_results(program):
    old = (v88["BASE"] / RESULTS).read_text(encoding="utf-8").rstrip()
    new = (VERSION / RESULTS).read_text(encoding="utf-8").rstrip()
    assert program.count(old) == 1
    return v88["inline"](program.replace(old, new, 1))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    builder.inline_program = inline_with_results
    gfx_tail = v87["GFX_TAIL"]
    v83["build"].__globals__.update(
        NAME=NAME, install_poachers=v84["install_poachers"], source_code=v87["source_code"],
        compile_code=v88["compile_code"], GFX_TAIL=gfx_tail,
        ROM_LITERAL_SIZE=v83["MAP_END"] - gfx_tail, load_literals=v85["load_literals"],
    )
    with TemporaryDirectory(prefix="seal-drift-v89-") as directory:
        v83["build"](args.label, Path(directory), args.output)
