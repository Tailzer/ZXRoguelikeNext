import sys, re
src = open("dzactivate.py").read()
exec(src.split("# smart enough to activate things")[0])
PAGE_MISC, PAGE_MAGIC, PAGE_SCROLL, PAGE_DEVICE, PAGE_MCAST, PAGE_TRAP = 41, 52, 53, 54, 56, 58
SCR = 0xBDC0 + 0x80
ID_CURSED = 8
EG = re.findall(r"\tdb ([\d,]+)\n\tdw egn_(\d+)\n\tdb ([\d,]+)", EGOS_SRC)
EREC = {int(n): ([int(x) for x in f.split(",")], [int(x) for x in m.split(",")]) for f, n, m in EG}
def rec(addr):
    r = rd(addr, IS)
    return dict(kind=r[0] | r[1] << 8, n=r[2], marked=r[5], ident=r[8], ac=sg(r[11]), ego=r[12])
def eq(i): return rec(EQ + IS*i)
def page(p): cmd(10, bytes([2, p]))
def sq(y, x): return rd(0xC000 + y*W + x, 1)[0]
def set_sq(y, x, t): wr(0xC000 + y*W + x, bytes([(sq(y, x) & 0xF0) | t]))
wr(A["P_STAT_USE"] + 1, bytes([118])); wr(A["P_STAT"] + 1, bytes([118])); wr(A["P_LEV"], bytes([30]))

# ---- the artifacts' data, as 1.3 put it right
gl, ae, bt, tu = (EREC[SN[n]] for n in ("SN_GLAMDRING", "SN_AEGLIN", "SN_BLADETURNER", "SN_TUOR"))
expect(gl[1][6] == 3 and ae[1][6] == 4, f"Glamdring searches and sneaks by 3, Aeglin by 4 (pvals {gl[1][6]}, {ae[1][6]})")
expect(bt[1][5] == 17 and bt[0][5] & 8, f"Bladeturner: [+17] and it activates (to-ac {bt[1][5]})")
expect(tu[0][5] & 1, "Tuor: immune to acid, in the right flags")

# ---- dragon scale mail: Razorback and Bladeturner can be made
MHD, PDS = KIDX["Multi-Hued Dragon Scale Mail"], KIDX["Power Dragon Scale Mail"]
def make(k, level, great=False):
    page(PAGE_MISC); set_reg(5, k); set_reg(2, level << 8); cmd(4, bytes([6]) + struct.pack("<H", SCR))
    if great:
        set_reg(3, 2 << 8); call(A["NEW_GOOD_ITEM"])
    else:
        call(A["NEW_ITEM"])
    return rec(SCR)
wr(A["ART_MADE"], bytes(24))
got = [make(PDS, 60, great=True)["ego"] for _ in range(3)]
print("  great Power Dragon Scale Mail:", got)
expect(got[0] == SN["SN_BLADETURNER"] and SN["SN_BLADETURNER"] not in got[1:], "a great one is Bladeturner, once")
got = [make(MHD, 60, great=True)["ego"] for _ in range(30)]
expect(got.count(SN["SN_RAZORBACK"]) == 1, "a great Multi-Hued one is Razorback 1 time in 3 (then never again)")
acs = [make(PDS, 30)["ac"] for _ in range(20)]
expect(all(a >= 1 for a in acs), f"and every dragon scale mail is enchanted ({min(acs)}..{max(acs)})")

# ---- their activations
clear(EQ, 10)
wear(PDS, ego=SN["SN_BLADETURNER"])
for t in ("P_HERO", "P_SHERO", "P_BLESSED", "P_RESIST_HEAT", "P_RESIST_COLD", "P_RESIST_LIGHT", "P_RESIST_ACID"): w16(t, 0)
keyed(ACTIVATE, "a")
vals = [r16(t) for t in ("P_HERO", "P_SHERO", "P_BLESSED", "P_RESIST_HEAT", "P_RESIST_COLD", "P_RESIST_LIGHT", "P_RESIST_ACID")]
print("  Bladeturner:", repr(msgline()), vals, atime(1))
expect(all(50 <= v <= 100 for v in vals) and atime(1) == 399, "Bladeturner: hero, berserk, blessed and four resistances, 50 + 1d50 (a turn gone); 400 turns")
for t in ("P_HERO", "P_SHERO", "P_BLESSED"): w16(t, 1)
tick(2)
clear(EQ, 10)
wear(MHD, ego=SN["SN_RAZORBACK"])
ln = open_line()
race = next(i for i, r in enumerate(RACES) if not r["raw"][15] & 3 and not r["raw"][13] & 1 and r["level"] < 10)
place_mon(race, ln[1], ln[2])
h0 = mon_hp()
keyed(ACTIVATE, "a")
print("  Razorback: hp", h0, "->", mon_hp(), atime(1))
expect(h0 - mon_hp() >= 150 and atime(1) == 999, "Razorback: a huge ball of lightning every way, 150 at the heart; 1000 turns")
kill_mon(); clear(EQ, 10)

# ---- cursed armour still has its base armour class
SLA = KIDX["Soft Leather Armour"]
clear(A["PACK"], 12); put(0, SLA, ident=KNOWN, ac=-3); keyed(WIELD, "a")
ac_plain = rd(A["P_AC"], 1)[0]
clear(EQ, 10); clear(A["PACK"], 12); put(0, SLA, ident=KNOWN | ID_CURSED, ac=-3); keyed(WIELD, "a")
ac_cursed = rd(A["P_AC"], 1)[0]
print("  armour class: plain", ac_plain, "cursed", ac_cursed)
expect(ac_cursed == ac_plain and ac_plain > 0, "cursed Soft Leather Armour (-3) gives its base AC all the same")
clear(EQ, 10)

# ---- berserk hit points are worked out as they're given (30)
st = struct.unpack("<H", rd(A["P_STATUS"], 2))[0]
wr(A["P_STATUS"], struct.pack("<H", st & ~0x80)); call(A["CALC_HITPOINTS"]); m0 = r16("P_MHP")
wr(A["P_STATUS"], struct.pack("<H", st | 0x80)); call(A["CALC_HITPOINTS"]); m1 = r16("P_MHP")
wr(A["P_STATUS"], struct.pack("<H", st & ~0x80)); call(A["CALC_HITPOINTS"])
expect(m1 - m0 == 30 and r16("P_MHP") == m0, f"berserk: +30 maximum hit points when they're worked out again ({m1 - m0})")

# ---- the One Ring takes nothing from nothing
clear(A["PACK"], 12); put(0, KIDX["Ring of Power"], ident=KNOWN); keyed(WIELD, "a")
wr(A["P_EXP"], bytes(4)); wr(A["P_MAX_EXP"], bytes(4))
page(PAGE_MAGIC)
for _ in range(100): call(A["ART_TICK"])
mx = struct.unpack("<I", rd(A["P_MAX_EXP"], 4))[0]
expect(mx == 0, f"with no experience the One Ring drains none (max {mx})")
wr(A["P_EXP"], struct.pack("<I", 1000)); wr(A["P_MAX_EXP"], struct.pack("<I", 1000))
for _ in range(100): call(A["ART_TICK"])
ex = struct.unpack("<I", rd(A["P_EXP"], 4))[0]
expect(ex < 1000, f"but drains it when there is some ({ex})")
clear(EQ, 10); wr(A["P_EXP"], struct.pack("<I", 1000)); wr(A["P_MAX_EXP"], struct.pack("<I", 1000))

# ---- cuts heal even with a poor constitution
w16("P_MHP", 500); w16("P_CHP", 500)
for adj, want in ((-2, 48), (0, 49), (2, 47)):
    wr(A["P_CON_ADJ"], bytes([adj & 255])); w16("P_CUT", 50)
    page(PAGE_MAGIC); call(A["CUT_TICK"])
    expect(r16("P_CUT") == want, f"con adjustment {adj}: a cut of 50 heals to {want} ({r16('P_CUT')})")
w16("P_CUT", 0)

# ---- acid: armour that's immune isn't eaten
SC = KIDX["Shadow Cloak"]
clear(A["PACK"], 12); put(0, SC, ident=KNOWN, ego=SN["SN_TUOR"], pval=4, ac=12); keyed(WIELD, "a")
a0 = eq(4)["ac"]
call(A["MSG_CLEAR"]); page(PAGE_MCAST); call(A["MINUS_AC"])
print("  acid on Tuor:", repr(msgline()), a0, eq(4)["ac"])
expect("resists damage!" in msgline() and eq(4)["ac"] == a0, "the Shadow Cloak of Tuor resists the acid")
clear(EQ, 10)

# ---- lightning reaches the pack
WAND = next(i for i, k in enumerate(KINDS) if k.startswith("Wand of"))
clear(A["PACK"], 12)
for sl in range(10): put(sl, WAND, pval=5)
w16("P_CHP", 500)
page(PAGE_MCAST)
for _ in range(60):
    set_reg(5, 1); call(A["EL_LIGHT"])
left = sum(1 for sl in range(12) if rd(A["PACK"] + IS*sl + 1, 1)[0] != 255)
print("  wands left after 60 shocks:", left)
expect(left < 10, "lightning destroys wands in the pack (1d100 < 3 each)")
clear(A["PACK"], 12)

# ---- earthquakes and destruction spare the stairs (and quakes, artifacts)
def around(r):
    y0, x0 = py()
    return [(y0 + dy, x0 + dx) for dy in range(-r, r + 1) for dx in range(-r, r + 1)
            if (dy or dx) and 0 < y0 + dy < 65 and 0 < x0 + dx < 197]
y0, x0 = py()
spots = [(y, x) for y, x in around(5) if (y + x) % 3 == 0][:30]
for y, x in spots: set_sq(y, x, 8)
ay, ax = next((y, x) for y, x in around(3) if (y, x) not in spots)
set_sq(ay, ax, 1)
clear(0xB400, 64)
wr(0xB400, bytes([KIDX["Longsword"] & 255, KIDX["Longsword"] >> 8, 1, ay, ax, 1, 0, 0, KNOWN, 10, 10, 0, SN["SN_RINGIL"], 0]))
before = rd(0xC000, W*66)
page(PAGE_DEVICE)
for _ in range(6): call(A["EARTHQUAKE"])
after = rd(0xC000, W*66)
changed = sum(1 for i in range(W*66) if (before[i] & 15) != (after[i] & 15))
print("  quakes:", changed, "squares changed")
expect(changed > 0 and all(sq(y, x) & 15 == 8 for y, x in spots), "earthquakes leave the stairs standing")
expect(rd(0xB401, 1)[0] != 255 and sq(ay, ax) & 15 == 1, "and Ringil, and the floor it lies on")
clear(0xB400, 64)
spots = [(y, x) for y, x in around(12) if (y + x) % 5 == 0][:40]
for y, x in spots: set_sq(y, x, 9)
page(PAGE_SCROLL); call(A["SC_DESTRUCTION"])
expect(all(sq(y, x) & 15 == 9 for y, x in spots), "*Destruction* leaves them too")
w16("P_BLIND", 0)

# ---- no rubble under a monster
m = rd(0xC000, W*66)
cor = [i for i in range(W*66) if m[i] & 15 == 2]
marked = [i for i in cor if (i % W) % 2 == 0]
for i in marked: wr(0xC000 + i, bytes([m[i] | 0x80]))
bad = 0
for _ in range(5):
    page(PAGE_TRAP); call(A["ALLOC_TRAPS"])
    mm = rd(0xC000, W*66)
    bad += sum(1 for i in marked if mm[i] & 15 == 10)
    for i in cor:
        if mm[i] & 15 == 10: wr(0xC000 + i, bytes([(mm[i] & 0xF0) | 2]))
mm = rd(0xC000, W*66)
for i in marked: wr(0xC000 + i, bytes([mm[i] & 0x7F]))
expect(bad == 0, f"the level's rubble never lands where a monster stands ({bad})")
cmd(2)
print("ALL OK" if ok else "FAILURES")
