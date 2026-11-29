"""Build the ten-level Seal Drift campaign on the v100 toolchain."""

import argparse
import json
from pathlib import Path
import re
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v101"
v100 = run_path(str(ROOT / "rewards_v100/tools/build.py"))
v96, v95, v90, v94, v83, v87 = (v100[f"v{n}"] for n in (96, 95, 90, 94, 83, 87))
builder = v100["builder"]
pipeline = v94["pipeline"]
original_inline = v90["v88"]["inline"]
BASES = {
    "01_splashscreen.lua": 94,
    "03_endgame.lua": 74,
    "06_ui.lua": 100,
    "07_tutorial.lua": 100,
    "08_rewards.lua": 90,
    "11_rescue.lua": 100,
}


def flatten(rows):
    return [value for row in rows for value in row]


def numeric_lines(values):
    lines, line = [], ""
    for value in values:
        field = str(value)
        if isinstance(value, float) and abs(value) < 1:
            field = field.replace("0.", ".")
        if line and len(line) + len(field) > 25:
            lines.append(line)
            line = ""
        line += field + ","
    return "\n".join(lines + [line[:-1]])


def literal(values, delim=None):
    """Encode editable records as a single PICO-8 string literal."""
    body = (f"{delim}\n").join(map(numeric_lines, values)) if delim else numeric_lines(values)
    return "[[\n" + body + "]]"


def campaign_source(previous):
    rows = json.loads((VERSION / "assets/levels.json").read_text(encoding="utf-8"))
    assert len(rows) == 10
    levels, rims = [], []
    for row in rows:
        bands = row.get("bands", [[56, 0, 47]])
        rim = row["rim"]
        assert sum(band[0] for band in bands) == 56
        assert all(count > 0 and (0 <= left <= right <= 48 or (left, right) == (1, 0))
                   for count, left, right in bands)
        assert all(4 <= x <= 99 and 12 <= y <= 123 for x, y in rim)
        assert 0 < row["stars"][0] < row["stars"][1] < 32767
        assert all(0 < row[key] < 32767 for key in ("hunt", "windup"))
        assert row["cuts"] > 0 and 1 <= row["art"] <= 5
        actors = row["seals"] + row["poachers"]
        assert 0 < len(row["seals"]) < len(actors) and all(len(actor) == 4 for actor in actors)
        levels.append([row["cuts"], len(row["seals"]), *row["stars"], len(bands),
                       *flatten(bands), *flatten(actors)])
        rims.append(flatten(rim))
    lesson = previous.split("levels=split([[", 1)[1].split("]]", 1)[0].split("|")[-1]
    lines = (
        f'levels=split({literal(levels, "|")},"|")',
        "level_count=#levels",
        f'floes=split({literal(rims, "|")},"|")',
        f'level_art=split{literal([row["art"] for row in rows])}',
        f'hunt_timing=split{literal(flatten((row["hunt"], row["windup"]) for row in rows))}',
        f'lesson_level=[[{lesson}]]',
    )
    return "\n".join(lines)


def overlay(program):
    for name, version in BASES.items():
        old = (ROOT / f"rewards_v{version}/src" / name).read_text(encoding="utf-8").rstrip()
        new = (VERSION / "src" / name).read_text(encoding="utf-8").rstrip()
        if name == "01_splashscreen.lua":
            new = new.replace("--campaign data", campaign_source(old), 1)
            marker = "function save_progress("
            art = builder.ice_art_lua()
            old = old.replace(marker, art + marker, 1)
            marker = "function load_progress("
            new = new.replace(marker, art + marker, 1)
        assert program.count(old) == 1, name
        program = program.replace(old, new, 1)
    return original_inline(program)


def unused_spans(rom, stars):
    """Find long zero runs outside every sprite rectangle and grip row."""
    occupied = set()

    def reserve(x, y, width, height):
        occupied.update(row * 64 + col for row in range(y, y + height)
                        for col in range(x // 2, (x + width + 1) // 2))

    for x, y, width, height, *_ in (*pipeline["SAW"], *stars):
        reserve(x, y, width, height)
    for tile in (*range(3, 37), *range(128, 168)):
        reserve(tile % 16 * 8, tile // 16 * 8, 8, 8)
    reserve(8, 0, 16, 8)
    reserve(64, 80, 40, 2)
    flags = bytes(a not in occupied and value == 0
                  for a, value in enumerate(rom[:v87["GFX_TAIL"]]))
    return [(match.start(), len(match[0])) for match in re.finditer(b"\x01{8,}", flags)]


def compile_code(cart, stars, scratch):
    v90["compile_code"](cart, stars, scratch)
    payload = (scratch / "literals.bin").read_bytes()
    gfx_tail = v87["GFX_TAIL"]
    map_start, map_end = v83["MAP_START"], v83["MAP_END"]
    extra = payload[map_end - gfx_tail:]
    ranges = [(map_start, map_end - map_start), (gfx_tail, map_start - gfx_tail)]
    stored = 0
    for start, length in unused_spans(cart.rom, stars):
        part = extra[stored:stored + length]
        if not part:
            break
        cart.rom[start:start + len(part)] = part
        ranges.append((start, len(part)))
        stored += len(part)
    print(f"Additional literals in spare sprite bytes: {stored}", flush=True)
    reader = f"""local rom_data=''
local spans=split{literal(flatten(ranges))}
for i=1,#spans,2 do
 local n=spans[i+1]
 for x=0,n-1,256 do
  rom_data..=chr(peek(
   spans[i]+x,min(n-x,256)))
 end
end
"""
    left = cart.code.index("local rom_data=")
    right = cart.code.index("local more=", left)
    tail = cart.code.index("\n]]", right) + 3
    rest = v83["folded_literal"](extra[stored:])
    cart.code = cart.code[:left] + reader + "local more=" + rest + cart.code[tail:]


def configure():
    v96["inline_updated_colors"].__globals__["inline_results"] = v100["inline_updated_layout"]
    v95["inline_updated_prompts"].__globals__["inline_results"] = v96["inline_updated_colors"]
    v90["inline_with_results"] = v95["inline_updated_prompts"]
    v90["v88"]["inline"] = overlay
    builder.inline_program = v94["inline_with_lessons"]
    pipeline["BLOCKS"] = tuple(
        ("function lesson_setup(" if first == "function tutorial_draw(" else first, last)
        for first, last in pipeline["BLOCKS"]
    )
    # Leave progress loading in the cold campaign block instead of inlining it into _init.
    order = original_inline.__globals__["ORDER"]
    original_inline.__globals__["ORDER"] = [name for name in order if name != "load_progress"]
    pipeline["BLOCKS"] = tuple(
        ("function load_progress(" if first == "function save_progress(" else first, last)
        for first, last in pipeline["BLOCKS"]
    )
    tabs = v87["v84"]["compile_code"].__globals__
    tabs["TAB_STARTS"] = tuple(
        ("function tutorial_update(" if title == "tutorial" else first, title)
        for first, title in tabs["TAB_STARTS"]
    )
    gfx_tail = v87["GFX_TAIL"]
    v83["build"].__globals__.update(
        NAME=NAME, install_poachers=v90["v84"]["install_poachers"],
        source_code=v87["source_code"], compile_code=compile_code,
        GFX_TAIL=gfx_tail, ROM_LITERAL_SIZE=v83["MAP_END"] - gfx_tail,
        load_literals=v90["v85"]["load_literals"],
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    configure()
    with TemporaryDirectory(prefix="seal-drift-v101-") as directory:
        v83["build"](args.label, Path(directory), args.output)
