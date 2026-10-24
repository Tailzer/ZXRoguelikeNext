import sys
exec(open("dztest.py").read().split("cmd(1, bytes")[0])
cmd(1, bytes([2, 0, 0]) + b"test\0")
install_keys()
W, H = 198, 66
CH = "#..##+'#><##%%"
PASS = {1, 2, 5, 6, 7, 8, 9}   # floor, corridor, doors (incl. secret), stairs
def report(tag):
    m = rd(0xC000, W * H)
    px, py, lvl = rd(A["PLAYER_X"], 1)[0], rd(A["PLAYER_Y"], 1)[0], rd(A["DUN_LEVEL"], 1)[0]
    counts = {}
    for b in m: counts[b] = counts.get(b, 0) + 1
    names = ["null","floor","corr","granite","perm","closed","open","secret","down","up","tmp1","tmp2","magma","quartz"]
    print(f"== {tag}: level {lvl}, player ({px},{py}) on {names[m[py*W+px]]}")
    print("   ", ", ".join(f"{names[k] if k < len(names) else k}={v}" for k, v in sorted(counts.items())))
    seen = {(py, px)}; q = deque([(py, px)])
    while q:
        y, x = q.popleft()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                ny, nx = y + dy, x + dx
                if (ny, nx) not in seen and m[ny*W+nx] in PASS:
                    seen.add((ny, nx)); q.append((ny, nx))
    openc = sum(1 for i, b in enumerate(m) if b in (1, 2, 8, 9))
    reach = sum(1 for (y, x) in seen if m[y*W+x] in (1, 2, 8, 9))
    print(f"    reachable floor {reach}/{openc}; border ok: {all(m[x]==4 and m[(H-1)*W+x]==4 for x in range(W)) and all(m[y*W]==4 and m[y*W+W-1]==4 for y in range(H))}")
    return m
def dump_map(m, path):
    with open(path, "w") as f:
        for y in range(H):
            f.write("".join(CH[b] if b < len(CH) else "?" for b in m[y*W:(y+1)*W]) + "\n")
def screen():
    tm = rd(0x6000, 80*32*2)
    return ["".join(chr(tm[(r*80+c)*2]) if 32 <= tm[(r*80+c)*2] < 127 else "?" for c in range(80)) for r in range(32)]
def set_reg(r, v): cmd(4, bytes([r]) + struct.pack("<H", v))
DISPATCH = A["DISPATCH"]
BP = A["MAIN_LOOP"] + 6
T = lambda b: b & 15
PASSABLE = {1, 2, 6, 8, 9, 14}
REMEMBER = {3, 4, 5, 6, 7, 8, 9, 12, 13}
def state():
    m = rd(0xC000, W * H)
    return m, rd(A["PLAYER_X"], 1)[0], rd(A["PLAYER_Y"], 1)[0]
def check(m, px, py, tag):
    errs = []
    lamp = {(i // W, i % W) for i, b in enumerate(m) if b & 0x40}
    want = {(py + dy, px + dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1)}
    if lamp != want: errs.append(f"lamp squares wrong: extra {sorted(lamp-want)[:5]} missing {sorted(want-lamp)[:5]}")
    for i, b in enumerate(m):
        y, x = divmod(i, W)
        if b & 0x20 and T(b) not in REMEMBER and not b & 0x10:
            errs.append(f"non-room open square remembered at {(y,x)} t={T(b)}"); break
    # room under/next to player: if lit, whole connected room must be lit
    seeds = [(py+dy, px+dx) for dy in (-1,0,1) for dx in (-1,0,1) if T(m[(py+dy)*W+px+dx]) == 14]
    if T(m[py*W+px]) == 14 or (m[py*W+px] & 0x10):
        from collections import deque
        for sy, sx in seeds:
            seen = {(sy, sx)}; q = deque([(sy, sx)])
            while q:
                y, x = q.popleft()
                if T(m[y*W+x]) not in PASSABLE: continue
                for dy in (-1,0,1):
                    for dx in (-1,0,1):
                        n = (y+dy, x+dx)
                        if n not in seen and m[n[0]*W+n[1]] & 0x10:
                            seen.add(n); q.append(n)
            unlit = [s for s in seen if not m[s[0]*W+s[1]] & 0x20]
            if unlit: errs.append(f"room from {(sy,sx)}: {len(unlit)}/{len(seen)} squares not lit")
    seen_count = sum(1 for b in m if b & 0x60)
    print(f"{tag}: player ({px},{py}) on t={T(m[py*W+px])} room={bool(m[py*W+px]&0x10)}; visible squares {seen_count}; " + ("OK" if not errs else "ERRORS: " + "; ".join(errs)))
    return not errs
def move(dx, dy):
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, 0); set_pc(DISPATCH); run_to(BP)
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend(); wr(A["DUN_LEVEL"], bytes([29])); descend()
m, px, py = state()
ok = check(m, px, py, "arrival")
sc = screen()
print("\n".join(f"{r:2}|{sc[r]}|" for r in range(0, 32)))
from collections import deque
def path_to(m, px, py, goal):
    prev = {(py, px): None}; q = deque([(py, px)])
    while q:
        c = q.popleft()
        if goal(c) and c != (py, px):
            out = []
            while prev[c]: out.append(c); c = prev[c]
            return out[::-1]
        for dy in (-1,0,1):
            for dx in (-1,0,1):
                n = (c[0]+dy, c[1]+dx)
                if n not in prev and T(m[n[0]*W+n[1]]) in PASSABLE | {5}:
                    prev[n] = c; q.append(n)
def walk(goal, label, extra=0):
    global m, px, py, ok
    p = path_to(m, px, py, goal)
    if not p: print("no path for", label); return
    p += []
    for i, (y, x) in enumerate(p):
        while (py, px) != (y, x):
            move(x - px, y - py)
            m, px, py = state()
        ok &= check(m, px, py, f"{label} step {i:3}") if (i >= len(p) - 3 or i % 10 == 0) else True
lit_unvisited = lambda c: T(m[c[0]*W+c[1]]) == 14 and not m[c[0]*W+c[1]] & 0x20
walk(lit_unvisited, "to lit room")
sc = screen(); print("\n".join(f"{r:2}|{sc[r]}|" for r in range(0, 32)))
dark = lambda c: T(m[c[0]*W+c[1]]) == 1
walk(dark, "to dark room")
for k in range(4):
    p = path_to(m, px, py, lambda c: T(m[c[0]*W+c[1]]) == 1 and abs(c[0]-py)+abs(c[1]-px) > 3)
    if p:
        for (y, x) in p[:4]:
            move(x - px, y - py); m, px, py = state()
ok &= check(m, px, py, "inside dark room")
sc = screen()
print("\n".join(f"{r:2}|{sc[r]}|" for r in range(0, 32)))
print("ALL OK" if ok else "FAILURES")
cmd(2)
