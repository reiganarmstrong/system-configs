"""Draw the wallpaper's NixOS logo at two-thirds size, and frames of it spinning.

The wallpaper logo (assets/nixos.txt) is ASCII art in fastfetch format, with
$1 and $2 switching between its two greys. This script turns that art into
shapes, turns the shapes about the vertical axis, and draws each angle as
smaller ASCII in the same style: # inside, / and \\ along slopes, _ and -
on flat edges.

    python3 fetch-logo.py nixos.txt OUT COLOUR1 COLOUR2

with each COLOUR an SGR code such as 38;2;94;98;104, writes OUT/logo.txt, the still logo for fastfetch, and OUT/frames.zsh, a zsh
array of frames for the spin (fetch-spin.zsh).
"""

import math
import re
import sys
from pathlib import Path

FRAMES = 96  # a full turn, 3.75 degrees apart
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


def frame(grid, angle):
    """Draw the logo turned by angle (radians) as rows of (char, colour)."""
    gh, gw = len(grid), len(grid[0])
    cols, rows = gw // TW, gh // TH
    half = gw / 2
    scale = math.cos(angle)
    out = []
    for r in range(rows):
        line = []
        for c in range(cols):
            samples, votes = [], [0, 0]
            for j in range(TH):
                y = r * TH + j
                for i in range(TW):
                    x = c * TW + i + 0.5 - half
                    # Undo the turn: which point of the flat logo lands here.
                    src = None
                    if abs(scale) > 1e-3:
                        sx = int(half + x / scale)
                        if 0 <= sx < gw:
                            src = grid[y][sx]
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
    return out


def trim(frames):
    """Drop columns and rows that every frame leaves blank, evenly."""
    rows, cols = len(frames[0]), len(frames[0][0])
    used_rows = [r for r in range(rows) if any(f[r][c][0] != " " for f in frames for c in range(cols))]
    used_cols = [c for c in range(cols) if any(f[r][c][0] != " " for f in frames for r in range(rows))]
    top, bottom = used_rows[0], used_rows[-1] + 1
    # Keep the axis centred so the spin doesn't wobble.
    pad = min(used_cols[0], cols - 1 - used_cols[-1])
    return [[row[pad : cols - pad] for row in f[top:bottom]] for f in frames]


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


def ansi_frame(f, colours):
    """One frame as a string that draws itself from the cursor down."""
    width = len(f[0])
    parts = []
    for row in f:
        # Bold, like fastfetch's own logo.
        colour, text = None, "\033[1m"
        for ch, c in row:
            if ch != " " and c != colour:
                text += f"\033[{colours[c]}m"
                colour = c
            text += ch
        parts.append(text + f"\033[0m\033[{width}D\033[1B")
    return "".join(parts)


def zsh_quote(s):
    return "$'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("\033", "\\e") + "'"


def main():
    art, out, colours = parse(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:5]
    grid = raster(art)
    frames = trim([frame(grid, 2 * math.pi * k / FRAMES) for k in range(FRAMES)])
    out.mkdir(parents=True, exist_ok=True)
    (out / "logo.txt").write_text(fastfetch_text(frames[0]))
    (out / "frames.zsh").write_text(
        f"fetch_logo_height={len(frames[0])}\n"
        f"fetch_logo_width={len(frames[0][0])}\n"
        "fetch_logo_frames=(\n"
        + "".join(zsh_quote(ansi_frame(f, colours)) + "\n" for f in frames)
        + ")\n"
    )


if __name__ == "__main__":
    main()
