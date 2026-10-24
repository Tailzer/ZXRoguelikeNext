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
# -more- returns at once; read_ascii is patched after the character is made
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
ok = True
def expect(cond, what):
    global ok
    print(("  ok   " if cond else "  FAIL ") + what); ok &= bool(cond)
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
wr(A["READ_ASCII"], bytes([0x3A]) + struct.pack("<H", A["ASCII_KEY"]) + bytes([0xC9]))
for i in range(64):						# no monsters to interrupt the messages
    b = 0xB000 + 16*i
    if rd(b + 12, 1)[0] != 255:
        y, x = rd(b + 1, 2); wr(0xC000 + y*198 + x, bytes([rd(0xC000 + y*198 + x, 1)[0] & 0x7F])); wr(b + 12, bytes([255]))
CLW = [i for i, k in enumerate(KIND_RECS) if "Cure Light" in k["name"]][0]
wr(A["PACK"] + 14, bytes([CLW & 255, CLW >> 8, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0]))	# a store-bought (known) potion to test with
for i_ in range(2, 12): wr(A["PACK"] + 14*i_, bytes([0, 255] + [0]*12))	# (the kit's torches and the rest)
p = player()
print("start:", p); print("  pack:", show_pack(), " equip:", show_equip())
expect(show_equip() == ["Broadsword", "Chain Mail", "-", "-", "-", "-", "-"], "starts wielding a Broadsword, wearing Chain Mail")
sac = rd(A["P_STAT_TOAC"],1)[0]; sac = sac - 256 if sac > 127 else sac
shit = rd(A["P_STAT_TOHIT"],1)[0]; shit = shit - 256 if shit > 127 else shit
expect(p["ac"] == max(0, 14 + sac) and p["tohit"] == -2 + shit and p["dice"] == "2d5" and p["weight"] == 150 and p["blows"] >= 1, "bonuses: Chain Mail 14 + DEX, to-hit -2 + stats, 2d5, 15 lb")
expect(p["food"] == 7500, "food 7500")
# ---- placement
m, px, py, vx, vy = state()
fl = floor()
objs = [r for r in fl if r["kind"] != 0xFE]; golds = [r for r in fl if r["kind"] == 0xFE]
print(f"floor: {len(objs)} objects, {len(golds)} piles of treasure:", sorted(kname(r) for r in objs))
squares = [(r["y"], r["x"]) for r in fl]
expect(len(set(squares)) == len(squares), "one item per square")
expect(all(T(m[y*W+x]) in PASSABLE for y, x in squares), "all on open floor")
expect((py, px) not in squares, "none under the player")
expect(all(r["kind"] < len(KINDS) for r in objs), "object kinds valid")
expect(all(0 <= r["sub"] < 18 and r["value"] > 0 for r in golds), "treasure types and values sane")
# ---- inventory / equipment screens
s1 = command("i", capture=True)
print("  'i' screen:", [l.strip() for l in s1[1:4] if l.strip()])
expect(any("a) a Ration of Food" in l for l in s1) and any("b) a Potion of Cure Light Wounds" in l for l in s1), "inventory lists the pack")
s2 = command("e", capture=True)
print("  'e' screen:", [l.strip() for l in s2[1:5]])
expect(any("Broadsword (2d5)" in l for l in s2) and any("Chain Mail (-2) [14,+0]" in l for l in s2), "equipment lists weapon and armour")
# ---- take off and wear
command("t", "b"); print("  't' b ->", msgline(), player()["ac"])
expect(player()["ac"] == max(0, sac) and player()["tohit"] == shit and any("Chain Mail" in x for x in show_pack()), "taking off the Chain Mail drops its AC and puts it in the pack")
slot = [i for i, r in enumerate(pack()) if r and KINDS[r["kind"]] == "Chain Mail"][0]
command("w", chr(97 + slot)); print("  'w' ->", msgline())
expect(player()["ac"] == max(0, 14 + sac) and show_equip()[1] == "Chain Mail" and "You are wearing Chain Mail (-2) [14,+0]." in msgline(), "wearing it again")
# ---- quaff
w16("P_CHP", 3); before = player()["chp"]
command("q", "b"); after = player()["chp"]; print("  'q' b ->", msgline(), before, "->", after)
expect(5 <= after <= 17 and "no more Potions of Cure Light Wounds" in msgline() and not any("Cure Light" in x for x in show_pack()), "Cure Light Wounds heals 2d7 and is used up")
command("q", "a"); print("  'q' with no potions ->", msgline())
expect("not carrying any potions" in msgline(), "no potions message")
# ---- eat
w16("P_FOOD", 1500); wr(A["P_HUNGER"], bytes([1]))
command("E", "a"); print("  'E' a ->", repr(msgline()), player()["food"], player()["hunger"])
expect(player()["food"] in (6498, 6500) and player()["hunger"] == 0 and not any("Ration" in x for x in show_pack()), "a ration adds 5000 food and ends hunger")
# ---- walk onto items: pick up
from collections import deque
def path_to(goal):
    m, px, py, vx, vy = state()
    prev = {(py, px): None}; q = deque([(py, px)])
    while q:
        c = q.popleft()
        if c == goal:
            out = []
            while prev[c]: out.append(c); c = prev[c]
            return out[::-1]
        for dy in (-1,0,1):
            for dx in (-1,0,1):
                n2 = (c[0]+dy, c[1]+dx)
                if n2 not in prev and T(m[n2[0]*W+n2[1]]) in PASSABLE | {5}:
                    prev[n2] = c; q.append(n2)
w16("P_CHP", 3000); w16("P_MHP", 3000)
picked = []
for want in ("gold", "object", "object"):
    m, px, py, vx, vy = state()
    fl = floor()
    cands = [r for r in fl if (r["kind"] == 0xFE) == (want == "gold")]
    best = None
    for r in sorted(cands, key=lambda r: abs(r["y"]-py) + abs(r["x"]-px)):
        p_ = path_to((r["y"], r["x"]))
        if p_: best = (r, p_); break
    if not best: print("  no reachable", want); continue
    r, p_ = best
    g0 = player()["gold"]; pk0 = show_pack()
    goal = (r["y"], r["x"])
    for step in range(200):
        m2, cx, cy, _, _ = state()
        if (cy, cx) == goal: break
        p2 = path_to(goal)
        if not p2: break
        y, x = p2[0]
        act(0, x - cx, y - cy)
    m, px, py, vx, vy = state()
    print(f"  walked onto {kname(r)} -> {msgline()!r}")
    if want == "gold":
        expect(player()["gold"] == g0 + r["value"] and "gold pieces worth of" in msgline(), f"picked up {r['value']} gold")
    else:
        expect(len(show_pack()) == len(pk0) + 1 or "You have" in msgline(), f"picked up the {kname(r)}")
    expect((py, px) not in [(f["y"], f["x"]) for f in floor()], "it's gone from the floor")
print("  pack now:", show_pack())
# ---- drop and pick up again
n0 = len(show_pack())
command("d", "a"); print("  'd' a ->", msgline())
m, px, py, vx, vy = state()
here = [f for f in floor() if (f["y"], f["x"]) == (py, px)]
expect(here and here[0]["marked"] == 1, "dropped item lies at the player's feet")
command("g"); print("  'g' ->", msgline())
expect(len(show_pack()) == n0 and not [f for f in floor() if (f["y"], f["x"]) == (py, px)], "'g' picks it back up")
# ---- wield a found weapon if we have one
weapons = [i for i, r in enumerate(pack()) if r and KCLASS[r["kind"]] == 7 and KINDS[r["kind"]] != "Broadsword"]
if weapons:
    i = weapons[0]; k = pack()[i]["kind"]
    command("w", chr(97 + i)); p = player(); print("  wield ->", msgline(), p["dice"], p["blows"], p["tohit"])
    expect(show_equip()[0] == KINDS[k] and any("Broadsword" in x for x in show_pack()), f"wielding the {KINDS[k]}, Broadsword back in the pack")
# ---- hunger
w16("P_FOOD", 2004); wr(A["P_HUNGER"], bytes([0])); w16("P_CHP", 3000)
for t in range(4): act(3)
print("  at food < 2000:", repr(msgline()), "status:", screen()[31][:60].rstrip())
expect(player()["hunger"] == 1 and "Hungry" in screen()[31], "hungry message and status")
w16("P_FOOD", 1003)
for t in range(3): act(3)
expect(player()["hunger"] == 2 and "Weak" in screen()[31], "weak from hunger")
# starvation: let food run out with low hp
w16("P_FOOD", -200); w16("P_CHP", 5); w16("P_MHP", 19)
captured_t = None
for t in range(30):
    act(3)
    if player()["dead"]:
        break
dead = player()["dead"]
print("  starving:", player())
expect(dead == 1, "starvation kills")
cmd(2)
print("ALL OK" if ok else "FAILURES")
