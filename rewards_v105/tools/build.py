"""Build Seal Drift with compound floes and the supplied seal frames."""

import argparse
import json
from pathlib import Path
from runpy import run_path
from tempfile import TemporaryDirectory

from PIL import Image


VERSION = Path(__file__).resolve().parents[1]
ROOT = VERSION.parent
NAME = "seal_drift_v105"
v104 = run_path(str(ROOT / "rewards_v104/tools/build.py"))
v101 = v104["v101"]
assemble = v104["assemble"]
base_compile = v101["compile_code"]
flatten, literal = v101["flatten"], v101["literal"]
set_pixel = v101["v87"]["v86"]["set_pixel"]
SEAL_INKS = {
    (0, 0, 0, 0): 0,
    (29, 43, 83, 255): 1,
    (255, 241, 232, 255): 7,
}


def load_levels():
    return json.loads((VERSION / "assets/levels.json").read_text(encoding="utf-8"))


def level_bands(record):
    """A zero-height band moves the cursor so later spans can share a row."""
    if "sections" not in record:
        bands = record.get("bands", [[56, 0, 47]])
        assert sum(count for count, _, _ in bands) == 56
        assert all(count > 0 and (0 <= left <= right <= 48 or (left, right) == (1, 0))
                   for count, left, right in bands)
        return bands

    assert "bands" not in record
    result, cursor = [], 0
    for start, count, left, right in record["sections"]:
        assert 0 <= start < start + count <= 56 and 0 <= left <= right < 48
        if cursor != start:
            result.append((0, start, 0))
        result.append((count, left, right))
        cursor = start + count
    assert result
    return result


def campaign_source(previous):
    rows = load_levels()
    assert len(rows) == 10
    levels, rims = [], []
    for row in rows:
        bands = level_bands(row)
        rim = row["rim"]
        assert len(rim) >= 3 and all(4 <= x <= 99 and 12 <= y <= 123 for x, y in rim)
        assert 0 < row["stars"][0] < row["stars"][1] < 32767
        assert all(0 < row[key] < 32767 for key in ("hunt", "windup"))
        assert row["cuts"] > 0 and 1 <= row["art"] <= 5
        actors = row["seals"] + row["poachers"]
        assert 0 < len(row["seals"]) < len(actors) and all(len(actor) == 4 for actor in actors)
        levels.append([row["cuts"], len(row["seals"]), *row["stars"], len(bands),
                       *flatten(bands), *flatten(actors)])
        rims.append(flatten(rim))
    lesson = previous.split("levels=split([[", 1)[1].split("]]", 1)[0].split("|")[-1]
    return "\n".join((
        f'levels=split({literal(levels, "|")},"|")',
        'level_count=#levels',
        f'floes=split({literal(rims, "|")},"|")',
        f'level_art=split{literal([row["art"] for row in rows])}',
        f'hunt_timing=split{literal(flatten((row["hunt"], row["windup"]) for row in rows))}',
        f'lesson_level=[[{lesson}]]',
    ))


def overlay(program):
    name = "05_tech.lua"
    old = (ROOT / "rewards_v74/src" / name).read_text(encoding="utf-8").rstrip()
    new = (VERSION / "src" / name).read_text(encoding="utf-8").rstrip()
    assert program.count(old) == 1, name
    return assemble(program.replace(old, new, 1))


def compile_code(cart, stars, scratch):
    base_compile(cart, stars, scratch)
    for tile in range(4, 36):
        file = VERSION / "assets/seal" / f"{tile}.png"
        with Image.open(file) as source:
            assert source.size == (8, 8), file
            pixels = source.convert("RGBA").get_flattened_data()
        assert set(pixels) <= SEAL_INKS.keys(), file
        x, y = tile % 16 * 8, tile // 16 * 8
        for i, pixel in enumerate(pixels):
            set_pixel(cart.rom, x + i % 8, y + i // 8, SEAL_INKS[pixel])


def configure():
    build = v104["configure"]()
    v101["campaign_source"] = campaign_source
    v101["overlay"].__globals__["campaign_source"] = campaign_source
    v104["overlay"].__globals__.update(campaign_source=campaign_source, assemble=overlay)
    build.__globals__.update(NAME=NAME, compile_code=compile_code)
    return build


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=VERSION / f"{NAME}.p8")
    args = parser.parse_args()
    build = configure()
    with TemporaryDirectory(prefix="seal-drift-v105-") as directory:
        build(None, Path(directory), args.output)
