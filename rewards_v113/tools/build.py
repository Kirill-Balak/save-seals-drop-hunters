"""Replace the saw and ice effects and let the result cue play after the transition."""

import argparse
from functools import partial
import json
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v113"
v112 = run_path(str(VERSION.parent / "rewards_v112/tools/build.py"))
v105, v101, v107, v108 = (v112[name] for name in ("v105", "v101", "v107", "v108"))
builder = v101["builder"]
pipeline = v101["pipeline"]


def overlay(program):
    program = v112["overlay"](program)
    start = program.index("function finish(")
    stop = program.index("\nend", start)
    finish = program[start:stop]
    cue = '\n\tsfx(won and 8 or 9)'
    transition = '\n\tset_state("endgame")'
    assert finish.count(cue) == finish.count(transition) == 1
    finish = finish.replace(cue, "").replace(transition, transition + cue)
    return program[:start] + finish + program[stop:]


def effect_row(effect):
    speed = effect["speed"]
    first, last = effect["loop"]
    notes = effect["notes"]
    assert 0 < speed <= 255 and 0 <= first <= last <= len(notes) <= 32
    assert all(0 <= pitch < 64 and 0 <= wave < 8 and 0 <= vol < 8
               for pitch, wave, vol in notes)
    header = f"00{speed:02x}{first:02x}{last:02x}"
    body = "".join(f"{pitch:02x}{wave:x}{volume:x}0" for pitch, wave, volume in notes)
    return header + body + "00000" * (32 - len(notes))


def compile_code(frames, cart, stars, scratch):
    v112["compile_code"](frames, cart, stars, scratch)
    effects = json.loads((VERSION / "assets/effects.json").read_text(encoding="utf-8"))
    rows = [effect_row(effects[name]) for name in ("chainsaw", "ice_crack")]
    audio = builder.read_cart_from_source(builder.HEADER + "__sfx__\n" + "\n".join(rows) + "\n")
    start = pipeline["SFX_BASE"]
    stop = start + len(rows) * pipeline["SFX_STRIDE"]
    cart.rom[start:stop] = audio.rom[start:stop]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    frames = v112["saw_frames"]()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v107["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(v112["source_code"], scope["source_code"], frames),
        compile_code=partial(compile_code, frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v113-") as directory:
        build(None, Path(directory), args.output)
