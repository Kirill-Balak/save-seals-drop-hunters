"""Build the editable sprite sheet from the v81 art and Pixelbolt recipe."""

from functools import partial
import re


SAW = (
    (0, 32, 16, 11, 0, 2),
    (16, 32, 16, 11, 0, 2),
    (0, 48, 11, 16, 3, 0),
    (11, 48, 11, 16, 3, 0),
    (22, 48, 15, 15, 0, 1),
    (37, 48, 15, 15, 0, 1),
)
STAR_POSITIONS = {
    17: (112, 37), 18: (52, 48), 20: (70, 48), 21: (88, 48),
    23: (112, 50), 26: (110, 24), 27: (74, 24), 28: (32, 24),
    32: (54, 24), 36: (92, 24),
}


def install_art(builder, recipe_loader, recipe_file):
    """Use the original asset installer for the canonical art and the game's audio."""
    builder.install_seal_frames = partial(recipe_loader, recipe_path=recipe_file)
    cart = builder.read_cart(str(builder.BASE))
    builder.install_assets(cart)
    old = [
        "".join(format((cart.rom[y * 64 + x // 2] >> (x % 2 * 4)) & 15, "x") for x in range(128))
        for y in range(96)
    ]
    atlas_src = (builder.BASE_VERSION / "src/10_atlas.lua").read_text(encoding="utf-8")
    star_table = [int(n) for n in re.search(r"split\[\[(.*?)\]\]", atlas_src, re.S)[1].split(",")]
    sheet = [list("0" * 128) for _ in range(64)]
    occupied = set()

    def region(sx, sy, w, h, dx, dy):
        assert dx + w <= 128 and dy + h <= 64
        for x in range(dx, dx + w):
            for y in range(dy, dy + h):
                assert (x, y) not in occupied
                occupied.add((x, y))
        for y in range(h):
            sheet[dy + y][dx:dx + w] = old[sy + y][sx:sx + w]

    def tile(source, dest):
        region(source % 16 * 8, source // 16 * 8, 8, 8, dest % 16 * 8, dest // 16 * 8)

    for head in range(8):
        for frame, base in enumerate((128, 136, 0, 8)):
            tile(base + head, 4 + head * 4 + frame)
        for frame in range(2):
            tile(144 + head + frame * 8, 36 + head * 2 + frame)
    for i, (x, y, w, h, ox, oy) in enumerate(SAW):
        region(i * 16 + ox, 80 + oy, w, h, x, y)
    region(112, 80, 16, 8, 8, 0)
    tile(172, 3)
    # Ink at the center of the magnet disappears only in its idle state.
    sheet[4][27:29] = "55"

    positions = {}
    new_stars = []
    for i in range(17, 37):
        sx, sy, w, h, ox, oy = star_table[i * 6:(i + 1) * 6]
        rect = (sx, sy, w, h)
        if rect not in positions:
            x, y = positions[rect] = STAR_POSITIONS[i]
            region(*rect, x, y)
        x, y = positions[rect]
        new_stars.append((x, y, w, h, ox, oy))

    resources = builder.read_cart_from_source(
        builder.HEADER + "__gfx__\n" + "\n".join(map("".join, sheet)) + "\n"
    )
    cart.rom[:0x3200] = resources.rom[:0x3200]
    return cart, new_stars
