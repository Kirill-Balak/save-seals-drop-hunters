"""Install the supplied saw art in eight directions on the v111 cart."""

import argparse
from functools import partial
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory

from PIL import Image


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v112"
v111 = run_path(str(VERSION.parent / "rewards_v111/tools/build.py"))
v105, v101, v107, v108 = (v111[name] for name in ("v105", "v101", "v107", "v108"))
pipeline = v101["pipeline"]
set_pixel = v105["set_pixel"]
SAW_SLOTS = (0, 4, 2, 5)
INKS = v108["INKS"]


def saw_canvas(name, size, origin):
    with Image.open(VERSION / "assets" / name) as source:
        assert source.size == size, name
        sprite = source.convert("RGBA")
    assert set(sprite.get_flattened_data()) <= INKS.keys()
    frame = Image.new("RGBA", (16, 16))
    frame.paste(sprite, origin)
    return frame


def saw_frames():
    right = saw_canvas("saw-right.png", (16, 12), (0, 2))
    lower_right = saw_canvas("saw-down-right.png", (13, 14), (1, 1))
    canvases = (
        right,
        lower_right.transpose(Image.Transpose.ROTATE_90),
        right.transpose(Image.Transpose.ROTATE_90),
        lower_right.transpose(Image.Transpose.ROTATE_180),
    )
    frames = []
    for slot, canvas in zip(SAW_SLOTS, canvases):
        x, y, max_width, max_height, *_ = pipeline["SAW"][slot]
        bounds = canvas.getbbox()
        sprite = canvas.crop(bounds)
        assert sprite.width <= max_width and sprite.height <= max_height
        frames.append(((x, y, sprite.width, sprite.height, *bounds[:2]), sprite))
    return frames


def overlay(program):
    program = v111["overlay"](program)
    start = program.index("function action_saw(")
    left = program.index("function draw_saw(", start)
    end = program.index("\nend", left) + len("\nend")
    saw = (VERSION / "src/saw.lua").read_text(encoding="utf-8").rstrip()
    program = program[:start] + saw + program[end:]
    for old, new in (
        ("draw_saw(57,40,0,1,7)", "draw_saw(57,40,0,7)"),
        ("draw_saw(33,5,0,1,", "draw_saw(33,5,0,"),
        ("draw_saw(x,y,0,1,9)", "draw_saw(x,y,0,9)"),
    ):
        assert program.count(old) == 1, old
        program = program.replace(old, new, 1)
    return program


def source_code(base, frames, stars):
    code = base(stars)
    atlas = pipeline["atlas_table"]
    old = atlas("saw_atlas", pipeline["SAW"])
    assert code.count(old) == 1
    return code.replace(old, atlas("saw_atlas", [rect for rect, _ in frames]), 1)


def compile_code(frames, cart, stars, scratch):
    v111["compile_code"](cart, stars, scratch)
    for x, y, w, h, *_ in pipeline["SAW"]:
        for dy in range(h):
            for dx in range(w):
                set_pixel(cart.rom, x + dx, y + dy, 0)
    for (x, y, w, _, *_), sprite in frames:
        for i, pixel in enumerate(sprite.get_flattened_data()):
            set_pixel(cart.rom, x + i % w, y + i // w, INKS[pixel])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    frames = saw_frames()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v107["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(source_code, scope["source_code"], frames),
        compile_code=partial(compile_code, frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v112-") as directory:
        build(None, Path(directory), args.output)
