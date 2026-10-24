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

STORE_INV, STORE_OWNER, STORE_COUNT, STORE_DOOR = A["STORE_INV"], A["STORE_OWNER"], A["STORE_OWNER"] + 8, A["STORE_DOOR"]
PAGE_STORE = 51
STORES = ["General Store", "Armoury", "Weaponsmith", "Temple", "Alchemist", "Magic shop", "Black market", "Home"]
G = _os.path.join(_GAME, "data")
def owners():
    out = []
    lines = open(_os.path.join(G, "stores.asm")).read().split("\n")
    i = lines.index("owner_table:") + 1
    while lines[i].startswith("\tdw own_"):
        purse = int(lines[i+1].split()[1]); v = [int(x) for x in lines[i+2].split()[1].split(",")]
        out.append(dict(purse=purse, max_inf=v[0], min_inf=v[1], race=v[3])); i += 3
    names = [l.split('"')[1] for l in lines if l.startswith("own_")]
    for o, n in zip(out, names): o["name"] = n
    rg_i = lines.index("rgold_table:") + 1
    rg = [[int(x) for x in lines[rg_i + r].split()[1].split(",")] for r in range(10)]
    ch_i = lines.index("store_choice_table:") + 1
    ch = [[int(x) for x in lines[ch_i + r].split()[1].split(",")] for r in range(6)]
    return out, rg, ch
OWN, RG, CHOICE = owners()
KCOST = [k["raw"][16] | k["raw"][17] << 8 for k in KIND_RECS]
KTVAL = [k["raw"][15] for k in KIND_RECS]
def chr_adj(c):
    for lim, v in [(4,130),(5,125),(6,122),(7,120),(8,118),(9,116),(10,114),(11,112),(12,110),(13,108),(14,106),(15,104),(16,103),(17,102),(18,101),(19,100),(68,98),(88,96),(108,94),(118,92),(148,90),(188,88),(218,86),(256,80)]:
        if c < lim: return v
def buy_price(store, kind, disc, prace, chr_, pval=0, e=None):
    c = KCOST[kind]
    if disc: c = max(1, c * {1: 75, 2: 50, 3: 25, 4: 10}[disc] // 100)
    cls = KIND_RECS[kind]["raw"][2]
    if cls in (4, 5): c += (c // 20) * pval				# charges (item_value)
    if e and cls >= 7:									# weapons, armour: pluses
        if cls == 7: c = 0 if min(e["tohit"], e["todam"], e["toac"]) < 0 else c + (e["tohit"] + e["todam"] + e["toac"]) * 100
        else: c = 0 if e["toac"] < 0 else c + e["toac"] * 100
    if c == 0: return 0
    o = OWN[rd(STORE_OWNER + store, 1)[0]]
    v = max(1, c * RG[o["race"]][prace] // 100)
    v = v * o["min_inf"] // 100
    if store == 6: v *= 2
    return max(1, v * chr_ // 100)
def sell_offer(store, kind, prace, chr_, value=None):
    c = KCOST[kind] if value is None else value
    if c == 0: return 0
    o = OWN[rd(STORE_OWNER + store, 1)[0]]
    c = c * (200 - chr_) // 100
    c = max(1, c * (200 - RG[o["race"]][prace]) // 100)
    max_buy = max(1, c * (200 - o["max_inf"]) // 100)
    min_buy = max(max_buy, max(1, c * (200 - o["min_inf"]) // 100))
    return min(min_buy, o["purse"])
def stock(store):
    n = rd(STORE_COUNT + store, 1)[0]
    old = cmd(11, bytes([0x52]))[0]				# the stock lives in the store overlay
    cmd(10, bytes([2, PAGE_STORE])); raw = rd(STORE_INV + store * 264, 264); cmd(10, bytes([2, old]))
    sg = lambda v: v - 256 if v > 127 else v
    return [dict(kind=raw[i*11] | raw[i*11+1] << 8, num=raw[i*11+2], disc=raw[i*11+3], pval=raw[i*11+4] | raw[i*11+10] << 8, tohit=sg(raw[i*11+5]), todam=sg(raw[i*11+6]), toac=sg(raw[i*11+7]), name2=raw[i*11+8], ident=raw[i*11+9]) for i in range(n)]
def door(store):
    y, x = rd(STORE_DOOR + 2 * store, 2); return y, x
# ---- a new character starts in town
install_keys("ama\rTest\r")
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
p = player_state()
m = rd(0xC000, W * H)
expect(rd(A["DUN_LEVEL"], 1)[0] == 0, "starts in the town")
print("  screen:"); [print("   |" + r.rstrip()) for r in screen()[:23] if r.strip()]
print("  status:", screen()[31].rstrip())
expect("Town" in screen()[31], "status line says Town")
doors = [door(sn) for sn in range(8)]
expect(all(T(m[y*W+x]) == 15 and 0 < y < 21 and 0 < x < 65 for y, x in doors) and len(set(doors)) == 8, f"eight store doors: {doors}")
expect(all(T(m[y*W+x]) in (4, 15, 1, 8) for y in range(22) for x in range(66)) and all(T(b) == 4 for i, b in enumerate(m) if i // W >= 22 or i % W >= 66),
       "town is floor, store walls, doors and stairs inside a permanent wall")
expect(sum(1 for y in range(22) for x in range(66) if T(m[y*W+x]) == 8) == 1, "one down staircase")
expect(all(m[y*W+x] & 0x20 for y in range(22) for x in range(66)), "daytime: the whole town is lit")
scr = screen()
expect(all(scr[y - 0 + 1][x] == str(sn + 1) for sn, (y, x) in enumerate(doors)), "doors drawn as 1-8")
ms = mons()
uniq = any(RACES[k["race"]]["raw"][13] & 1 for k in ms)	# a unique picked twice is placed once
expect((len(ms) == 4 or (uniq and len(ms) >= 2)) and all(RACES[k["race"]]["level"] == 0 for k in ms), f"4 townsfolk by day: {[NAMES[k['race']] for k in ms]}")
for sn in range(8):
    st = stock(sn)
    print(f"  {STORES[sn]:13} ({OWN[rd(STORE_OWNER+sn,1)[0]]['name'].split('  ')[0]}): " + ", ".join(f"{e['num']} {KINDS[e['kind']]}" + (f" (-{e['disc']})" if e['disc'] else "") for e in st))
expect(all(sum(e["num"] for e in stock(sn)) >= 10 for sn in (0, 1, 2, 6)) and len(stock(7)) == 0, "shops stocked with 10+ items (stacked), home empty")
expect(all(all(e["kind"] in CHOICE[sn] for e in stock(sn)) for sn in range(6)), "stock comes from each store's choice list")
expect(all([KTVAL[e["kind"]] for e in stock(sn)] == sorted([KTVAL[e["kind"]] for e in stock(sn)], reverse=True) for sn in range(8)), "stock kept in tval order")
# ---- walk into the general store and buy the first item, then sell the ration back
def enter(store, keys):
    install_keys(keys)
    y, x = doors[store]
    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)):
        if T(m[(y+dy)*W + x+dx]) == 1:
            wr(A["PLAYER_Y"], bytes([y+dy])); wr(A["PLAYER_X"], bytes([x+dx])); break
    set_reg(3, ((-dx & 255) << 8) | (-dy & 255)); set_reg(4, 0); set_pc(A["DISPATCH"])
    run_to(A["READ_ASCII"]); first = screen(); run_to(BP); return first
chr_ = chr_adj(p["stats"][5]); prace = p["race"]
g0 = player_state()["gold"]; first = stock(0)[0]
price = buy_price(0, first["kind"], first["disc"], prace, chr_, first["pval"], first)
shot = enter(0, "pa ")
print("  in the general store:"); [print("   |" + r.rstrip()) for r in shot if r.strip()]
g1 = player_state()["gold"]
expect(g0 - g1 == price, f"bought a {KINDS[first['kind']]} for {g0 - g1} gold (expected {price})")
expect(any(KINDS[r["kind"]] == KINDS[first["kind"]] for r in pack() if r), "it's in the pack")
expect(any(str(price) in r for r in shot), "price shown matches")
# sell the ration (slot a) to the general store
ration_offer = sell_offer(0, [r for r in pack() if r][0]["kind"], prace, chr_)
g1 = player_state()["gold"]
shot = enter(0, "sa ")
g2 = player_state()["gold"]
expect(g2 - g1 == ration_offer, f"sold the ration for {g2 - g1} gold (expected {ration_offer})")
# the home: drop the broadsword? it's wielded; drop pack slot a there, then get it back
before = [KINDS[r["kind"]] for r in pack() if r]
shot7 = enter(7, "da ")
print("  home:", before, [r.rstrip() for r in shot7 if r.strip()][:12], "| after:", [r.rstrip() for r in screen() if r.strip()][:3], [KINDS[r["kind"]] for r in pack() if r])
expect(len(stock(7)) == 1 and len([r for r in pack() if r]) < len(before) or before[0] in [KINDS[e["kind"]] for e in stock(7)], f"dropped {before[0]} at home: {[KINDS[e['kind']] for e in stock(7)]}")
enter(7, "ga ")
expect(len(stock(7)) == 0 and sorted(KINDS[r["kind"]] for r in pack() if r) == sorted(before), "got it back")
# an unknown potion sold to the temple: valued at 20, and identified by the sale
CSW = [i for i, k in enumerate(KIND_RECS) if k["name"] == "Potion of Cure Serious Wounds"][0]
wr(A["PACK"], bytes([CSW & 255, CSW >> 8, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]))
oi = A["OBJECT_IDENT"] + 5*64 + KIND_RECS[CSW]["raw"][22]
wr(oi, bytes([0]))
offer = sell_offer(3, CSW, prace, chr_, value=20)
g1 = player_state()["gold"]
enter(3, "sa ")
g2 = player_state()["gold"]
print("  sold an unknown potion to the temple:", g2 - g1, "gold (offer on 20:", offer, ") ident", rd(oi, 1)[0])
expect(g2 - g1 == offer and rd(oi, 1)[0] & 2 and pack()[0] and pack()[0]["num"] == 1, "an unknown potion sells as worth 20 and becomes known")
# a store that buys nothing of ours: the weaponsmith won't take food
p_items = [KINDS[r["kind"]] for r in pack() if r]
shot = enter(2, "s ")
print("  weaponsmith sell attempt ->", [r.strip() for r in screen()[26:30] if r.strip()], "pack", p_items)
def act(cmdno, dx=0, dy=0):
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
# ---- down and back up: same town, restocked
s0 = [stock(sn) for sn in range(7)]
y, x = [(i // W, i % W) for i, b in enumerate(rd(0xC000, W*H)) if T(b) == 8][0]
wr(A["PLAYER_Y"], bytes([y])); wr(A["PLAYER_X"], bytes([x])); act(1)
expect(rd(A["DUN_LEVEL"], 1)[0] == 1, "down to 50 ft")
m1 = bytes(b & 15 for b in rd(0xC000, W*H)); i = m1.index(9)
wr(A["PLAYER_Y"], bytes([i // W])); wr(A["PLAYER_X"], bytes([i % W])); act(2)
expect(rd(A["DUN_LEVEL"], 1)[0] == 0 and [door(sn) for sn in range(8)] == doors, "back up: the same town")
expect([stock(sn) for sn in range(7)] != s0, "and the stores have restocked")
cmd(2)
print("ALL OK" if ok else "FAILURES")
