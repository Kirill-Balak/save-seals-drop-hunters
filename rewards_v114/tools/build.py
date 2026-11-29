"""Add short cues alongside the v113 audio."""

import argparse
from functools import partial
import json
from pathlib import Path
import re
from runpy import run_path
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
NAME = "seal_drift_v114"
v113 = run_path(str(VERSION.parent / "rewards_v113/tools/build.py"))
v112, v105, v101, v107, v108 = (v113[name] for name in ("v112", "v105", "v101", "v107", "v108"))
v111 = v112["v111"]
builder = v101["builder"]
BASE_MUSIC = v111["import_music"]
BASE_ATLAS = v111["install_atlas"]
GROUPS = json.loads((VERSION / "assets/cues.json").read_text(encoding="utf-8"))
IDS = {name: group * 6 + index for group, entry in enumerate(GROUPS)
       for index, name in enumerate(entry["cues"])}


def overlay(program):
    program = v113["overlay"](program)
    helper = (VERSION / "src/cues.lua").read_text(encoding="utf-8").rstrip()
    replacements = (
        ("function rescue_start()", helper + "\n\nfunction rescue_start()"),
        ('notice=9\n\t\tif tut then\n\t\t\ttutorial_result(false)\n\t\tend',
         'notice=9\n\t\tif tut then\n\t\t\ttutorial_result(false)\n\t\telse cue(@invalid) end'),
        ('phase="aim"\n\t\t\tnotice=9', 'phase="aim"\n\t\t\tnotice=9\n\t\t\tcue(@invalid)'),
        ('if o==thrower then release_line() end',
         'if o==thrower then\n\t\t\t\tc.saved=snared\n\t\t\t\trelease_line()\n\t\t\tend'),
        ('phase="resolve"\n\t\twait=3',
         'if c.saved then cue(@rescue) c.saved=nil end\n\t\tphase="resolve"\n\t\twait=3'),
        ('tether_left-=1', 'tether_left-=1\n\t\tif tether_left==44 then cue(@rescue_warning) end'),
        ('if flight==0 then release_line() end', 'if flight==0 then\n\t\t\trelease_line()\n\t\t\tcue(@harpoon_miss)\n\t\tend'),
        ('sfx(5)\n\tend', 'sfx(5)\n\telse cue(@charge_increment)\n\tend'),
        ('placing,hold_o=true,-1', 'placing,hold_o=true,-1\n\t\tcue(@magnet_aim)'),
        ('if hold_o>=18 then placing=nil end', 'if hold_o>=18 then placing=nil cue(@magnet_cancel) end'),
        ('\tsfx(6)\n\tend', '\tsfx(6)\n\telseif place_now then cue(@invalid)\n\tend'),
        ('magnet,blocked=0,nil\n\t\treturn', 'magnet,blocked=0,nil\n\t\tcue(@magnet_end)\n\t\treturn'),
        ('hunter,target,blocked=nil,nil,true', 'hunter,target,blocked=nil,nil,true\n\t\t\t\tcue(@hunt_interrupted)'),
        ('t_passed=ok', 't_passed=ok\n\tcue(ok and @lesson_pass or @lesson_retry)'),
        ('start_level(n)\n\t\tend\n\t\tif selected!=n then',
         'start_level(n)\n\t\t\tcue(@menu_confirm)\n\t\telseif fresh and n>unlocked then cue(@invalid)\n\t\tend\n\t\tif selected!=n then\n\t\t\tcue(@menu_move)'),
        ('if confirm(menu_choice!=old,', 'if ready and menu_choice!=old then cue(@menu_move) end\n\t\tif confirm(menu_choice!=old,'),
        ('\t\t\taction()', '\t\t\taction()\n\t\t\tcue(@menu_confirm)'),
        ('ending=min(ending+1,last)',
         'ending=min(ending+1,last)\n\t\tlocal reveal=ending-result_delay\n'
         '\t\tif reveal==0 and cut and cut.saved then cue(@rescue) end\n'
         '\t\tlocal star=reveal-48\n'
         '\t\tif victory and star>0 and star%6==0 and star\\6<=result.stars then cue(@star) end'),
        ('ending=last\n\t\t\tmenu_hold=-1',
         'if victory and reveal<48+result.stars*6 then cue(@star) end\n\t\t\tending=last\n\t\t\tmenu_hold=-1'),
    )
    for old, new in replacements:
        assert program.count(old) == 1, old
        program = program.replace(old, new, 1)
    program, count = re.subn(
        r"score_bank\+=([a-z0-9_]+)\.n",
        r"\g<0>\n\t\t\tcue(\1.k==2 and @single or @combo)",
        program,
    )
    assert count == 1
    for name, number in sorted(IDS.items(), key=lambda item: -len(item[0])):
        key = "@" + name
        assert key in program, name
        program = program.replace(key, str(number))
    return program


def music_with_cues():
    first, sounds, patterns = BASE_MUSIC()
    rows = []
    for group in GROUPS:
        assert 1 <= len(group["cues"]) <= 6
        notes = []
        for cue in group["cues"].values():
            assert 1 <= len(cue) <= 5
            notes.extend(cue + [[0, 0, 0]] * (5 - len(cue)))
        rows.append(v113["effect_row"]({"speed": group["speed"], "loop": [0, 0], "notes": notes}))
    assert first - len(rows) == 46
    asset = builder.read_cart_from_source(builder.HEADER + "__sfx__\n" + "\n".join(rows) + "\n")
    start = v111["SFX_START"]
    cue_data = asset.rom[start:start + len(rows) * v111["SFX_STRIDE"]]
    return first - len(rows), bytes(cue_data) + sounds, patterns


def install_atlas(cart, scratch, displaced):
    source = cart.code.split("local spans=split[[", 1)[1].split("]]", 1)[0]
    raw_size = sum(int(n) for n in re.findall(r"\d+", source)[1::2])
    literals = (scratch / "literals.bin").read_bytes()[raw_size:]
    BASE_ATLAS(cart, scratch, displaced)

    spans = [(a + y * 64, w) for a, w, h in v111["ATLAS"] for y in range(h)]
    payload = b"".join(cart.rom[a:a + w] for a, w in spans)
    dictionary_start = len(displaced)
    marker = re.search(r"local j=dict\+(\d+)\n", cart.code)
    assert marker
    dictionary_end = dictionary_start + int(marker[1])
    dictionary = payload[dictionary_start:dictionary_end]
    palette = bytes(dict.fromkeys(dictionary))
    assert len(palette) == 16
    codes = [palette.index(b) for b in dictionary]
    packed = palette + bytes(a + 16 * b for a, b in zip(codes[::2], codes[1::2]))
    indices = payload[dictionary_end:dictionary_end + len(payload) // 4]
    atlas = displaced + packed + indices
    capacity = len(payload) - len(atlas)
    assert 0 <= capacity <= len(literals)
    atlas += literals[:capacity]
    assert v111["SCRATCH_RAM"] + len(atlas) + len(dictionary) <= 0x5600
    offset = 0
    for a, w in spans:
        cart.rom[a:a + w] = atlas[offset:offset + w]
        offset += w
    assert offset == len(atlas)

    decoder = (VERSION / "src/atlas_decode.lua").read_text(encoding="utf-8")
    line = f"local j=dict+{len(packed)}\n" + decoder
    cart.code = cart.code[:marker.start()] + line + cart.code[marker.end():]
    cart.code = cart.code.replace("dict+4*peek(j)", "tail+4*peek(j)", 1)
    start = cart.code.index("local more=")
    stop = cart.code.index("\n]]", start) + 3
    tail = v101["v83"]["folded_literal"](literals[capacity:])
    cart.code = cart.code[:start] + "local more=" + tail + cart.code[stop:]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    frames = v112["saw_frames"]()
    build = v105["configure"]()
    v105["campaign_source"].__globals__["load_levels"] = v107["load_levels"]
    v105["v104"]["overlay"].__globals__["assemble"] = overlay
    v101["compile_code"].__globals__["unused_spans"] = v108["unused_spans"]
    v111["compile_code"].__globals__["import_music"] = music_with_cues
    v111["compile_code"].__globals__["install_atlas"] = install_atlas
    scope = build.__globals__
    scope.update(
        NAME=NAME, source_code=partial(v112["source_code"], scope["source_code"], frames),
        compile_code=partial(v113["compile_code"], frames),
    )
    with TemporaryDirectory(prefix="seal-drift-v114-") as directory:
        build(None, Path(directory), args.output)
