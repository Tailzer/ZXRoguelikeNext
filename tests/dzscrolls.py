import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
def scroll(name): return KIDX["Scroll of " + name]
def potion(name): return KIDX["Potion of " + name]
FLV = lambda k: KIND_RECS[k]["raw"][22]
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
OIS = A["OBJECT_IDENT"] + 4*64
OIP = A["OBJECT_IDENT"] + 5*64
def sident(k): return rd(OIS + FLV(k), 1)[0]
def pident(k): return rd(OIP + FLV(k), 1)[0]
def put(slot, k, n=1, store=0, pval=0, hit=0, dam=0, ac=0): wr(A["PACK"] + 14*slot, bytes([k & 255, k >> 8, n, 0, 0, 1, pval, 0, store, hit & 255, dam & 255, ac & 255, 0, 0]))
def clear_pack():
    for i in range(12): wr(A["PACK"] + 14*i, bytes([0, 255] + [0]*12))
def keyed(c, keys, capture=False):
    install_keys(keys)
    set_reg(3, 0); set_reg(4, CMDS[c] << 8); set_pc(A["DISPATCH"])
    shot = None
    if capture:
        run_to(A["READ_ASCII"]); shot = screen()
    run_to(BP)
    return shot
CMDS["r"] = 13
def read(k, keys="a", store=0, extra=()):
    clear_pack(); put(0, k, 1, store)
    for i, (kk, st) in enumerate(extra): put(1 + i, kk, 1, st)
    keyed("r", keys); return msgline()
def tick(n=1):
    for _ in range(n): act(3)
def mons_(): return mons()
def heal(): w16("P_CHP", 500); w16("P_MHP", 500)
def status(): return screen()[31]
def pos(): return rd(A["PLAYER_Y"], 1)[0], rd(A["PLAYER_X"], 1)[0]
def sq(y, x): return rd(0xC000 + y*W + x, 1)[0]
def exp(): return struct.unpack("<I", rd(A["P_EXP"], 4))[0]
wr(A["P_RACE"], bytes([0]))
heal()
def calm():
    for i in range(64):
        b = 0xB000 + 16*i
        if rd(b + 12, 1)[0] != 255:
            y, x = rd(b + 1, 2); wr(0xC000 + y*198 + x, bytes([rd(0xC000 + y*198 + x, 1)[0] & 0x7F])); wr(b + 12, bytes([255]))
calm()

# ---- titles and names
idn = scroll("Identify")
clear_pack(); put(0, idn); put(1, scroll("Light"), 3)
shot = keyed("i", " ", capture=True)
lines = [l.strip() for l in shot if l.strip()[:2] in ("a)", "b)")]
print("  unknown scrolls:", lines)
m0 = re.fullmatch(r'a\) a Scroll titled "([a-z ]{1,9})"', lines[0])
m1 = re.fullmatch(r'b\) 3 Scrolls titled "([a-z ]{1,9})"', lines[1])
expect(m0 and m1 and m0.group(1) != m1.group(1) and not m0.group(1).endswith(" "), 'unknown scrolls: a Scroll titled "..." (made-up titles, up to 9 letters)')
# ---- can't read blind or confused
w16("P_BLIND", 5); m = read(idn); w16("P_BLIND", 0)
expect("can't see to read" in m, "blind: 'You can't see to read the scroll.'")
w16("P_CONFUSED", 5); m = read(idn); w16("P_CONFUSED", 0); tick()
expect("too confused to read" in m, "confused: 'You are too confused to read a scroll.'")
# ---- identify: learns a potion, and itself, with experience
spd = potion("Speed")
e0 = exp()
read(idn, keys="ab", extra=[(spd, 0)])
print("  identify ->", repr(msgline()), "exp", e0, "->", exp())
expect(pident(spd) & 2 and sident(idn) & 2 and exp() > e0, "Identify: the Speed potion is known, and so is Identify (with exp)")
expect(not any(r and r["kind"] == idn for r in pack()), "the scroll is used up")
# put back if nothing chosen
read(idn, keys="a ", store=1)
expect(any(r and r["kind"] == idn for r in pack()), "Identify with nothing chosen isn't used up")
# ---- light: the 3x3 around you is lit for good
y, x = pos()
for dy in (-1, 0, 1):
    for dx in (-1, 0, 1): wr(0xC000 + (y+dy)*W + x+dx, bytes([sq(y+dy, x+dx) & ~0x20]))
read(scroll("Light"))
expect(all(sq(y+dy, x+dx) & 0x20 for dy in (-1,0,1) for dx in (-1,0,1)), "Light: the squares around you are lit")
# ---- create food
for f in range(64):
    b = 0xB400 + 14*f
    if rd(b + 1, 1)[0] != 255 and tuple(rd(b + 3, 2)) == pos(): wr(b + 1, b"\xff")
m = read(scroll("Create Food"))
here = [f for f in floor() if (f["y"], f["x"]) == pos()]
print("  create food ->", repr(m), [KINDS[f["kind"]] for f in here])
expect(here and KINDS[here[0]["kind"]] == "Slime Mold", "Create Food: a Slime Mold under you")
m = read(scroll("Create Food"), store=1)
expect(len([f for f in floor() if (f["y"], f["x"]) == pos()]) == 1, "and not another if something's there")
for f in range(64):
    b = 0xB400 + 14*f
    if rd(b + 1, 1)[0] != 255 and tuple(rd(b + 3, 2)) == pos(): wr(b + 1, b"\xff")
# ---- blessing
th0, ac0 = r8("P_TOHIT"), rd(A["P_AC"], 1)[0]
read(scroll("Blessing")); b = r16("P_BLESSED"); tick()
expect(6 <= b <= 18 and r8("P_TOHIT") == th0 + 10 and rd(A["P_AC"], 1)[0] == ac0 + 5, f"Blessing: {b} turns of +10 to-hit, +5 AC")
w16("P_BLESSED", 1); tick()
# ---- protection from evil, monster confusion
lev = rd(A["P_LEV"], 1)[0]
read(scroll("Protection from Evil")); pe = r16("P_PROTEVIL")
expect(3*lev <= pe <= 3*lev + 25, f"Protection from Evil: {pe} turns (1d25 + 3 x level)")
w16("P_PROTEVIL", 0)
m = read(scroll("Monster Confusion"))
print("  monster confusion ->", repr(m), rd(A["P_CONFUSE_MON"], 1)[0])
expect(rd(A["P_CONFUSE_MON"], 1)[0] == 1, "Monster Confusion: your hands glow")
# ---- phase door / teleport
for name, dis in (("Phase Door", 10), ("Teleport", 100)):
    y0, x0 = pos()
    read(scroll(name)); y1, x1 = pos()
    dy, dx = abs(y1-y0), abs(x1-x0); d = ((dy+dx)*2 - min(dy, dx)) >> 1
    expect(d <= dis and T(sq(y1, x1)) in (1, 2, 8, 9, 14), f"{name}: moved {d} squares (at most {dis}) onto open floor")
# ---- magic mapping
read(scroll("Magic Mapping"))
mm = rd(0xC000, W*H)
vy, vx = rd(A["VIEW_Y"], 1)[0], rd(A["VIEW_X"], 1)[0]
walls = [(yy, xx) for yy in range(vy, vy+30) for xx in range(vx, vx+80) if 0 < yy < H-1 and 0 < xx < W-1
         and T(mm[yy*W+xx]) == 3 and any(T(mm[(yy+a)*W+xx+c]) in (1, 2, 14) for a in (-1,0,1) for c in (-1,0,1))]
expect(walls and all(mm[yy*W+xx] & 0x20 for yy, xx in walls), f"Magic Mapping: all {len(walls)} walls beside floor in view are mapped")
# ---- door/stair location: a secret door in view becomes a door
vy, vx = rd(A["VIEW_Y"], 1)[0], rd(A["VIEW_X"], 1)[0]
secret = [(yy, xx) for yy in range(vy, vy+30) for xx in range(vx, vx+80) if T(mm[yy*W+xx]) == 7]
if not secret:
    py_, px_ = pos(); wr(0xC000 + (py_+2)*W + px_, bytes([(sq(py_+2, px_) & 0xF0) | 7])); secret = [(py_+2, px_)]
read(scroll("Door/Stair Location"))
expect(all(T(sq(*s)) == 5 and sq(*s) & 0x20 for s in secret), f"Door/Stair Location: {len(secret)} secret doors in view found")
# ---- treasure / object detection
ms = [f for f in floor() if f["marked"] == 0]
read(scroll("Object Detection"))
vy, vx = rd(A["VIEW_Y"], 1)[0], rd(A["VIEW_X"], 1)[0]
inview = [f for f in floor() if f["kind"] != 0xFE and vy <= f["y"] < vy+30 and vx <= f["x"] < vx+80]
expect(all(f["marked"] for f in inview), f"Object Detection: {len(inview)} objects in view marked")
# ---- aggravate
read(scroll("Aggravate Monster"))
expect(all(k["sleep"] == 0 for k in mons()), "Aggravate Monster: everything wakes")
calm()
# ---- summon monster
n0 = len(mons()); y, x = pos()
for _ in range(5):
    read(scroll("Summon Monster"))
near = [k for k in mons() if abs(k["y"]-y) <= 1 and abs(k["x"]-x) <= 1]
print("  summoned:", len(mons()) - n0, "next to you:", [NAMES[k["race"]] for k in near])
expect(len(mons()) > n0 and near, "Summon Monster: monsters appear beside you")
# ---- genocide one letter, then mass genocide
heal()
ch = RACES[near[0]["race"]]["raw"][0]
keyed("r", "a" + chr(ch)) if False else None
clear_pack(); put(0, scroll("Genocide")); keyed("r", "a" + chr(ch))
left = [k for k in mons() if RACES[k["race"]]["raw"][0] == ch]
print("  genocide left:", [(NAMES[k["race"]], k["y"], k["x"]) for k in left], "hp", r16("P_CHP"), repr(msgline()))
expect(not left and r16("P_CHP") < 500, f"Genocide of '{chr(ch)}': all gone, and it hurt")
heal()
read(scroll("Mass Genocide"))
close = [k for k in mons() if k["cdis"] <= 20 and not RACES[k["race"]]["raw"][13] & 1]
expect(not close, "Mass Genocide: nothing (non-unique) within 20 squares")
# ---- monster confusion on a hit
heal(); y, x = pos()
clear_pack(); put(0, scroll("Summon Monster"))
for _ in range(10):
    keyed("r", "a")
    near = [k for k in mons() if abs(k["y"]-y) <= 1 and abs(k["x"]-x) <= 1]
    if near: break
wr(A["P_CONFUSE_MON"], bytes([1]))
if near:
    k = near[0]
    for _ in range(20):
        act(0, k["x"] - x, k["y"] - y); heal()
        if rd(A["P_CONFUSE_MON"], 1)[0] == 0 or not [q for q in mons() if (q["y"], q["x"]) == (k["y"], k["x"])]: break
    print("  hit while glowing ->", repr(msgline()), "confused flags:", [rd(0xB000 + 16*i + 13, 1)[0] for i in range(64) if rd(0xB000 + 16*i + 12, 1)[0] != 255 and rd(0xB000+16*i+1, 2) == bytes([k["y"], k["x"]])])
    expect(rd(A["P_CONFUSE_MON"], 1)[0] == 0, "glowing hands: the monster hit is confused (or unaffected)")
# ---- dispel undead: an undead placed beside you takes 1d60
calm(); heal()
und = next(i for i, r in enumerate(RACES) if r["raw"][13] & 16 and not r["raw"][13] & 1 and r["level"] < 20)
y, x = pos()
spot = next((y+a, x+c) for a in (-1,0,1) for c in (-1,0,1) if (a or c) and T(sq(y+a, x+c)) in (1, 2, 14))
wr(0xB000, bytes([und & 255, spot[0], spot[1], 200, 0, 200, 0, 0, 0, 0, 1, 1, und >> 8, 0, 0, 0]))
wr(0xC000 + spot[0]*W + spot[1], bytes([sq(*spot) | 0x80]))
read(scroll("Dispel Undead"))
hp = rd(0xB003, 2); hp = hp[0] | hp[1] << 8
print(f"  dispel undead: {NAMES[und]} hp 200 -> {hp}", repr(msgline()))
expect(140 <= hp < 200, "Dispel Undead: 1d60 damage to the undead in sight")
# ---- darkness, *destruction*, recall, teleport level
heal()
read(scroll("Word of Recall")); wrc = r16("P_WORD_RECALL")
expect(25 <= wrc <= 55, f"Word of Recall: fires in {wrc} turns")
lvl = rd(A["DUN_LEVEL"], 1)[0]
w16("P_WORD_RECALL", 2); tick(); tick()
expect(rd(A["DUN_LEVEL"], 1)[0] == 0, "and takes you up to town")
descend(); heal()
read(scroll("Teleport Level"))
expect(rd(A["DUN_LEVEL"], 1)[0] in (0, 2), f"Teleport Level: from 1 to {rd(A['DUN_LEVEL'], 1)[0]}")
if rd(A["DUN_LEVEL"], 1)[0] == 0: descend()
heal()
y, x = pos()
read(scroll("*Destruction*"))
mm = rd(0xC000, W*H)
changed = sum(1 for yy in range(max(1, y-12), min(H-1, y+13)) for xx in range(max(1, x-12), min(W-1, x+13)) if T(mm[yy*W+xx]) in (3, 12, 13))
expect(changed > 50 and r16("P_BLIND") >= 10, f"*Destruction*: {changed} squares turned to rock, and you're blind")
w16("P_BLIND", 1); tick(); tick()
cmd(2)
print("ALL OK" if ok else "FAILURES")
