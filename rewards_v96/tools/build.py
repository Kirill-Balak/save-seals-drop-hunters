"""Build Seal Drift v96 with the red saw and X restricted to lesson one."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
BASE = VERSION.parent / "rewards_v95"
NAME = "seal_drift_v96"
v95 = run_path(str(BASE / "tools/build.py"))
builder, v83, v87, v90, v94 = (v95[name] for name in ("builder", "v83", "v87", "v90", "v94"))
inline_results = v95["inline_results"]


def inline_updated_colors(program):
    """Replace only the two v95 modules that draw tutorial controls."""
    for path in sorted((VERSION / "src").glob("*.lua")):
        old = (BASE / "src" / path.name).read_text(encoding="utf-8").rstrip()
        new = path.read_text(encoding="utf-8").rstrip()
        assert program.count(old) == 1, path
        program = program.replace(old, new, 1)
    return inline_results(program)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    v95["inline_updated_prompts"].__globals__["inline_results"] = inline_updated_colors
    v90["inline_with_results"] = v95["inline_updated_prompts"]
    builder.inline_program = v94["inline_with_lessons"]
    pipeline = v94["pipeline"]
    pipeline["BLOCKS"] = tuple(
        ("function tutorial_hint(" if first == "function tutorial_draw(" else first, last)
        for first, last in pipeline["BLOCKS"]
    )
    gfx_tail = v87["GFX_TAIL"]
    v83["build"].__globals__.update(
        NAME=NAME, install_poachers=v90["v84"]["install_poachers"],
        source_code=v87["source_code"], compile_code=v90["compile_code"],
        GFX_TAIL=gfx_tail, ROM_LITERAL_SIZE=v83["MAP_END"] - gfx_tail,
        load_literals=v90["v85"]["load_literals"],
    )
    with TemporaryDirectory(prefix="seal-drift-v96-") as directory:
        v83["build"](args.label, Path(directory), args.output)
