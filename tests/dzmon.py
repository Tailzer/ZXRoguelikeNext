import sys, random
exec(open("dztest.py").read().split("cmd(1, bytes")[0])
cmd(1, bytes([2, 0, 0]) + b"test\0")
install_keys()
W, H = 198, 66
T = lambda b: b & 15
PASSABLE = {1, 2, 6, 8, 9, 14}
def screen():
    tm = rd(0x6000, 80*32*2)
    return ["".join(chr(tm[(r*80+c)*2]) if 32 <= tm[(r*80+c)*2] < 127 else "?" for c in range(80)) for r in range(32)]
def regs():
    r = cmd(3); return struct.unpack("<HHHHHH", r[:12])  # PC SP AF BC DE HL
def set_reg(i, v): cmd(4, bytes([i]) + struct.pack("<H", v))
BP = A["MAIN_LOOP"] + 6
def call(addr, de=None):
    pc, sp, *_ = regs()
    sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp)
    if de is not None: set_reg(4, de)
    set_pc(addr); run_to(BP)
    return regs()
def py_los(m, fy, fx, ty, tx):
    blk = lambda y, x: T(m[y*W+x]) not in PASSABLE
    dX, dY = tx - fx, ty - fy
    if -2 < dX < 2 and -2 < dY < 2: return True
    if dX == 0:
        a, b = sorted((fy, ty))
        return not any(blk(y, fx) for y in range(a+1, b))
    if dY == 0:
        a, b = sorted((fx, tx))
        return not any(blk(fy, x) for x in range(a+1, b))
    s2 = abs(dX*dY); s = s2*2; xs = 1 if dX > 0 else -1; ys = 1 if dY > 0 else -1
    if abs(dX) >= abs(dY):
        d = dY*dY; mm = d*2; px = fx + xs
        if d == s2: py = fy + ys; d -= s
        else: py = fy
        while tx - px:
            if blk(py, px): return False
            d += mm
            if d < s2: px += xs
            elif d > s2:
                py += ys
                if blk(py, px): return False
                px += xs; d -= s
            else: px += xs; py += ys; d -= s
        return True
    else:
        d = dX*dX; mm = d*2; py = fy + ys
        if d == s2: px = fx + xs; d -= s
        else: px = fx
        while ty - py:
            if blk(py, px): return False
            d += mm
            if d < s2: py += ys
            elif d > s2:
                px += xs
                if blk(py, px): return False
                py += ys; d -= s
            else: px += xs; py += ys; d -= s
        return True
def mons():
    raw = rd(A["MON_LIST"] if "MON_LIST" in A else 0xB000, 64*16)
    out = []
    for i in range(64):
        r = raw[i*16:(i+1)*16]
        if r[12] != 255: out.append(dict(race=r[0] | r[12] << 8, y=r[1], x=r[2], hp=r[3]|r[4]<<8, sleep=r[7]|r[8]<<8, speed=r[9]-256 if r[9]>127 else r[9], cdis=r[10], ml=r[11]))
    return out
def state():
    return rd(0xC000, W*H), rd(A["PLAYER_X"],1)[0], rd(A["PLAYER_Y"],1)[0], rd(A["VIEW_X"],1)[0], rd(A["VIEW_X"]+1,1)[0]
def dist(y1,x1,y2,x2):
    dy, dx = abs(y1-y2), abs(x1-x2); return ((dy+dx)*2 - min(dy,dx)) >> 1
def check(tag):
    m, px, py, vx, vy = state(); ms = mons(); errs = []
    flagged = {(i//W, i%W) for i, b in enumerate(m) if b & 0x80}
    pos = [(k["y"], k["x"]) for k in ms]
    if len(set(pos)) != len(pos): errs.append("two monsters share a square")
    if flagged != set(pos): errs.append(f"F_MON mismatch: extra {sorted(flagged-set(pos))[:3]} missing {sorted(set(pos)-flagged)[:3]}")
    if (py, px) in pos: errs.append("monster on player")
    for k in ms:
        if T(m[k["y"]*W+k["x"]]) not in PASSABLE: errs.append(f"monster in wall at {(k['y'],k['x'])}")
        d = dist(py, px, k["y"], k["x"])
        if d != k["cdis"] and d < 255: errs.append(f"cdis {k['cdis']} != {d}")
        vis = d <= 20 and 0 <= k["y"]-vy < 30 and 0 <= k["x"]-vx < 80 and (m[k["y"]*W+k["x"]] & 0x60) and not (RACES[k["race"]]["raw"][13] & 4) and py_los(m, py, px, k["y"], k["x"])
        if bool(vis) != bool(k["ml"]): errs.append(f"{NAMES[k['race']]} at {(k['y'],k['x'])} ml={k['ml']} expected {bool(vis)}")
    tm = rd(0x6000, 80*32*2); drawn_bad = []
    for k in ms:
        if k["ml"]:
            sr, sc = k["y"] - vy + 1, k["x"] - vx
            if tm[(sr*80+sc)*2] != RACES[k["race"]]["raw"][0]: drawn_bad.append((NAMES[k["race"]], chr(tm[(sr*80+sc)*2])))
    if drawn_bad: errs.append(f"visible monsters not drawn: {drawn_bad[:3]}")
    print(f"{tag}: {len(ms)} monsters, {sum(k['ml'] for k in ms)} visible, awake {sum(1 for k in ms if k['sleep']==0)} - " + ("OK" if not errs else "ERRORS " + "; ".join(errs[:4])))
    return not errs, m, px, py, ms
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
for nm in ("P_CHP", "P_MHP"): wr(A[nm], struct.pack("<h", 3000))
ok, m, px, py, ms = check("arrival")
from collections import Counter
print("  races:", dict(Counter(NAMES[k["race"]] for k in ms)))
print("  hp ranges ok:", all(1 <= k["hp"] for k in ms), " speeds:", sorted(set(k["speed"] for k in ms)))
# --- los unit test against the Python port of the C ---
random.seed(7)
floors = [i for i, b in enumerate(m) if T(b) in PASSABLE]
mismatch = 0; n = 0; seen_true = 0
for _ in range(400):
    f = random.choice(floors); fy, fx = divmod(f, W)
    cands = [i for i in floors if dist(fy, fx, *divmod(i, W)) <= 20]
    t = random.choice(cands); ty, tx = divmod(t, W)
    wr(A["PLAYER_Y"], bytes([fy])); wr(A["PLAYER_X"], bytes([fx]))
    *_, af, bc, de, hl = call(A["LOS"], (ty << 8) | tx)
    got = bool(af & 1); want = py_los(m, fy, fx, ty, tx); n += 1; seen_true += want
    if got != want:
        mismatch += 1
        if mismatch < 5: print(f"  los mismatch from {(fy,fx)} to {(ty,tx)}: z80 {got} c {want}")
print(f"los: {n} pairs tested, {seen_true} visible, {mismatch} mismatches")
ok &= mismatch == 0
wr(A["PLAYER_Y"], bytes([py])); wr(A["PLAYER_X"], bytes([px]))
# --- turns: walk towards the nearest monster, checking every turn ---
DISPATCH = A["DISPATCH"]
def move(dx, dy):
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, 0); set_pc(DISPATCH); run_to(BP)
from collections import deque
def step_towards(m, px, py, goal):
    prev = {(py, px): None}; q = deque([(py, px)])
    while q:
        c = q.popleft()
        if c in goal:
            while prev[c] and prev[c] != (py, px): c = prev[c]
            return c
        for dy in (-1,0,1):
            for dx in (-1,0,1):
                n2 = (c[0]+dy, c[1]+dx)
                if n2 not in prev and (T(m[n2[0]*W+n2[1]]) in PASSABLE | {5} or n2 in goal):
                    prev[n2] = c; q.append(n2)
start = {(k["y"], k["x"]): k for k in ms}
for turn in range(120):
    goal = {(k["y"]+dy, k["x"]+dx) for k in ms for dy in (-1,0,1) for dx in (-1,0,1) if (dy or dx)}
    nxt = step_towards(m, px, py, goal - {(k["y"],k["x"]) for k in ms}) if (py,px) not in goal else None
    if nxt is None:
        move(0, 0) if False else None
        # stand still: walk into a wall doesn't take a turn, so step back and forth
        for d in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)]:
            if T(m[(py+d[1])*W+px+d[0]]) in PASSABLE and not m[(py+d[1])*W+px+d[0]] & 0x80:
                move(*d); break
    else:
        move(nxt[1]-px, nxt[0]-py)
    if turn % 10 == 9: print("   player", (py, px), "nearest monster cdis", min(k["cdis"] for k in ms), "awake & near:", sum(1 for k in ms if k["sleep"]==0 and k["cdis"]<=10))
    good, m, px, py, ms = check(f"turn {turn:3}") if turn % 10 == 9 or turn < 3 else (True,) + state()[:3] + (mons(),)
    ok &= good
moved = sum(1 for k in ms if (k["y"], k["x"]) not in start)
print(f"monsters that have moved from their start square: {moved}/{len(ms)}")
msg = screen()[0].strip(); print("last message:", repr(msg))
sc = screen(); print("\n".join(f"{r:2}|{sc[r]}|" for r in range(1, 31) if sc[r].strip()))
print("ALL OK" if ok else "FAILURES")
cmd(2)
