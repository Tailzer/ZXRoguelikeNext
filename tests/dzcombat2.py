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

WAITK = A["WAIT_FRESH_KEY"]
captured = []
def run_until(bp):
    while True:
        cmd(6, bytes([1]) + struct.pack("<H", bp) + bytes([1]) + struct.pack("<H", WAITK))
        while True:
            rseq, d = recv_msg()
            if rseq == 0: break
        pc, sp, *_ = regs()
        if pc == WAITK:
            captured.append(screen())
            ret = struct.unpack("<H", rd(sp, 2))[0]
            set_reg(1, sp + 2); set_pc(ret)
            continue
        return
def w16(name, v): wr(A[name], struct.pack("<h", v))
def r16(name): return struct.unpack("<h", rd(A[name], 2))[0]
def r32(name): return struct.unpack("<I", rd(A[name], 4))[0]
def p(): return dict(lev=rd(A["P_LEV"],1)[0], exp=r32("P_EXP"), chp=r16("P_CHP"), mhp=r16("P_MHP"), dead=rd(A["P_DEAD"],1)[0], depth=rd(A["DUN_LEVEL"],1)[0])
DISPATCH = A["DISPATCH"]
def act(cmdno, dx=0, dy=0):
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(DISPATCH); run_until(BP)
def wake_all():
    raw = bytearray(rd(0xB000, 64*16))
    for i in range(64):
        if raw[i*16+12] != 255: raw[i*16+7] = raw[i*16+8] = 0
    wr(0xB000, bytes(raw))
from collections import deque, Counter
def step_to(m, px, py, goals):
    prev = {(py, px): None}; q = deque([(py, px)])
    while q:
        c = q.popleft()
        if c in goals:
            while prev[c] and prev[c] != (py, px): c = prev[c]
            return c
        for dy in (-1,0,1):
            for dx in (-1,0,1):
                n2 = (c[0]+dy, c[1]+dx)
                if n2 not in prev and T(m[n2[0]*W+n2[1]]) in PASSABLE | {5} and not (m[n2[0]*W+n2[1]] & 0x80 and n2 not in goals):
                    prev[n2] = c; q.append(n2)

def clear_msgs():
    pc0 = regs()[0]
    call_ret(A["MSG_CLEAR"])
def call_ret(addr):
    pc, sp, *_ = regs()
    sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp); set_pc(addr); run_until(BP)
lines = []
def turn_msgs():
    out = [c[0].replace("-more-", "").strip() for c in captured]; captured.clear()
    out.append(screen()[0].strip()); return [o for o in out if o]
set_pc(A["ENTER_DUNGEON"]); run_until(BP)
descend()
ok = True
w16("P_CHP", 3000); w16("P_MHP", 3000); wake_all()
kills = Counter(); levels = []; last_lev = 1; exp_gain = []
for turn in range(300):
    if p()["chp"] < 1000: w16("P_CHP", 3000)      # (levelling up resets the maximum)
    m, px, py, vx, vy = state(); ms = mons()
    clear_msgs()
    adj = [k for k in ms if max(abs(k["y"]-py), abs(k["x"]-px)) == 1]
    e0 = p()["exp"]
    if adj:
        k = adj[0]; act(0, k["x"]-px, k["y"]-py)
    else:
        goals = {(k["y"], k["x"]) for k in ms if k["race"] not in ONLY_ATT}
        nxt = step_to(m, px, py, goals)
        if nxt is None:
            st = [i for i, b in enumerate(m) if T(b) == 8]
            sy, sx = divmod(st[0], W)
            wr(A["PLAYER_Y"], bytes([sy])); wr(A["PLAYER_X"], bytes([sx])); act(1); wake_all()
        else: act(0, nxt[1]-px, nxt[0]-py)
    msgs = turn_msgs(); lines.extend(msgs)
    for t in msgs:
        for part in t.split("You have slain the ")[1:]: kills[part.split(".")[0]] += 1
        if "Welcome to level" in t: levels.append((turn, t[t.index("Welcome"):][:22]))
    if p()["exp"] != e0: exp_gain.append(p()["exp"] - e0)
    if turn % 100 == 99:
        good, *_ = check(f"turn {turn+1:3}"); ok &= good
        print("     player:", p())
print("kills:", dict(kills))
print("level ups:", levels)
print("player:", p())
from collections import Counter as C2
kinds = C2()
for l in lines:
    for s_ in l.replace("!", ".").split(". "):
        s_ = s_.strip(" .")
        if not s_: continue
        for nm in NAMES: s_ = s_.replace(nm, "<mon>")
        kinds[s_] += 1
print("message kinds seen:")
for k_, v in kinds.most_common(30): print(f"   {v:4}x {k_}")
# ---- death ----
w16("P_MHP", 19); w16("P_CHP", 1)
wake_all()
for turn in range(400):
    if p()["dead"] or p()["chp"] == 19 and p()["exp"] == 0: break
    w16("P_CHP", 1)                          # (no regenerating out of it)
    m, px, py, vx, vy = state(); ms = mons()
    goals = {(k["y"]+dy, k["x"]+dx) for k in ms if k["race"] not in ONLY_ATT for dy in (-1,0,1) for dx in (-1,0,1)}
    if (py, px) in goals: act(3)
    else:
        nxt = step_to(m, px, py, goals)
        act(3) if nxt is None else act(0, nxt[1]-px, nxt[0]-py)
    tomb = [c for c in captured if any("R I P" in r for r in c)]
    if tomb:
        print("tombstone:")
        for r in tomb[0]:
            if r.strip(): print("   |" + r.rstrip())
        break
    captured.clear()
if p()["dead"]:
    captured.clear(); run_until(BP)
    tomb = [c for c in captured if any("R I P" in r for r in c)]
    if tomb:
        print("tombstone:", [r.strip() for r in tomb[0] if r.strip()])
after = p()
print("after death:", after)
ok &= bool(tomb) and after["lev"] == 1 and after["exp"] == 0 and after["chp"] == after["mhp"] and after["depth"] == 0 and after["dead"] == 0
cmd(2)
print("ALL OK" if ok else "FAILURES")
