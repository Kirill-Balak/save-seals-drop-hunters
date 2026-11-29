"""Build Seal Drift v97 with room for the saw and one magnet control."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
BASE = VERSION.parent / "rewards_v96"
NAME = "seal_drift_v97"
v96 = run_path(str(BASE / "tools/build.py"))
builder, v83, v87, v90, v94, v95 = (v96[name] for name in ("builder", "v83", "v87", "v90", "v94", "v95"))
inline_results = v96["inline_results"]


def inline_updated_layout(program):
    """Apply interface and reticle edits to their inherited source modules."""
    for path in sorted((VERSION / "src").glob("*.lua")):
        base = BASE if path.name == "06_ui.lua" else v94["VERSION"]
        old = (base / "src" / path.name).read_text(encoding="utf-8").rstrip()
        new = path.read_text(encoding="utf-8").rstrip()
        assert program.count(old) == 1, path
        program = program.replace(old, new, 1)
    return inline_results(program)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    v96["inline_updated_colors"].__globals__["inline_results"] = inline_updated_layout
    v95["inline_updated_prompts"].__globals__["inline_results"] = v96["inline_updated_colors"]
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
    with TemporaryDirectory(prefix="seal-drift-v97-") as directory:
        v83["build"](args.label, Path(directory), args.output)
