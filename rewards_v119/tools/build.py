"""Align score rows, label the keyboard input, and buffer magnet requests."""

import argparse
from functools import partial
from pathlib import Path
import re
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v119"
v118 = run_path(str(VERSION.parent / "rewards_v118/tools/build.py"))
v117, v115, v114, v112, v111, v108, v105, v101 = (
    v118[name] for name in ("v117", "v115", "v114", "v112", "v111", "v108", "v105", "v101")
)
# The two retired saw frames from the old two-phase atlas.
# The second rectangle starts on a whole byte inside the old tile.
EXTRA_ROM = ((2056, 8, 11), (3078, 5, 16))


def overlay(program):
    program = v118["overlay"](program)
    begin = program.index("\n\tlocal down=btn(4)", program.index("function magnet_input()"))
    end = program.index("\n\t\tplacing,hold_o=true,-1", begin)
    request = (VERSION / "src/magnet_request.lua").read_text(encoding="utf-8").rstrip()
    program = program[:begin] + "\n" + request + program[end:]

    changes = (
        ("o_down=btn(4)", "o_down,o_pending=btn(4),nil", 2),
        ("line(10,63,117,63,1)", "line(10,65,117,65,1)", 1),
        ("local y_28_21=60+j_28_20*14", "local y_28_21=59+j_28_20*14", 1),
        ("print(key_glyph(key_17_5),102,y_17_4,col_17_7)",
         'print(key_glyph(key_17_5),102,y_17_4,col_17_7)\n'
         '\t\t\tif key_17_5==4 then print("(z)",109,y_17_4,col_17_7) end', 1),
        ("magnet_icon(120,y_17_8,", "magnet_icon(124,y_17_8,", 1),
        ("line(120-5,y_17_8+6,120-5+hold_o/2", "line(124-5,y_17_8+6,124-5+hold_o/2", 1),
        ("\t\t\tlocal col_18_8=p_18_0.k==2 and 8 or 9\n", "", 1),
        ("x_18_6,y_18_7,col_18_8)", "x_18_6,y_18_7,9)", 1),
    )
    for old, new, count in changes:
        assert program.count(old) == count, old
        program = program.replace(old, new)

    # This once-per-award routine can share the packed rescue module.
    start = program.index("function score_flight(")
    end = program.index("\nend\n", start) + len("\nend")
    body = program[start:end]
    program = program[:start] + program[end:]
    target = "function rescue_start()"
    assert program.count(target) == 1
    return program.replace(target, body + "\n\n" + target, 1)


def install_atlas(cart, scratch, displaced):
    spans = cart.code.split("local spans=split[[", 1)[1].split("]]", 1)[0]
    raw_size = sum(int(n) for n in re.findall(r"\d+", spans)[1::2])
    v114["install_atlas"](cart, scratch, displaced)

    shapes = v111["ATLAS"]
    atlas_size = sum(w * h for _, w, h in shapes)
    packed_dict = int(re.search(r"local j=dict\+(\d+)\n", cart.code)[1])
    used = raw_size + atlas_size - len(displaced) - packed_dict - atlas_size // 4
    capacity = sum(w * h for _, w, h in EXTRA_ROM)
    literals = (scratch / "literals.bin").read_bytes()
    assert used + capacity <= len(literals)
    assert v111["SCRATCH_RAM"] + atlas_size + capacity + (packed_dict - 16) * 2 <= 0x5600
    (scratch / "extra_rom.bin").write_bytes(literals[used:used + capacity])

    begin = cart.code.index("local shapes=split")
    end = cart.code.index("\nlocal ram=", begin)
    descriptors = v101["literal"](v101["flatten"](shapes + EXTRA_ROM))
    cart.code = cart.code[:begin] + "local shapes=split" + descriptors + cart.code[end:]
    loop = "for i=1,#shapes,3 do"
    assert cart.code.count(loop) == 2
    start = cart.code.rindex(loop)
    cart.code = cart.code[:start] + cart.code[start:].replace(loop, f"for i=1,{len(shapes)*3},3 do", 1)
    start = cart.code.index("local more=")
    end = cart.code.index("\n]]", start) + 3
    tail = v101["v83"]["folded_literal"](literals[used + capacity:])
    cart.code = cart.code[:start] + "local more=" + tail + cart.code[end:]


def compile_code(frames, cart, stars, scratch):
    v115["compile_code"](frames, cart, stars, scratch)
    extra = memoryview((scratch / "extra_rom.bin").read_bytes())
    offset = 0
    for base, width, height in EXTRA_ROM:
        for y in range(height):
            address = base + y * 64
            assert not any(cart.rom[address:address + width])
            cart.rom[address:address + width] = extra[offset:offset + width]
            offset += width
    assert offset == len(extra)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    frames = v112["saw_frames"]()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v117["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    v111["compile_code"].__globals__.update(
        import_music=v114["music_with_cues"], install_atlas=install_atlas,
    )
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(v112["source_code"], scope["source_code"], frames),
        compile_code=partial(compile_code, frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v119-") as directory:
        build(None, Path(directory), args.output)
