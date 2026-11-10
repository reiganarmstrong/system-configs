"""Draw the wallpaper's NixOS logo at two-thirds size for fastfetch.

The wallpaper logo (nixos.txt) is ASCII art in fastfetch format, with $1 and
$2 switching between its two greys. This script turns that art into shapes
and draws them as smaller ASCII in the same style: # inside, / and \\ along
slopes, _ and - on flat edges. Run it from this folder after changing
nixos.txt:

    python3 fastfetch-logo.py > fastfetch-logo.txt
"""

import re
from pathlib import Path

SX, SY = 4, 8  # samples per source cell; a terminal cell is twice as tall as wide


def parse(path):
    """Return the art as rows of (char, colour) cells."""
    rows = []
    for line in Path(path).read_text().splitlines():
        colour, row = 0, []
        for token in re.split(r"(\$\d)", line):
            if re.fullmatch(r"\$\d", token):
                colour = int(token[1]) - 1
            else:
                row += [(ch, colour) for ch in token]
        rows.append(row)
    # One blank row on top lines the art's flat edges up with the output
    # rows, so they come out as _ and - rather than slopes.
    rows.insert(0, [])
    width = max(map(len, rows))
    return [row + [(" ", 0)] * (width - len(row)) for row in rows]


def covers(ch, left, right, u, v):
    """Whether point (u, v) in [0,1)^2 of a cell holding ch is inside the shape.

    A slope's filled side is the side its # neighbours are on.
    """
    if ch == "#":
        return True
    if ch == "_":
        return v > 0.8
    if ch == "-":
        return v < 0.5
    if ch == "/":
        if right in "#\\" or left not in "#/":
            return u + v > 1  # filled to the right
        return u + v < 1
    if ch == "\\":
        if right in "#/" or left not in "#\\":
            return u > v
        return u < v
    return False


def raster(art):
    """Sample the art into a grid of None (empty) or a colour index."""
    h, w = len(art), len(art[0])
    grid = [[None] * (w * SX) for _ in range(h * SY)]
    for r, row in enumerate(art):
        for c, (ch, colour) in enumerate(row):
            left = row[c - 1][0] if c else " "
            right = row[c + 1][0] if c + 1 < w else " "
            for j in range(SY):
                for i in range(SX):
                    if covers(ch, left, right, (i + 0.5) / SX, (j + 0.5) / SY):
                        grid[r * SY + j][c * SX + i] = colour
    return grid


# What each output character looks like, sampled the same way, for matching.
TW, TH = 6, 12  # an output cell spans 1.5x1.5 source cells
GLYPHS = {}
for name, ch, l, r in [
    ("space", " ", " ", " "),
    ("full", "#", "#", "#"),
    ("slash-r", "/", " ", "#"),
    ("slash-l", "/", "#", " "),
    ("back-r", "\\", " ", "#"),
    ("back-l", "\\", "#", " "),
    ("under", "_", " ", " "),
    ("dash", "-", " ", " "),
]:
    GLYPHS[name] = (
        ch,
        [covers(ch, l, r, (i + 0.5) / TW, (j + 0.5) / TH) for j in range(TH) for i in range(TW)],
    )


def draw(grid):
    """Draw the sampled art as rows of (char, colour)."""
    out = []
    for r in range(len(grid) // TH):
        line = []
        for c in range(len(grid[0]) // TW):
            samples, votes = [], [0, 0]
            for j in range(TH):
                for i in range(TW):
                    src = grid[r * TH + j][c * TW + i]
                    samples.append(src is not None)
                    if src is not None:
                        votes[src] += 1
            if not any(samples):
                line.append((" ", 0))
                continue
            ch = min(
                GLYPHS.values(),
                key=lambda g: sum(a != b for a, b in zip(g[1], samples)),
            )[0]
            line.append((ch, 0 if votes[0] >= votes[1] else 1))
        out.append(line)
    # Drop blank rows and columns around the logo.
    rows = [r for r, line in enumerate(out) if any(ch != " " for ch, _ in line)]
    cols = [c for c in range(len(out[0])) if any(line[c][0] != " " for line in out)]
    return [line[cols[0] : cols[-1] + 1] for line in out[rows[0] : rows[-1] + 1]]


def fastfetch_text(f):
    lines, colour = [], None
    for row in f:
        text = ""
        for ch, c in row:
            if ch != " " and c != colour:
                text += f"${c + 1}"
                colour = c
            text += ch
        lines.append(text.rstrip())
    # fastfetch starts every line in colour 1, so restate the colour.
    fixed, colour = [], 0
    for line in lines:
        fixed.append(("$" + str(colour + 1) if not line.startswith("$") else "") + line)
        for m in re.finditer(r"\$(\d)", line):
            colour = int(m[1]) - 1
    return "\n".join(fixed) + "\n"


if __name__ == "__main__":
    art = parse(Path(__file__).with_name("nixos.txt"))
    print(fastfetch_text(draw(raster(art))), end="")
