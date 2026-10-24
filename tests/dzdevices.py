import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
def kind(name): return KIDX[name]
FLV = lambda k: KIND_RECS[k]["raw"][22]
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
OI = lambda ofs, k: A["OBJECT_IDENT"] + ofs*64 + FLV(k)
def put(slot, k, n=1, store=0, pval=0, hit=0, dam=0, ac=0): wr(A["PACK"] + 14*slot, bytes([k & 255, k >> 8, n, 0, 0, 1, pval, 0, store, hit & 255, dam & 255, ac & 255, 0, 0]))
def clear_pack():
    for i in range(12): wr(A["PACK"] + 14*i, bytes([0, 255] + [0]*12))
def slot(i):
    r = rd(A["PACK"] + 14*i, 14); return dict(kind=r[0] | r[1] << 8, num=r[2], pval=r[6], timeout=r[6] | r[7] << 8, ident=r[8])
def keyed(cmdno, keys, capture=False, retry=True):
    for _ in range(5):						# (a sure hand still fails 1 in 50)
        shot = keyed1(cmdno, keys, capture)
        if not retry or "failed to use" not in screen()[0]: return shot
    return shot
def keyed1(cmdno, keys, capture=False):
    install_keys(keys)
    set_reg(3, 0); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"])
    shot = None
    if capture:
        run_to(A["READ_ASCII"]); shot = screen()
    run_to(BP)
    return shot
AIM, USE, ZAP, READ, INV = 14, 15, 16, 13, 4
def tick(n=1):
    for _ in range(n): act(3)
def pos(): return rd(A["PLAYER_Y"], 1)[0], rd(A["PLAYER_X"], 1)[0]
def sq(y, x): return rd(0xC000 + y*W + x, 1)[0]
def setsq(y, x, v): wr(0xC000 + y*W + x, bytes([v]))
def calm():
    for i in range(64):
        b = 0xB000 + 16*i
        if rd(b + 12, 1)[0] != 255:
            y, x = rd(b + 1, 2); setsq(y, x, sq(y, x) & 0x7F); wr(b + 12, bytes([255]))
def place(race, y, x, hp=200, sleep=0):
    for i in range(64):
        b = 0xB000 + 16*i
        if rd(b + 12, 1)[0] == 255:
            sp = RACES[race]["raw"][8] - 10
            wr(b, bytes([race & 255, y, x, hp & 255, hp >> 8, hp & 255, hp >> 8, sleep & 255, sleep >> 8, sp & 255, 3, 1, race >> 8, 0, 0, 0]))
            setsq(y, x, sq(y, x) | 0x80); return b
def mon(b):
    r = rd(b, 16); return dict(race=r[0] | r[12] << 8, y=r[1], x=r[2], hp=r[3] | r[4] << 8, sleep=r[7] | r[8] << 8, speed=r[9] - 256 if r[9] > 127 else r[9], conf=r[13], alive=r[12] != 255)
def race(name): return next(i for i, r in enumerate(RACES) if r["name"] == name)
def heal(): w16("P_CHP", 500); w16("P_MHP", 500)
wr(A["P_RACE"], bytes([0])); wr(A["P_SAVE"], bytes([100]))	# a sure hand with devices
calm(); heal()
# a clear corridor eastward: walls above and below, floor for 12
y0, x0 = pos()
if x0 > 180: x0 = 100
for dx in range(-1, 14):
    setsq(y0 - 1, x0 + dx, 0x23); setsq(y0 + 1, x0 + dx, 0x23)
    setsq(y0, x0 + dx, 0x22)
setsq(y0, x0 + 14, 0x23)
wr(A["PLAYER_Y"], bytes([y0])); wr(A["PLAYER_X"], bytes([x0]))
for f in range(64):						# nothing on the floor there
    b = 0xB400 + 14*f
    if rd(b + 1, 1)[0] != 255 and rd(b + 3, 1)[0] in (y0 - 1, y0, y0 + 1): wr(b + 1, b"\xff")
tick()
LIZ = race("Rock lizard")

# ---- names
mm = kind("Wand of Magic Missile")
clear_pack(); put(0, mm, pval=5)
shot = keyed(INV, " ", capture=True)
line = next((l.strip() for l in shot if l.strip().startswith("a)")), "")
print("  unknown wand:", repr(line))
expect(re.fullmatch(r"a\) an? [A-Z][A-Za-z-]+ Wand", line), "an unknown wand goes by its metal")
# ---- the prompts (they printed garbage from 9b to 13b)
put(1, next(i for i, r in enumerate(KIND_RECS) if r["raw"][2] == 5)); put(2, next(i for i, r in enumerate(KIND_RECS) if r["raw"][2] == 6))
for cmdno, want in ((AIM, "Aim which wand?"), (USE, "Use which staff?"), (ZAP, "Activate which rod?")):
    shot = keyed1(cmdno, " ", capture=True)
    print("  prompt:", repr(shot[0].strip()))
    expect(shot[0].strip().startswith(want), f"'{want} (letter, or space)'")
clear_pack(); put(0, mm, pval=5)
# ---- magic missile: identified by use, a charge gone
b = place(LIZ, y0, x0 + 4)
keyed(AIM, "a6")
m = mon(b); s0 = slot(0)
print("  magic missile:", repr(msgline()), "lizard hp", m["hp"], "charges", s0["pval"])
expect(198 >= m["hp"] >= 188 and s0["pval"] == 4 and rd(OI(3, mm), 1)[0] & 2, "Magic Missile: 2d6 to the lizard, 4 charges left, the wand is known")
shot = keyed(INV, " ", capture=True)
line = next((l.strip() for l in shot if l.strip().startswith("a)")), "")
expect(line == "a) a Wand of Magic Missile", f"now it's {line!r} (charges unknown until identified)")
# ---- store bought: charges shown
calm(); clear_pack(); put(0, mm, store=5, pval=7)
shot = keyed(INV, " ", capture=True)
line = next((l.strip() for l in shot if l.strip().startswith("a)")), "")
expect(line == "a) a Wand of Magic Missile (7 charges)", f"known charges: {line!r}")
keyed(AIM, "a6")
print("  store wand ->", repr(msgline()))
expect("You have 6 charges remaining." in screen()[0], "'You have 6 charges remaining.'")
# ---- empty
clear_pack(); put(0, mm, pval=0)
keyed(AIM, "a6")
shot = keyed(INV, " ", capture=True)
line = next((l.strip() for l in shot if l.strip().startswith("a)")), "")
print("  empty:", repr(line))
expect(line.endswith("{empty}"), "an empty wand is marked {empty}")
# ---- cancelling the direction takes no turn
clear_pack(); put(0, mm, pval=3); t0 = struct.unpack("<H", rd(A["GAME_TURN"], 2))[0]
keyed(AIM, "a ")
expect(slot(0)["pval"] == 3 and struct.unpack("<H", rd(A["GAME_TURN"], 2))[0] == t0, "no direction: no charge used, no turn")
# ---- failure
wr(A["P_SAVE"], bytes([256 - 100]))
keyed(AIM, "a6", retry=False)
expect("failed to use the wand properly" in screen()[0], "a poor hand: 'You failed to use the wand properly.'")
wr(A["P_SAVE"], bytes([100]))
# ---- monster effects
for name, test, what in (("Wand of Slow Monster", lambda m: m["speed"] == RACES[LIZ]["raw"][8] - 11, "slower"),
                         ("Wand of Haste Monster", lambda m: m["speed"] == RACES[LIZ]["raw"][8] - 9, "faster"),
                         ("Wand of Sleep Monster", lambda m: m["sleep"] > 400, "asleep"),
                         ("Wand of Confuse Monster", lambda m: m["conf"] == 1, "confused")):
    calm(); b = place(LIZ, y0, x0 + 3)
    clear_pack(); put(0, kind(name), pval=5); keyed(AIM, "a6")
    print(f"  {name}: {msgline()!r}", mon(b), pos(), (y0, x0))
    expect(test(mon(b)), f"{name}: the lizard is {what}")
calm(); b = place(LIZ, y0, x0 + 3)
clear_pack(); put(0, kind("Wand of Teleport Away"), pval=5); keyed(AIM, "a6")
m = mon(b)
expect(abs(m["x"] - (x0 + 3)) + abs(m["y"] - y0) > 5, f"Teleport Away: the lizard is now at {m['y']},{m['x']}")
calm(); b = place(LIZ, y0, x0 + 3)
n0 = sum(1 for i in range(64) if rd(0xB000 + 16*i + 12, 1)[0] != 255)
clear_pack(); put(0, kind("Wand of Clone Monster"), pval=5); keyed(AIM, "a6")
n1 = sum(1 for i in range(64) if rd(0xB000 + 16*i + 12, 1)[0] != 255)
expect(n1 == n0 + 1, "Clone Monster: another lizard")
calm()
b = place(race("Poltergeist"), y0, x0 + 3)
clear_pack(); put(0, kind("Wand of Drain Life"), pval=5); keyed(AIM, "a6")
expect(mon(b)["hp"] == 200, "Drain Life does nothing to the undead")
calm(); b = place(LIZ, y0, x0 + 3, hp=300)
clear_pack(); put(0, kind("Wand of Drain Life"), pval=5); keyed(AIM, "a6")
expect(mon(b)["hp"] == 225, "Drain Life: 75 from the living")
# ---- stone to mud
calm()
setsq(y0, x0 + 6, 0x23)
clear_pack(); put(0, kind("Wand of Stone to Mud"), pval=5); keyed(AIM, "a6")
print("  stone to mud ->", repr(msgline()), hex(sq(y0, x0 + 6)), pos(), (y0, x0))
expect(T(sq(y0, x0 + 6)) in (1, 2), "Stone to Mud: the wall is gone")
setsq(y0, x0 + 14, 0x23)
# ---- fire ball: burns a potion beside the target
calm(); b = place(LIZ, y0, x0 + 5)
pot = KIDX["Potion of Cure Light Wounds"]
fs = next(f for f in range(64) if rd(0xB400 + 14*f + 1, 1)[0] == 255)
wr(0xB400 + 14*fs, bytes([pot & 255, pot >> 8, 1, y0, x0 + 6, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
clear_pack(); put(0, kind("Wand of Fire Balls"), pval=5); keyed(AIM, "a6")
m = mon(b); print("  fire ball:", repr(msgline()), "lizard", m)
expect(not m["alive"] or m["hp"] <= 200 - 72 // 1 + 0, "Fire Ball: the lizard takes 72")
expect(rd(0xB400 + 14*fs + 1, 1)[0] == 255, "and the potion next to it boils away")
# ---- staffs
calm(); heal()
clear_pack(); put(0, kind("Staff of Speed"), pval=5); keyed(USE, "a"); tick()
expect(r8("P_SPEED") == -1, "Staff of Speed: fast")
w16("P_FAST", 1); tick()
w16("P_CHP", 1)
clear_pack(); put(0, kind("Staff of Cure Light Wounds"), pval=5); keyed(USE, "a")
print("  cure light ->", repr(msgline()), r16("P_CHP"), r16("P_MHP"))
expect(2 <= r16("P_CHP") <= 9, "Staff of Cure Light Wounds: 1d8")
y1, x1 = pos()
clear_pack(); put(0, kind("Staff of Teleportation"), pval=5); keyed(USE, "a")
expect(pos() != (y1, x1), "Staff of Teleportation moves you")
calm(); y1, x1 = pos()
for _ in range(4):							# (needs room next to you)
    clear_pack(); put(0, kind("Staff of Summoning"), pval=5); keyed(USE, "a")
    if any(rd(0xB000 + 16*i + 12, 1)[0] != 255 for i in range(64)): break
expect(any(rd(0xB000 + 16*i + 12, 1)[0] != 255 for i in range(64)), "Staff of Summoning brings company")
calm()
clear_pack(); put(0, kind("Staff of Light"), pval=5); keyed(USE, "a")
y1, x1 = pos()
expect(all(sq(y1+a, x1+c) & 0x20 for a in (-1,0,1) for c in (-1,0,1)), "Staff of Light lights around you")
# ---- rods
calm()
wr(A["PLAYER_Y"], bytes([y0])); wr(A["PLAYER_X"], bytes([x0])); tick()
clear_pack(); put(0, kind("Rod of Light"))
keyed(ZAP, "a6")
print("  rod of light:", repr(msgline()), slot(0))
expect(slot(0)["timeout"] == 8 and all(sq(y0, x0 + d) & 0x20 for d in range(0, 6)), "Rod of Light: a lit line, then 9 turns to recharge (8 after this turn)")
tick(2)
expect(slot(0)["timeout"] == 6, "rods recharge a turn at a time")
keyed(ZAP, "a6")
expect("currently exhausted" in screen()[0], "'The rod is currently exhausted.'")
w16("P_CHP", 1)
clear_pack(); put(0, kind("Rod of Healing"))
keyed(ZAP, "a")
expect(r16("P_CHP") == r16("P_MHP") and slot(0)["timeout"] == 887, "Rod of Healing: 500 hp, 888 turns")
# ---- recharging
rec = KIDX["Scroll of Recharging"]
clear_pack(); put(0, rec, store=1); put(1, mm, pval=1)
keyed(READ, "ab")
s1 = slot(0)
print("  recharge ->", repr(msgline()), s1)
expect((s1["kind"] == mm and s1["pval"] > 1) or s1["kind"] == 0xFF00, "Recharging adds charges (or the wand blows up)")
cmd(2)
print("ALL OK" if ok else "FAILURES")
