"""Add campaign result jingles and a two-stage tether alarm."""

import argparse
from functools import partial
import json
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "save_seals_drop_hunters_v125"
v124 = run_path(str(VERSION.parent / "rewards_v124/tools/build.py"))
v123, v119, v117, v114, v112, v111, v108, v105, v101 = (
    v124[name] for name in ("v123", "v119", "v117", "v114", "v112", "v111", "v108", "v105", "v101")
)
builder = v124["builder"]
effects = v114["v113"]["effect_row"]
SLOTS = (("victory", 8), ("defeat", 9), ("alarm", 54), ("urgent_alarm", 55))
LITERAL_SLOTS = range(56, 60)


def overlay(program):
    program = v123["overlay"](program)
    for old, new in (
        ('\n\tsfx(won and 8 or 9)', ''),
        ('local reveal=ending-result_delay',
         'local reveal=ending-result_delay\n'
         '\t\tif reveal==0 and not ready then\n'
         '\t\t\tmusic(-1)\n'
         '\t\t\tsfx(victory and 8 or 9,3)\n'
         '\t\tend'),
        ('function start_level(id)', 'function start_level(id)\n\tmusic(0,0,10)'),
        ('function release_line()', 'function release_line()\n\tif snared then sfx(-1,3) end'),
        ('function set_state(name)', 'function set_state(name)\n\tif name!="endgame" then sfx(-1,3) end'),
        ('if tether_left==44 then cue(1) end', 'if tether_left==44 then sfx(55,3) end'),
        ('\t\t\t\tsfx(4,2)', '\t\t\t\tsfx(4,2)\n\t\t\t\tsfx(54,3)'),
    ):
        assert program.count(old) == 1, old
        program = program.replace(old, new, 1)
    return program


def pack_extra_literals(cart):
    """Use spare SFX note bytes for the beginning of the Lua literal tail."""
    marker = "local more=[[\n"
    begin = cart.code.index(marker)
    end = cart.code.index("\n]]", begin) + 3
    encoded = cart.code[begin + len(marker):end - 3].replace("\n", "")
    raw = bytearray()
    escaped = False
    for character in encoded:
        if escaped:
            raw.append(ord(character) - 32)
            escaped = False
        elif character == "~":
            escaped = True
        else:
            raw.append(ord(character))
    assert not escaped and len(raw) > 64 * len(LITERAL_SLOTS)
    for index, slot in enumerate(LITERAL_SLOTS):
        start = v124["SFX_START"] + slot * v124["STRIDE"]
        assert not any(cart.rom[start:start + v124["STRIDE"]]), slot
        cart.rom[start:start + 64] = raw[64 * index:64 * (index + 1)]
    first = v124["SFX_START"] + LITERAL_SLOTS.start * v124["STRIDE"]
    last = v124["SFX_START"] + LITERAL_SLOTS[-1] * v124["STRIDE"]
    loader = (
        f"for i={first},{last},{v124['STRIDE']} do\n"
        " rom_data..=read_bytes(i,64)\n"
        "end\n"
    )
    tail = v101["v83"]["folded_literal"](raw[64 * len(LITERAL_SLOTS):])
    cart.code = cart.code[:begin] + loader + "local more=" + tail + cart.code[end:]
    old_reader = "sfx_data ..= chr(peek(12800\n\t+ i * 68, 64))"
    assert cart.code.count(old_reader) == 1
    cart.code = cart.code.replace(old_reader, "sfx_data..=read_bytes(\n  12800+i*68,64)", 1)


def quiet_music(cart):
    """Halve nonzero note volumes in the packed Broken Arm parts."""
    music, sfx, stride = (v124[key] for key in ("MUSIC_START", "SFX_START", "STRIDE"))
    first, size = (v124[key] for key in ("PACKED_FIRST", "RECORD_SIZE"))
    runtime_slots = {value & 63 for value in cart.rom[music + 1:sfx:4] if not value & 64}
    for slot in runtime_slots:
        index = slot - v124["RUNTIME_FIRST"]
        address = sfx + (first + index // 4) * stride + (index % 4) * size
        assert 0 <= index and first + index // 4 < 54
        for offset in range(1, size - 4, 2):
            byte = cart.rom[address + offset]
            volume = (byte >> 1) & 7
            if volume:
                cart.rom[address + offset] = (byte & ~14) | (max(1, volume // 2) << 1)


def compile_code(frames, cart, stars, scratch):
    v124["compile_code"](frames, cart, stars, scratch)
    quiet_music(cart)
    track = json.loads((VERSION / "assets/screen_and_rescue_sfx.json").read_text(encoding="utf-8"))
    rows = ["00010000" + "00000" * 32] * 64
    for name, slot in SLOTS:
        rows[slot] = effects(track[name])
    sounds = builder.read_cart_from_source(builder.HEADER + "__sfx__\n" + "\n".join(rows) + "\n")
    for _, slot in SLOTS:
        start = v124["SFX_START"] + slot * v124["STRIDE"]
        end = start + v124["STRIDE"]
        if slot >= 54:
            assert not any(cart.rom[start:end]), slot
        cart.rom[start:end] = sounds.rom[start:end]
    pack_extra_literals(cart)
    assert cart.code.startswith("--Save Seals, Drop Hunters!\n")
    cart.code = cart.code.replace("--Save Seals, Drop Hunters!\n", "--save seals, drop hunters!\n", 1)
    cover = VERSION.parent / "rewards_v124/assets/cover3.png"
    cart.label = builder.read_cart(str(cover), builder.CartFormat.label).label


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
        import_music=v114["music_with_cues"], install_atlas=v119["install_atlas"],
    )
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(v112["source_code"], scope["source_code"], frames),
        compile_code=partial(compile_code, frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v125-") as directory:
        build(None, Path(directory), args.output)
