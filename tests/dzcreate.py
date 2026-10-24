import sys, random
exec(open("dztest.py").read().split("cmd(1, bytes")[0])
cmd(1, bytes([2, 0, 0]) + b"test\0")
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

wr(A["WAIT_FRESH_KEY"], bytes([0xC9]))
ok = True
def expect(cond, what):
    global ok
    print(("  ok   " if cond else "  FAIL ") + what); ok &= bool(cond)
STATS = ["STR","INT","WIS","DEX","CON","CHR"]
def stat_txt(v): return f"{v}" if v <= 18 else (f"18/{v-18:02d}" if v < 118 else f"18/{v-18}")
def player_state():
    g = lambda n, k=1: rd(A[n], k)
    s8 = lambda n: (lambda v: v - 256 if v > 127 else v)(g(n)[0])
    return dict(race=g("P_RACE")[0], cls=g("P_CLASS")[0], male=g("P_MALE")[0], name=g("P_NAME", 24).split(b"\0")[0].decode(),
                stats=list(g("P_STAT", 6)), hitdie=g("P_HITDIE")[0], bth=g("P_BTH")[0], stl=s8("P_STL"), infra=g("P_INFRA")[0],
                expfact=g("P_EXPFACT")[0], cla=g("P_CLA_BTH")[0], notice=struct.unpack("<H", g("P_NOTICE", 2))[0],
                tohit=s8("P_STAT_TOHIT"), todam=s8("P_STAT_TODAM"), toac=s8("P_STAT_TOAC"), con=s8("P_CON_ADJ"),
                mhp=r16("P_MHP"), gold=struct.unpack("<I", g("P_GOLD", 4))[0], kit=list(g("P_KIT", 5)),
                ac=g("P_AC")[0], ptohit=s8("P_TOHIT"), blows=g("P_BLOWS")[0], age=g("P_AGE")[0], ht=g("P_HT")[0], wt=r16("P_WT"))
# reference versions of the C stat tables
def thr(table, v):
    for lim, val in table:
        if v < lim: return val
DEX_HIT = [(4,-3),(6,-2),(8,-1),(16,0),(17,1),(18,2),(69,3),(118,4),(119,5),(128,6),(138,7),(148,8),(158,9),(168,10),(178,11),(188,12),(198,13),(218,14),(228,15),(256,17)]
STR_HIT = [(4,-3),(5,-2),(7,-1),(18,0),(94,1),(109,2),(117,3),(119,4),(128,5),(138,6),(148,7),(158,8),(168,9),(178,10),(188,11),(198,12),(218,13),(228,14),(256,16)]
STR_DAM = [(4,-2),(5,-1),(16,0),(17,1),(18,2),(94,3),(109,4),(119,5),(128,6),(138,7),(148,8),(158,9),(168,10),(178,11),(188,12),(198,13),(218,14),(228,16),(256,20)]
DEX_AC = [(4,-4),(5,-3),(6,-2),(7,-1),(15,0),(18,1),(59,2),(94,3),(117,4),(119,5),(128,6),(138,7),(148,8),(158,9),(168,10),(178,11),(188,12),(198,13),(218,14),(228,15),(256,17)]
CON_HP = [(4,-4),(5,-3),(6,-2),(7,-1),(17,0),(18,1),(94,2),(117,3),(119,4),(128,5),(138,6),(158,7),(168,8),(178,9),(188,10),(198,11),(208,12),(228,13),(256,14)]
def check_character(label, race, cls, male, name, race_hd, cls_hd, bth, stl, infra, expfact, kit_names):
    p = player_state()
    print(f"{label}: {p['name']} race {p['race']} class {p['cls']} {'male' if p['male'] else 'female'}  stats " +
          " ".join(f"{n} {stat_txt(v)}" for n, v in zip(STATS, p["stats"])) + f"  age {p['age']} ht {p['ht']} wt {p['wt']}  gold {p['gold']}")
    expect((p["race"], p["cls"], p["male"], p["name"]) == (race, cls, male, name), "race, class, sex and name as chosen")
    expect(all(3 <= v <= 118 for v in p["stats"]), "stats within 3 .. 18/100")
    expect(p["hitdie"] == race_hd + cls_hd and p["bth"] == bth and p["stl"] == stl and p["infra"] == infra and p["expfact"] == expfact,
           f"hit die {p['hitdie']}, to-hit {p['bth']}, stealth {p['stl']}, infra {p['infra']}, exp {p['expfact']}%")
    s = p["stats"]
    expect(p["tohit"] == thr(DEX_HIT, s[3]) + thr(STR_HIT, s[0]) and p["todam"] == thr(STR_DAM, s[0]) and
           p["toac"] == thr(DEX_AC, s[3]) and p["con"] == thr(CON_HP, s[4]),
           f"stat bonuses match MISC2.C (to-hit {p['tohit']:+}, to-dam {p['todam']:+}, AC {p['toac']:+}, hp/level {p['con']:+})")
    hp = [struct.unpack("<H", rd(A["P_HP_TABLE"] + 2*i, 2))[0] for i in range(50)]
    hd = p["hitdie"]
    expect(hp[0] == hd and all(1 <= hp[i] - hp[i-1] <= hd for i in range(1, 50)) and
           150*(hd-1)//8 + 50 <= hp[49] <= 250*(hd-1)//8 + 50, f"hit point table rolled within bounds (level 50: {hp[49]})")
    ex = [struct.unpack("<I", rd(A["P_EXP_TABLE"] + 4*i, 4))[0] for i in range(50)]
    base = [10,25,45,70,100,140,200,280,380,500]
    expect(ex[:10] == [b * expfact // 100 for b in base], f"experience table scaled by {expfact}% ({ex[:4]}...)")
    expect(p["mhp"] == max(hd + p["con"], 2), f"level 1 hit points {p['mhp']} = hit die + CON adjustment")
    names = [KINDS[r["kind"]] for r in pack() + equip() if r]
    expect(sorted(names) == sorted(kit_names), f"kit: {names}")
    return p
# a human male warrior called Bob, rerolled twice
install_keys("ama  \rBob\r")
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
check_character("Human warrior", 0, 0, 1, "Bob", 10, 9, 70, 1, 0, 100, ["Ration of Food", "Wooden Torch", "Potion of Berserk Strength", "Broadsword", "Chain Mail"])
p = player_state()
expect(p["ac"] == max(0, 14 + p["toac"]) and p["ptohit"] == -2 + p["tohit"], f"AC {p['ac']} and to-hit {p['ptohit']} include stats and Chain Mail")
# the character sheet
wr(A["ASCII_KEY"], b" ")
install_keys(" ")
set_reg(3, 0); set_reg(4, 12 << 8); set_pc(A["DISPATCH"])
run_to(A["READ_ASCII"]); sheet = screen(); run_to(BP)
print("  'C' sheet:"); [print("   |" + r.rstrip()) for r in sheet if r.strip()]
expect(any("Name   : Bob" in r for r in sheet) and any("Title  : Rookie" in r for r in sheet) and any("Blows" in r for r in sheet), "sheet shows name, title and combat numbers")
# a female dwarf priest: dwarves may be warriors (a) or priests (b)
install_keys("ffb\rDis\r")
w16("P_CHP", -5); wr(A["P_DEAD"], bytes([1]))
set_pc(A["MAIN_LOOP"]); run_to(BP); run_to(BP)
check_character("Dwarf priest", 5, 2, 0, "Dis", 11, 2, 15 + 48, -1 + 2, 5, 120 + 20, ["Ration of Food", "Wooden Torch", "[Beginners Handbook]", "Potion of Healing", "Mace"])
cmd(2)
print("ALL OK" if ok else "FAILURES")
