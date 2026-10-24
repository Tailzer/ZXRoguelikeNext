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

KINDS = [k["name"] for k in KIND_RECS]
KCLASS = [k["raw"][2] for k in KIND_RECS]
def r16(n): return struct.unpack("<h", rd(A[n], 2))[0]
def w16(n, v): wr(A[n], struct.pack("<h", v))
def r8(n): v = rd(A[n],1)[0]; return v - 256 if v > 127 else v
def rec_list(base, n):
    raw = rd(base, n*14); out = []
    for i in range(n):
        r = raw[i*14:i*14+14]
        out.append(None if r[1] == 255 else dict(kind=0xFE if r[1] == 0xFE else r[0] | r[1] << 8, num=r[2], y=r[3], x=r[4], marked=r[5], value=r[6]|r[7]<<8, sub=r[8], ident=r[8], tohit=r[9]-256 if r[9]>127 else r[9], todam=r[10]-256 if r[10]>127 else r[10], toac=r[11]-256 if r[11]>127 else r[11], name2=r[12], feel=r[13]))
    return out
def floor(): return [r for r in rec_list(0xB400, 64) if r]
def pack(): return rec_list(A["PACK"], 12)
def equip(): return rec_list(A["EQUIP"], 7)
def kname(r): return "gold" if r["kind"] == 0xFE else KINDS[r["kind"]]
def player():
    return dict(chp=r16("P_CHP"), mhp=r16("P_MHP"), ac=rd(A["P_AC"],1)[0], tohit=r8("P_TOHIT"), todam=r8("P_TODAM"), blows=rd(A["P_BLOWS"],1)[0],
                dice=f'{rd(A["W_DICE"],1)[0]}d{rd(A["W_SIDES"],1)[0]}', weight=r16("W_WEIGHT"), food=r16("P_FOOD"), hunger=rd(A["P_HUNGER"],1)[0],
                gold=struct.unpack("<I", rd(A["P_GOLD"],4))[0], dead=rd(A["P_DEAD"],1)[0])
def show_pack():
    return [f"{chr(97+i)}) {r['num']} {kname(r)}" for i, r in enumerate(pack()) if r]
def show_equip():
    return [kname(r) if r else "-" for r in equip()]
# patch the key waits: -more- returns at once, read_ascii returns ascii_key
wr(A["WAIT_FRESH_KEY"], bytes([0xC9]))
CMDS = dict(i=4, e=5, w=6, t=7, q=8, E=9, d=10, g=11)
def command(c, answer=" ", capture=False):
    wr(A["ASCII_KEY"], answer.encode())
    set_reg(3, 0); set_reg(4, CMDS[c] << 8); set_pc(A["DISPATCH"])
    shot = None
    if capture:
        run_to(A["READ_ASCII"]); shot = screen()
    run_to(BP)
    return shot
def act(cmdno, dx=0, dy=0):
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
def msgline(): return screen()[0].strip()

from collections import Counter
ok = True
def expect(cond, what):
    global ok
    print(("  ok   " if cond else "  FAIL ") + what); ok &= bool(cond)
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
w16("P_CHP", 3000); w16("P_MHP", 3000)
seen_uniques = Counter(); levels_all = []; item_levels = []
for depth in (10, 20, 30, 40):
    wr(A["DUN_LEVEL"], bytes([depth - 1]))
    m = bytes(b & 15 for b in rd(0xC000, W*H)); i = m.index(8)
    wr(A["PLAYER_Y"], bytes([i // W])); wr(A["PLAYER_X"], bytes([i % W]))
    act(1)
    ms = mons(); raw = rd(0xB000, 64*16)
    lv = [RACES[k["race"]]["level"] for k in ms]
    levels_all += lv
    bad = sorted(k["race"] for k in ms if k["race"] >= len(RACES)); print("   out-of-range races:", bad[:10], "of", len(ms)); ms = [k for k in ms if k["race"] < len(RACES)]; lv = [RACES[k["race"]]["level"] for k in ms]
    uniq = [NAMES[k["race"]] for k in ms if RACES[k["race"]]["raw"][13] & 1]
    dup = [n for n, c in Counter(uniq).items() if c > 1]
    maxhp_ok = all((raw[i*16+5] | raw[i*16+6] << 8) == RACES[raw[i*16] | raw[i*16+12] << 8]["raw"][9] * RACES[raw[i*16] | raw[i*16+12] << 8]["raw"][10]
                   for i in range(64) if raw[i*16+12] != 255 and RACES[raw[i*16] | raw[i*16+12] << 8]["raw"][13] & 2)
    objs = [r for r in floor() if r["kind"] != 0xFE]
    ilv = [KIND_RECS[r["kind"]]["level"] for r in objs]; item_levels += ilv
    print(f"level {depth}: {len(ms)} monsters, levels min {min(lv)} median {sorted(lv)[len(lv)//2]} max {max(lv)}; uniques {uniq}")
    print(f"   sample: {sorted({NAMES[k['race']] for k in ms})[:12]}")
    print(f"   items ({len(objs)}): {sorted(KINDS[r['kind']] for r in objs)[:10]}")
    expect(not dup, "no unique twice on a level")
    expect(maxhp_ok, "max-hp monsters have full hit points")
    expect(max(lv) <= 99 and min(lv) >= 1, "no town monsters, levels within 1-99")
    expect(sum(1 for x in lv if x <= depth) >= len(lv) * 0.8, "most monsters at or above the dungeon level")
# fight some deep monsters to see their names in messages
w16("P_CHP", 30000); w16("P_MHP", 30000)
msgs = Counter()
for t in range(40):
    act(3)
    for part in screen()[0].replace("-more-", "").split(". "):
        if part.strip(): msgs[part.strip()] += 1
print("messages while waiting at level 40:")
for k_, v in msgs.most_common(12): print(f"   {v}x {k_}")
cmd(2)
print("ALL OK" if ok else "FAILURES")
