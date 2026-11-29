"""Build v79 with the v78 cartridge pipeline and a new seal recipe."""

import argparse
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory


VERSION = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(VERSION.parent / "rewards_v78/tools"))
import build as previous


FRAME_BASES = (("glide", 128), ("lift", 136), ("push", 0), ("release", 8))
HEADINGS = ("e", "ne", "n", "ne", "e", "se", "s", "se")
PICO8_PIXELS = str.maketrans(".osf", "0167")


def install_seal_frames(rows, recipe_path=VERSION / "assets/seal-cycle.pixel.json"):
    recipe = json.loads(recipe_path.read_text(encoding="utf-8"))
    assert (recipe["width"], recipe["height"]) == (8, 8)
    assert recipe["palette"] == {"o": "#1d2b53", "s": "#c2c3c7", "f": "#fff1e8"}
    frames = {frame["name"]: frame for frame in recipe["frames"]}
    assert len(frames) == len(recipe["frames"]) == 20

    for face, heading in enumerate(HEADINGS):
        for phase, base in FRAME_BASES:
            frame = frames[f"{heading}-{phase}"]
            assert frame["anchor"] == [4, 4] and frame["duration"] == 200
            grid, = frame["ops"]
            assert grid == {"op": "grid", "x": 0, "y": 0, "rows": grid["rows"]}
            sprite = grid["rows"]
            assert len(sprite) == 8 and all(len(row) == 8 and set(row) <= set(".osf") for row in sprite)
            slot = base + face
            x, y = slot % 16 * 8, slot // 16 * 8
            for dest, source in zip(rows[y:y + 8], sprite):
                pixels = source.translate(PICO8_PIXELS)
                dest[x:x + 8] = pixels[::-1] if face in (3, 4, 5) else pixels


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", type=Path)
    previous.CART_NAME = str(VERSION / "seal_drift_v79")
    previous.install_seal_frames = install_seal_frames
    with TemporaryDirectory(prefix="seal-drift-v79-") as folder:
        previous.build(parser.parse_args().label, Path(folder))
