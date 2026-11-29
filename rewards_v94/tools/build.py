"""Build the Seal Drift tutorial update on the v90 campaign."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v94"
v90 = run_path(str(ROOT / "rewards_v90/tools/build.py"))
builder = v90["builder"]
v83, v87 = v90["v83"], v90["v87"]
pipeline = v87["pipeline"]


def inline_with_lessons(program):
    for path in sorted((VERSION / "src").glob("*.lua")):
        base = next(ROOT / f"rewards_v{version}/src" / path.name
                    for version in (87, 86, 85, 84, 83, 82, 80, 77, 74)
                    if (ROOT / f"rewards_v{version}/src" / path.name).is_file())
        old = base.read_text(encoding="utf-8").rstrip()
        # The base assembler inserts ice art partway through the splash module.
        new = path.read_text(encoding="utf-8").rstrip()
        if path.name == "01_splashscreen.lua":
            marker = "function save_progress("
            art = builder.ice_art_lua()
            old = old.replace(marker, art + marker, 1)
            new = new.replace(marker, art + marker, 1)
        assert program.count(old) == 1, path
        program = program.replace(old, new, 1)
    return v90["inline_with_results"](program)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    builder.inline_program = inline_with_lessons
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
    with TemporaryDirectory(prefix="seal-drift-v94-") as directory:
        v83["build"](args.label, Path(directory), args.output)
