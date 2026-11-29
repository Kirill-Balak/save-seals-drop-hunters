"""Assemble Seal Drift v83 from the v82 pipeline and the poacher recipe."""

import argparse
import json
import os
from pathlib import Path
import re
from runpy import run_path
import sys
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
BASE = ROOT / "rewards_v82"
NAME = "seal_drift_v83"
sys.path.insert(0, str(BASE / "tools"))
pipeline = run_path(str(BASE / "tools/build.py"))
legacy = run_path(str(pipeline["BUILD_SOURCE"]))
builder = legacy["previous"]
from pico_defs import k_palette

HEADINGS = ("e", "ne", "n", "se", "s")
PHASES = ("stride-a", "pass-a", "stride-b", "pass-b", "idle", "raise", "aim", "recoil")
PALETTE = dict(zip(".kprhbtswg", "0128e5467f"))
MAP_START, MAP_END = 0x2000, 0x3000
GFX_TAIL = 125 * 64
ROM_LITERAL_SIZE = MAP_END - GFX_TAIL


def folded_literal(data):
    """Fit binary bytes in one Lua long string, avoiding control bytes and ]]."""
    escaped = (f"~{chr(byte + 32)}" if byte <= 32 or byte in (93, 126) else chr(byte)
               for byte in data)
    encoded = "".join(escaped)
    rows = "\n".join(encoded[i:i + 30] for i in range(0, len(encoded), 30))
    return f"[[\n{rows}\n]]"


def load_literals(code, payload):
    """Extend the map string with the binary tail that does not fit in ROM."""
    tail = folded_literal(payload[ROM_LITERAL_SIZE:])
    loader = f"""local rom_data=''
for a=0x2000,0x2fff,256 do
 rom_data..=chr(peek(a,256))
end
rom_data..=chr(peek(8000,192))
local more={tail}
local escape=false
for i=1,#more do
 local v=ord(more,i)
 if v!=10 then
  if escape then
   rom_data..=chr(v-32)
   escape=false
  elseif v==126 then
   escape=true
  else
   rom_data..=chr(v)
  end
 end
end
"""
    code, count = re.subn(r"local rom_data=chr\(peek\(8192,\s*4096\)\)\s*for y=0,-1 do.*?\bend\n",
                          lambda _: loader, code, count=1, flags=re.S)
    assert count == 1
    return code


def install_poachers(cart):
    recipe = json.loads((VERSION / "assets/poacher.pixel.json").read_text(encoding="utf-8"))
    assert (recipe["width"], recipe["height"]) == (16, 12)
    for key, index in PALETTE.items():
        if index != "0":
            color = k_palette[int(index, 16)]
            assert recipe["palette"][key].lower() == f"#{color.r:02x}{color.g:02x}{color.b:02x}"
    expected = [f"{head}-{phase}" for head in HEADINGS for phase in PHASES]
    assert [frame["name"] for frame in recipe["frames"]] == expected
    assert not any(cart.rom[0x1000:MAP_END])
    rows = [list("0" * 128) for _ in range(128)]

    for i, frame in enumerate(recipe["frames"]):
        grid, = frame["ops"]
        assert frame["anchor"] == [8, 7] and grid["op"] == "grid" and grid["x"] == grid["y"] == 0
        pixels = grid["rows"]
        assert len(pixels) == 12 and all(len(row) == 16 for row in pixels)
        (gx, gy), = [(x, y) for y, row in enumerate(pixels) for x, c in enumerate(row) if c == "g"]
        dx, dy = i % 8 * 16, 64 + i // 8 * 12
        for j, row in enumerate(pixels):
            rows[dy + j][dx:dx + 16] = [PALETTE[c] for c in row]
        rows[124][i], rows[124][i + 40] = format(gx, "x"), format(gy, "x")

    sprites = builder.read_cart_from_source(builder.HEADER + "__gfx__\n" + "\n".join(map("".join, rows)) + "\n")
    cart.rom[0x1000:MAP_START] = sprites.rom[0x1000:MAP_START]
    # These sixteen tiles belonged to the v82 poacher. Everything else is retained.
    for index in range(36, 52):
        for y in range(8):
            offset = (index // 16 * 8 + y) * 64 + index % 16 * 4
            cart.rom[offset:offset + 4] = bytes(4)


def source_code(stars):
    modules = {}
    for version in ("rewards_v74", "rewards_v77", "rewards_v80", "rewards_v82", VERSION.name):
        modules.update({path.name: path for path in (ROOT / version / "src").glob("*.lua")})
    code = "\n".join(modules[name].read_text(encoding="utf-8").rstrip() for name in sorted(modules))
    marker = "function save_progress("
    code = code.replace(marker, builder.ice_art_lua() + marker, 1)
    code = builder.inline_program(builder.HEADER + code + "\n")
    blocks = pipeline["BLOCKS"] + (("-->8\n--rewards", "function release_line("),)
    spans = [(code.index(start), code.index(end) if end else len(code)) for start, end in blocks]
    for left, right in sorted(spans, reverse=True):
        options = f"rom_ranges={MAP_START}:{MAP_START + pipeline['PAYLOAD_SIZE']} compress"
        code = code[:left] + f"--$switch-compiler: parens8 {options}\n" + code[left:right] + "\n--$switch-compiler: none\n" + code[right:]
    table = pipeline["atlas_table"]
    atlas = table("saw_atlas", pipeline["SAW"]) + table("star_atlas", stars)
    return code.replace("--core\n", "--core\n" + atlas, 1)


def compile_code(cart, stars, scratch):
    source, packed = (scratch / name for name in ("source.p8", "packed.p8"))
    source.write_text(source_code(stars), encoding="utf-8")
    env = dict(os.environ, PYTHONPATH=os.environ.get("SEAL_DRIFT_TOOLCHAIN", str(pipeline["TOOLCHAIN"])))
    builder.run("-m", "shrinko.shrinko8", source, packed, "--minify",
                "--focus-compressed", "--rename-safe-only", "--no-minify-reorder", "--count", env=env)
    package = builder.read_cart(str(packed))
    code = pipeline["install_payload"](cart, package, package.code)
    cart.code = "--seal drift\n--kirill balak\n--parens-8 vm: agplv3\n--core\n" + code
    staged, wrapped, literals = (scratch / name for name in ("staged.p8", "wrapped.p8", "literals.bin"))
    builder.write_cart(str(staged), cart, builder.CartFormat.p8)
    wrap = ROOT / "rewards_v76/tools/wrap.py"
    builder.run(wrap, staged, wrapped, literals, MAP_START, MAP_END, 0, 0, 0)
    payload = literals.read_bytes()
    print(f"Packed literals: {len(payload)} bytes", flush=True)
    map_bytes = payload[:MAP_END - MAP_START]
    assert len(map_bytes) == MAP_END - MAP_START
    cart.rom[MAP_START:MAP_END] = map_bytes
    assert not any(cart.rom[GFX_TAIL:MAP_START])
    cart.rom[GFX_TAIL:MAP_START] = payload[len(map_bytes):ROM_LITERAL_SIZE]
    cart.code = load_literals(builder.read_cart(str(wrapped)).code, payload)


def build(label, scratch, output):
    original, stars = pipeline["install_art"](
        builder, legacy["install_seal_frames"], ROOT / "rewards_v81/assets/seal-cycle.pixel.json"
    )
    cart = builder.read_cart(str(BASE / "base_assets.p8"))
    assert original.rom[:MAP_END] == cart.rom[:MAP_END]
    install_poachers(cart)
    compile_code(cart, stars, scratch)
    if label:
        cart.label = builder.read_cart(str(label), builder.CartFormat.label).label
    tokens, errors = builder.tokenize(builder.Source(NAME, cart.code))
    assert not errors, errors
    rom = builder.write_cart_to_rom(cart)
    metrics = {
        "tokens": builder.count_tokens(tokens),
        "compressed_bytes": builder.get_compressed_size(
            builder.BinaryReader(builder.BytesIO(rom[len(cart.rom):]), big_end=True)),
        "longest_line": max(map(len, cart.code.split("\n"))),
    }
    print(metrics, flush=True)
    assert metrics["tokens"] <= 8192 and metrics["compressed_bytes"] < 15360 and metrics["longest_line"] <= 30
    builder.write_cart(str(output), cart, builder.CartFormat.p8)
    check = builder.read_cart(str(output))
    assert (check.code, check.rom) == (cart.code, cart.rom)
    assert check.label.array == cart.label.array


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    with TemporaryDirectory(prefix="seal-drift-v83-") as directory:
        build(args.label, Path(directory), args.output)
