"""Build v85 with the v84 sprite sheet, tab layout and Seal Drift toolchain."""

import argparse
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v85"
v84 = run_path(str(ROOT / "rewards_v84/tools/build.py"))
v83 = v84["base"]
builder = v83["builder"]
pipeline = v83["pipeline"]
GFX_TAIL = 88 * 64


def source_code(stars):
    modules = {}
    for version in (74, 77, 80, 82, 83, 84, 85):
        modules.update({path.name: path for path in (ROOT / f"rewards_v{version}/src").glob("*.lua")})
    code = "\n".join(modules[name].read_text(encoding="utf-8").rstrip() for name in sorted(modules))
    marker = "function save_progress("
    code = code.replace(marker, builder.ice_art_lua() + marker, 1)
    code = builder.inline_program(builder.HEADER + code + "\n")
    blocks = pipeline["BLOCKS"] + (("-->8\n--rewards", "function release_line("),)
    spans = [(code.index(start), code.index(end) if end else len(code)) for start, end in blocks]
    start = pipeline["PAYLOAD_START"]
    options = f"rom_ranges={start}:{start + pipeline['PAYLOAD_SIZE']} compress"
    for left, right in sorted(spans, reverse=True):
        code = code[:left] + f"--$switch-compiler: parens8 {options}\n" + code[left:right] + "\n--$switch-compiler: none\n" + code[right:]
    table = pipeline["atlas_table"]
    atlas = table("saw_atlas", pipeline["SAW"]) + table("star_atlas", stars)
    return code.replace("--core\n", "--core\n" + atlas, 1)


def load_literals(code, payload):
    code = v83["load_literals"](code, payload)
    old = "rom_data..=chr(peek(8000,192))\n"
    new = "for a=0x1600,0x1fff,256 do\n rom_data..=chr(peek(a,256))\nend\n"
    assert code.count(old) == 1
    return code.replace(old, new, 1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    v83["build"].__globals__.update(
        NAME=NAME, install_poachers=v84["install_poachers"], source_code=source_code,
        compile_code=v84["compile_code"], GFX_TAIL=GFX_TAIL,
        ROM_LITERAL_SIZE=v83["MAP_END"] - GFX_TAIL, load_literals=load_literals,
    )
    with TemporaryDirectory(prefix="seal-drift-v85-") as directory:
        v83["build"](args.label, Path(directory), args.output)
