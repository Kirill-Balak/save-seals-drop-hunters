"""Build the v82 cart with a clean sprite sheet and map editor."""

import argparse
import os
from pathlib import Path
import re
from runpy import run_path
from tempfile import TemporaryDirectory

from sprites import SAW, install_art


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
BUILD_SOURCE = ROOT / "rewards_v79/tools/build.py"
TOOLCHAIN = ROOT / "rewards_v66/checks/toolchain"
SFX_FIRST = 10
SFX_END = 64
SFX_BASE = 0x3200
SFX_STRIDE = 68
SFX_NOTES = 64
PAYLOAD_START = 0x2000
PAYLOAD_SIZE = (SFX_END - SFX_FIRST) * SFX_NOTES
BLOCKS = (
    ("function save_progress(", "-->8\n--gameplay"),
    ("gamestate.endgame=", "-->8\n--objects"),
    ("function tutorial_draw(", "-->8\n--rewards"),
    ("function release_line(", None),
)

PAYLOAD_LOADER = f"""
local sfx_data=""
for i={SFX_FIRST},{SFX_END - 1} do
 sfx_data..=chr(peek({SFX_BASE}+i*{SFX_STRIDE},{SFX_NOTES}))
end
"""


def atlas_table(name, rectangles):
    rows = ",\n".join(",".join(map(str, row)) for row in rectangles)
    return f"{name}=split[[\n{rows}]]\n"


def source_code(builder, stars, blocks):
    modules = {}
    for directory in (builder.BASE_VERSION / "src", builder.PREVIOUS / "src",
                      ROOT / "rewards_v80/src", VERSION / "src"):
        modules.update({path.name: path for path in directory.glob("*.lua")})
    code = "\n".join(modules[name].read_text(encoding="utf-8").rstrip() for name in sorted(modules))
    code = code.replace("function save_progress(", builder.ice_art_lua() + "function save_progress(", 1)
    code = builder.inline_program(builder.HEADER + code + "\n")
    spans = [(code.index(start), code.index(end) if end else len(code)) for start, end in blocks]
    options = f"rom_ranges={PAYLOAD_START}:{PAYLOAD_START + PAYLOAD_SIZE}"
    for left, right in sorted(spans, reverse=True):
        code = code[:left] + f"--$switch-compiler: parens8 {options}\n" + code[left:right] + "\n--$switch-compiler: none\n" + code[right:]
    data = atlas_table("saw_atlas", SAW) + atlas_table("star_atlas", stars)
    return code.replace("--core\n", "--core\n" + data, 1)


def install_payload(cart, package, code):
    """Move VM bytes from the build's scratch map into unused SFX notes."""
    data = package.rom[PAYLOAD_START:PAYLOAD_START + PAYLOAD_SIZE]
    for i in range(SFX_END - SFX_FIRST):
        offset = SFX_BASE + (SFX_FIRST + i) * SFX_STRIDE
        cart.rom[offset:offset + SFX_NOTES] = data[i * SFX_NOTES:(i + 1) * SFX_NOTES]

    def read_slice(match):
        at, length = [int(group, 0) for group in match.groups()]
        if not PAYLOAD_START <= at < PAYLOAD_START + PAYLOAD_SIZE:
            return match[0]
        assert at + length <= PAYLOAD_START + PAYLOAD_SIZE
        start = at - PAYLOAD_START + 1
        return f"sub(sfx_data,{start},{start + length - 1})"

    patched = re.sub(r"chr\(peek\((0x[0-9a-f]+|[0-9]+),\s*(0x[0-9a-f]+|[0-9]+)\)\)", read_slice, code)
    assert patched != code
    return PAYLOAD_LOADER + patched


def build(label, scratch):
    source = run_path(str(BUILD_SOURCE))
    builder = source["previous"]
    cart, stars = install_art(builder, source["install_seal_frames"],
                              ROOT / "rewards_v81/assets/seal-cycle.pixel.json")
    original, package = (scratch / name for name in ("source.p8", "packed.p8"))
    original.write_text(source_code(builder, stars, BLOCKS), encoding="utf-8")
    env = dict(os.environ, PYTHONPATH=os.environ.get("SEAL_DRIFT_TOOLCHAIN", str(TOOLCHAIN)))
    builder.run("-m", "shrinko.shrinko8", original, package, "--minify",
                "--focus-compressed", "--rename-safe-only", "--no-minify-reorder", "--count", env=env)
    packed = builder.read_cart(str(package))
    code = install_payload(cart, packed, packed.code)
    cart.code = "--seal drift\n--kirill balak\n-- Parens-8 VM: AGPLv3\n-- SFX 10-63: VM data\n" + code
    cart.label = builder.read_cart(str(label or builder.COVER),
                                   builder.CartFormat.label if label else None).label
    verify_and_write(builder, cart)


def verify_and_write(builder, cart):
    name = "seal_drift_v82"
    tokens, errors = builder.tokenize(builder.Source(name, cart.code))
    assert not errors, errors
    rom = builder.write_cart_to_rom(cart)
    metrics = {
        "tokens": builder.count_tokens(tokens),
        "compressed_bytes": builder.get_compressed_size(
            builder.BinaryReader(builder.BytesIO(rom[len(cart.rom):]), big_end=True)),
        "longest_line": max(map(len, cart.code.split("\n"))),
    }
    print(metrics, flush=True)
    assert metrics["tokens"] <= 8192 and metrics["compressed_bytes"] < 15360
    assert not any(cart.rom[0x1000:0x3100])
    path = VERSION / f"{name}.p8"
    builder.write_cart(str(path), cart, builder.CartFormat.p8)
    check = builder.read_cart(str(path))
    assert check.code == cart.code and check.rom == cart.rom


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    with TemporaryDirectory(prefix="seal-drift-v82-") as folder:
        build(parser.parse_args().label, Path(folder))
