"""Import the two-channel Broken Arm track and pack the sprite atlas."""

import argparse
from pathlib import Path
import re
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v111"
v110 = run_path(str(VERSION.parent / "rewards_v110/tools/build.py"))
v105, v101, v107, v108 = (v110[name] for name in ("v105", "v101", "v107", "v108"))
builder = v101["builder"]
MUSIC_START = 0x3100
SFX_START = 0x3200
SFX_STRIDE = 68
NOTE_BYTES = 64
SCRATCH_RAM = 0x4300
MUSIC_LANES = (1, 3)
ATLAS = (
    # ROM address, width in bytes, height in pixels.
    (16, 48, 8), (512, 64, 8), (1024, 16, 8),
    (4096, 64, 16), (5120, 32, 8),
)


def overlay(program):
    program = v110["overlay"](program)
    init = "function _init()"
    assert program.count(init) == 1
    mask = sum(1 << lane for lane in MUSIC_LANES)
    program = program.replace(init, init + f"\n music(0,0,{mask})", 1)
    for effect in ("5", "6", "7", "won and 8 or 9"):
        old = f"sfx({effect},3)"
        assert program.count(old) == 1, old
        program = program.replace(old, f"sfx({effect})", 1)
    return program


def sound(cart, slot):
    offset = SFX_START + slot * SFX_STRIDE
    return bytes(cart.rom[offset:offset + SFX_STRIDE])


def import_music():
    source = builder.read_cart(str(VERSION / "assets/Broken_Arm_corrected_2ch.p8"))
    blank = bytes((65, 66, 67, 68))
    patterns = [bytes(source.rom[i:i + 4]) for i in range(MUSIC_START, SFX_START, 4)]
    while patterns and all(value & 0x40 for value in patterns[-1]):
        assert not any(value & 0x80 for value in patterns[-1])
        patterns.pop()
    parts = {}
    for a, b, c, d in patterns:
        assert not (a & 0x40 or b & 0x40) and (c, d) == (66, 67)
        for value in (a, b):
            data = sound(source, value & 63)
            assert all(not (byte & 0x80) for byte in data[1:NOTE_BYTES:2]), "custom instrument"
            parts.setdefault(data, len(parts))
    first = 64 - len(parts)
    result = []
    for pattern in patterns:
        channels = [value & 0x80 | quiet for value, quiet in zip(pattern, blank)]
        for original, lane in enumerate(MUSIC_LANES):
            slot = first + parts[sound(source, pattern[original] & 63)]
            channels[lane] = channels[lane] & 0x80 | slot
        result.append(bytes(channels))
    return first, b"".join(parts), b"".join(result)


def install_atlas(cart, scratch, displaced):
    spans = [(base + y * 64, width) for base, width, height in ATLAS for y in range(height)]
    atlas = b"".join(cart.rom[a:a + w] for a, w in spans)
    rows = [atlas[i:i + 4] for i in range(0, len(atlas), 4)]
    dictionary = {row: i for i, row in enumerate(dict.fromkeys(rows))}
    lookup = bytes(dictionary[row] for row in rows)
    encoded = displaced + b"".join(dictionary) + lookup

    left = cart.code.index("local rom_data=")
    inline = cart.code.index("local more=", left)
    tail = cart.code.index("\n]]", inline) + 3
    spans_literal = cart.code.split("local spans=split[[", 1)[1].split("]]", 1)[0]
    numbers = [int(n) for n in re.findall(r"\d+", spans_literal)]
    original_spans = list(zip(numbers[::2], numbers[1::2]))
    assert not any(a < b + v and b < a + w for a, w in spans for b, v in original_spans)
    raw_size = sum(size for _, size in original_spans)
    literals = (scratch / "literals.bin").read_bytes()[raw_size:]
    available = len(atlas) - len(encoded)
    assert 0 <= available <= len(literals)
    encoded += literals[:available]
    assert SCRATCH_RAM + len(encoded) <= 0x5600
    offset = 0
    for address, width in spans:
        cart.rom[address:address + width] = encoded[offset:offset + width]
        offset += width
    assert offset == len(encoded)

    decoder = (VERSION / "src/audio_storage.lua").read_text(encoding="utf-8")
    for token, value in {
        "@shapes": "split" + v101["literal"](v101["flatten"](ATLAS)),
        "@ram": str(SCRATCH_RAM),
        "@sfx": str(len(displaced)),
        "@dict": str(len(dictionary) * 4),
    }.items():
        decoder = decoder.replace(token, value)
    tail_code = v101["v83"]["folded_literal"](literals[available:])
    reader, marker = cart.code[left:inline].split("for i=1,#spans,2 do\n", 1)
    assert "rom_data..=chr(peek(" in marker
    reader += (
        "for i=1,#spans,2 do\n"
        " rom_data..=read_bytes(\n"
        "  spans[i],spans[i+1])\n"
        "end\n"
    )
    load_extra = "rom_data..=read_bytes(\n j,tail-j)\n"
    cart.code = (cart.code[:left] + decoder + reader
                 + load_extra + "local more=" + tail_code + cart.code[tail:])


def compile_code(cart, stars, scratch):
    v110["compile_code"](cart, stars, scratch)
    first, sounds, patterns = import_music()
    end = v110["SFX_FIRST_FREE"]
    assert 10 < first < end
    displaced = b"".join(sound(cart, slot)[:NOTE_BYTES] for slot in range(first, end))
    install_atlas(cart, scratch, displaced)

    old = f"for i = 10, {end - 1} do"
    assert cart.code.count(old) == 1
    cart.code = cart.code.replace(old, f"for i = 10, {first - 1} do", 1)
    flags = "sfx_data..=chr(peek(12288,\n 256))"
    assert cart.code.count(flags) == 1
    extra = "sfx_data..=read_bytes(\n ram,dict-ram)\n"
    cart.code = cart.code.replace(flags, extra + flags, 1)
    start = SFX_START + first * SFX_STRIDE
    assert len(sounds) == 64 * SFX_STRIDE + SFX_START - start
    cart.rom[start:start + len(sounds)] = sounds
    cart.rom[MUSIC_START:MUSIC_START + len(patterns)] = patterns


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v107["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    build.__globals__.update(NAME=NAME, compile_code=compile_code)
    with TemporaryDirectory(prefix="seal-drift-v111-") as directory:
        build(None, Path(directory), args.output)
