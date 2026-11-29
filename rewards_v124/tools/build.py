"""Replace the v123 music with the supplied single-channel Broken Arm loop."""

import argparse
from functools import partial
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "save_seals_drop_hunters_v124"
TRACK = VERSION / "assets/Broken_Arm_fixed_loop_from_1_24_375s.p8"
v123 = run_path(str(VERSION.parent / "rewards_v123/tools/build.py"))
v120, v119, v117, v114, v112, v111, v108, v105, v101 = (
    v123[name] for name in ("v120", "v119", "v117", "v114", "v112", "v111", "v108", "v105", "v101")
)
builder = v101["builder"]
MUSIC_START, SFX_START, STRIDE = (v111[name] for name in ("MUSIC_START", "SFX_START", "SFX_STRIDE"))
PACKED_FIRST = 49
RUNTIME_FIRST = 10
RECORD_SIZE = 16


def install_track(cart):
    source = builder.read_cart(str(TRACK))
    parts = {}
    patterns = bytearray()
    for address in range(MUSIC_START, SFX_START, 4):
        a, b, c, d = source.rom[address:address + 4]
        if a & 0x40:
            assert not ((a | b | c | d) & 0x80)
            continue
        assert address == MUSIC_START + len(patterns)
        assert all(channel & 0x40 for channel in (b, c, d))
        sound = v111["sound"](source, a & 63)
        assert not any(sound[12:64]) and not any(note & 0x80 for note in sound[1:12:2])
        slot = RUNTIME_FIRST + parts.setdefault(sound, len(parts))
        patterns.extend((65 | (a & 0x80), slot | (b & 0x80), 67 | (c & 0x80), 68 | (d & 0x80)))

    assert patterns and RUNTIME_FIRST + len(parts) <= 46
    assert PACKED_FIRST + (len(parts) + 3) // 4 <= 64
    start = SFX_START + PACKED_FIRST * STRIDE
    cart.rom[start:SFX_START + 64 * STRIDE] = bytes((64 - PACKED_FIRST) * STRIDE)
    for sound, index in parts.items():
        offset = start + index // 4 * STRIDE + index % 4 * RECORD_SIZE
        cart.rom[offset:offset + RECORD_SIZE] = sound[:12] + sound[64:]
    cart.rom[MUSIC_START:SFX_START] = patterns + bytes((65, 66, 67, 68)) * (64 - len(patterns) // 4)

    # Read the Parens-8 payload before reusing its SFX slots in RAM.
    marker = "sfx_data..=chr(peek(12288,\n 256))\n"
    assert cart.code.count(marker) == 1
    unpack = (VERSION / "src/music_unpack.lua").read_text(encoding="utf-8")
    cart.code = cart.code.replace(marker, marker + unpack.replace("@last", str(len(parts) - 1)), 1)


def compile_code(frames, cart, stars, scratch):
    v120["compile_code"](frames, cart, stars, scratch)
    install_track(cart)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    frames = v112["saw_frames"]()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v117["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = v123["overlay"]
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    v111["compile_code"].__globals__.update(
        import_music=v114["music_with_cues"], install_atlas=v119["install_atlas"],
    )
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(v112["source_code"], scope["source_code"], frames),
        compile_code=partial(compile_code, frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v124-") as directory:
        build(None, Path(directory), args.output)
