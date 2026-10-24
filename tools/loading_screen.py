#!/usr/bin/env python3
"""Make the NEX loading screen from assets/loading.webp.

Writes assets/loading.l2 (a 256 x 192 Layer 2 screen, 256 colours, a row
at a time: the NEX format's original loading screen, which every loader
shows) and assets/loading.pal (its 256 colours, 9-bit, two bytes each as
NEXTREG $44 takes them).

The picture is scaled to 256 wide with macOS's sips (so no Python imaging
library is needed), letterboxed in black, dithered to the Next's 512 colours
(3 bits each of red, green and blue) and cut down to the 256 most used.

Usage:  tools/loading_screen.py   (from the project folder)
"""
import os, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "assets", "loading.webp")
W, H = 256, 192


def load_scaled():
    """-> (width, height, [(r, g, b)] rows top first), 320 wide"""
    bmp = os.path.join(tempfile.mkdtemp(), "loading.bmp")
    probe = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", SRC], capture_output=True, text=True).stdout
    sw = int(probe.split("pixelWidth:")[1].split()[0])
    sh = int(probe.split("pixelHeight:")[1].split()[0])
    h = round(sh * W / sw)
    subprocess.run(["sips", "-s", "format", "bmp", "-z", str(h), str(W), SRC, "--out", bmp],
                   check=True, capture_output=True)
    d = open(bmp, "rb").read()
    off = struct.unpack("<I", d[10:14])[0]
    bw, bh = struct.unpack("<ii", d[18:26])
    bpp = struct.unpack("<H", d[28:30])[0]
    assert bpp == 24, bpp
    top_down = bh < 0
    bh = abs(bh)
    stride = (bw * 3 + 3) & ~3
    rows = []
    for y in range(bh):
        row = d[off + y * stride: off + y * stride + bw * 3]
        rows.append([(row[i + 2], row[i + 1], row[i]) for i in range(0, bw * 3, 3)])
    if not top_down:
        rows.reverse()
    return bw, bh, rows


def to3(v):
    """0-255 -> 0-7, rounded"""
    return min(7, max(0, (v * 7 + 127) // 255))


def from3(v):
    return v * 255 // 7


def dither(rows, palette):
    """Floyd-Steinberg onto palette (a list of 3-bit (r, g, b)) -> rows of indexes"""
    full = [tuple(from3(c) for c in p) for p in palette]
    cache = {}
    def nearest(r, g, b):
        key = (r >> 2, g >> 2, b >> 2)
        if key not in cache:
            cache[key] = min(range(len(full)), key=lambda i: (full[i][0] - r) ** 2 * 3 + (full[i][1] - g) ** 2 * 4 + (full[i][2] - b) ** 2 * 2)
        return cache[key]
    h, w = len(rows), len(rows[0])
    err = [[[0.0, 0.0, 0.0] for _ in range(w + 2)] for _ in range(2)]
    out = []
    for y in range(h):
        cur, nxt = err[y % 2], err[(y + 1) % 2]
        for e in nxt:
            e[0] = e[1] = e[2] = 0.0
        line = []
        for x in range(w):
            r, g, b = (min(255, max(0, int(rows[y][x][c] + cur[x + 1][c]))) for c in range(3))
            i = nearest(r, g, b)
            line.append(i)
            q = full[i]
            for c, v in enumerate((r, g, b)):
                e = v - q[c]
                cur[x + 2][c] += e * 7 / 16
                nxt[x][c] += e * 3 / 16
                nxt[x + 1][c] += e * 5 / 16
                nxt[x + 2][c] += e * 1 / 16
        out.append(line)
    return out


def main():
    w, h, rows = load_scaled()
    # every 9-bit colour the picture would use, by how often
    all9 = [(r, g, b) for r in range(8) for g in range(8) for b in range(8)]
    idx = dither(rows, all9)
    counts = {}
    for line in idx:
        for i in line:
            counts[i] = counts.get(i, 0) + 1
    keep = [all9[i] for i, _ in sorted(counts.items(), key=lambda kv: -kv[1])]
    palette = [(0, 0, 0)] + [c for c in keep if c != (0, 0, 0)][:255]
    while len(palette) < 256:
        palette.append((0, 0, 0))
    idx = dither(rows, palette)
    screen = bytearray(W * H)						# index 0: black letterbox
    top = (H - h) // 2
    for y in range(h):
        for x in range(w):
            screen[(top + y) * W + x] = idx[y][x]
    pal = bytearray()
    for r, g, b in palette:
        pal += bytes([(r << 5) | (g << 2) | (b >> 1), b & 1])
    open(os.path.join(ROOT, "assets", "loading.l2"), "wb").write(screen)
    open(os.path.join(ROOT, "assets", "loading.pal"), "wb").write(pal)
    print(f"{w}x{h} picture, {len(counts)} colours used before cutting to 256; "
          f"assets/loading.l2 ({len(screen)} bytes), assets/loading.pal ({len(pal)} bytes)")


if __name__ == "__main__":
    main()
