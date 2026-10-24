import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
EGOS_SRC = open(_os.path.join(_GAME, "data", "egos.asm")).read()
SN = {m.group(1): int(m.group(2)) for m in re.finditer(r"^(SN_\w+)\t+equ (\d+)", EGOS_SRC, re.M)}
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
IS = 14
EQ = A["EQUIP"]
sg = lambda v: v - 256 if v > 127 else v
def raw(k, ident=0, hit=0, dam=0, ac=0, pval=0, ego=0):
    return bytes([k & 255, k >> 8, 1, 0, 0, 1, pval & 255, 0, ident, hit & 255, dam & 255, ac & 255, ego, 0])
def put(slot, k, base=None, **kw): wr((A["PACK"] if base is None else base) + IS*slot, raw(k, **kw))
def clear(base, n):
    for i in range(n): wr(base + IS*i, bytes([0, 255] + [0]*12))
def atime(slot): return struct.unpack("<H", rd(EQ + IS*slot + 3, 2))[0]
def set_atime(slot, v): wr(EQ + IS*slot + 3, struct.pack("<H", v))
def keyed(cmdno, keys, capture=False):
    install_keys(keys)
    set_reg(3, 0); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"])
    shot = None
    if capture:
        run_to(A["READ_ASCII"]); shot = screen()
    run_to(BP)
    return shot
WIELD, TAKEOFF, ACTIVATE = 6, 7, 17
def lines_of(shot): return [l.strip() for l in shot if re.match(r"\s*[a-l]\) ", l)]
def tick(n=1):
    for _ in range(n): act(3)
def calm():
    for i in range(64):
        b = 0xB000 + 16*i
        if rd(b + 12, 1)[0] != 255:
            y, x = rd(b + 1, 2); wr(0xC000 + y*198 + x, bytes([rd(0xC000 + y*198 + x, 1)[0] & 0x7F])); wr(b + 12, bytes([255]))
calm()
ID_STORE, ID_KNOWN2 = 1, 4
KNOWN = ID_STORE | ID_KNOWN2
W = 198
def wear(k, ego=0, pval=0, base_slot=None, keys="a"):
    clear(A["PACK"], 12); put(0, k, ident=KNOWN, ego=ego, pval=pval); keyed(WIELD, keys)
def py(): return rd(A["PLAYER_Y"], 1)[0], rd(A["PLAYER_X"], 1)[0]
DIRS = {1: (1, -1), 2: (1, 0), 3: (1, 1), 4: (0, -1), 6: (0, 1), 7: (-1, -1), 8: (-1, 0), 9: (-1, 1)}
def open_line():
    y, x = py(); m = rd(0xC000, W * 66)
    for d, (dy, dx) in DIRS.items():
        if all((m[(y + dy*i)*W + x + dx*i] & 15) in (1, 2, 14) for i in (1, 2, 3)):
            return d, y + 2*dy, x + 2*dx
    return None
def place_mon(race, y, x, hp=600):
    b = 0xB000
    wr(b, bytes([race & 255, y, x, hp & 255, hp >> 8, 0, 0, 255, 0, 0, 2, 1, race >> 8, 0, 0, 0]))
    a = 0xC000 + y*W + x; wr(a, bytes([rd(a, 1)[0] | 0x80]))
def mon_hp(): return struct.unpack("<h", rd(0xB000 + 3, 2))[0]
def kill_mon():
    y, x = rd(0xB001, 2); a = 0xC000 + y*W + x; wr(a, bytes([rd(a, 1)[0] & 0x7F])); wr(0xB000 + 12, bytes([255]))

# smart enough to activate things
wr(A["P_STAT_USE"] + 1, bytes([118])); wr(A["P_STAT"] + 1, bytes([118])); wr(A["P_LEV"], bytes([30]))
clear(EQ, 10)

# ---- nothing to activate
keyed(ACTIVATE, "a")
expect("You are not wearing/wielding anything that can be activated." in msgline(), "nothing to activate: the C's message")

# ---- Narthanc: a fire bolt, then it recharges
wear(KIDX["Dagger"], ego=SN["SN_NARTHANC"])
ln = open_line()
print("  line:", ln)
race = next(i for i, r in enumerate(RACES) if not r["raw"][15] & 3 and not r["raw"][13] & 1 and r["level"] < 10)
place_mon(race, ln[1], ln[2])
h0 = mon_hp()
shot = keyed(ACTIVATE, "a" + str(ln[0]), capture=True)
print("  list:", lines_of(shot), " ->", repr(msgline()), "hp", h0, "->", mon_hp(), "timeout", atime(0))
expect(any("Dagger named Narthanc" in l for l in lines_of(shot)), "'A' lists the Dagger named Narthanc")
expect(9 <= h0 - mon_hp() <= 72 or mon_hp() < 0, "a 9d8 fire bolt hits the monster")
expect(5 <= atime(0) <= 14, "and it needs 5 + 1d10 turns to recharge (one already gone)")
t0 = atime(0)
shot = keyed(ACTIVATE, "a" + str(ln[0]), capture=True)
run_to(A["READ_ASCII"]) if False else None
print("  again ->", repr(msgline()), atime(0))
expect(atime(0) == t0 - 1, "activating it again does nothing while it recharges")
kill_mon()
t0 = atime(0)
tick(3)
expect(atime(0) == t0 - 3, "recharging a turn at a time")
set_atime(0, 0)

# ---- not known: not listed
clear(A["PACK"], 12); put(0, KIDX["Dagger"], ego=SN["SN_NARTHANC"]); keyed(TAKEOFF, "a"); keyed(WIELD, "a")
keyed(ACTIVATE, "a")
expect("anything that can be activated" in msgline(), "an artifact not known to be one can't be activated")

# ---- Ringil: a 100 ball of frost
wear(KIDX["Longsword"], ego=SN["SN_RINGIL"])
ln = open_line(); place_mon(race, ln[1], ln[2]); h0 = mon_hp()
keyed(ACTIVATE, "a" + str(ln[0]))
print("  Ringil: hp", h0, "->", mon_hp(), "timeout", atime(0))
expect(h0 - mon_hp() == 100 and atime(0) == 299, "Ringil: a storm of Ice for 100, then 300 turns")
kill_mon()

# ---- Dal-i-thalion cures fear and poison; Gondor heals; Tulkas hastes; Colluin resists
clear(EQ, 10)
wear(KIDX["Pair of Soft Leather Boots"], ego=SN["SN_DAL"], pval=5)
w16("P_POISONED", 20); w16("P_AFRAID", 20)
keyed(ACTIVATE, "a")
expect(r16("P_POISONED") == 0 and r16("P_AFRAID") == 0 and atime(6) == 4, "Dal-i-thalion: no more fear or poison; 5 turns")
wear(KIDX["Golden Crown"], ego=SN["SN_GONDOR"], pval=3)
w16("P_CHP", 1)
keyed(ACTIVATE, "a")
expect(r16("P_CHP") == r16("P_MHP"), "Gondor: healed (500)")
ring = KIDX["Ring of Tulkas"]
clear(A["PACK"], 12); put(0, ring, ident=KNOWN, pval=4); keyed(WIELD, "a")
w16("P_FAST", 0)
keyed(ACTIVATE, "c")
f = r16("P_FAST"); print("  Tulkas: fast", f)
expect(51 <= f <= 150, "the Ring of Tulkas: fast for 50 + 1d100")
w16("P_FAST", 0)
wear(KIDX["Cloak"], ego=SN["SN_COLLUIN"])
w16("P_RESIST_HEAT", 0); w16("P_RESIST_COLD", 0)
keyed(ACTIVATE, "b")
expect(21 <= r16("P_RESIST_HEAT") <= 40 and 21 <= r16("P_RESIST_COLD") <= 40, "Colluin: resist heat and cold 20 + 1d20")

# ---- Avavir: recall; Belegennon: phase door
clear(EQ, 10)
wear(KIDX["Scythe"], ego=SN["SN_AVAVIR"])
w16("P_WORD_RECALL", 0)
keyed(ACTIVATE, "a")
expect(16 <= r16("P_WORD_RECALL") <= 35, "Avavir: recalled in 15 + 1d20")
w16("P_WORD_RECALL", 0)
wear(KIDX["Mithril Chain Mail"], ego=SN["SN_BELEGENNON"])
y0, x0 = py()
keyed(ACTIVATE, "b")
y1, x1 = py()
print("  Belegennon: from", (y0, x0), "to", (y1, x1))
expect((y0, x0) != (y1, x1) and abs(y1 - y0) <= 10 and abs(x1 - x0) <= 10, "Belegennon: teleport(10)")

# ---- Ingwe dispels evil for 5 x level
clear(EQ, 10)
amu = KIDX["Amulet of Ingwe"]
clear(A["PACK"], 12); put(0, amu, ident=KNOWN, pval=3); keyed(WIELD, "a")
ln = open_line(); evil = next(i for i, r in enumerate(RACES) if r["raw"][13] & 8 and not r["raw"][13] & 1 and r["level"] < 10)
place_mon(evil, ln[1], ln[2]); h0 = mon_hp()
keyed(ACTIVATE, "a")
print("  Ingwe:", NAMES[evil], h0, "->", mon_hp())
expect(1 <= h0 - mon_hp() <= 150, "the Amulet of Ingwe: dispel evil for 1d(5 x 30)")
kill_mon()

# ---- failing: a dim novice and the Ring of Power named Narya (level 80)
wr(A["P_STAT"] + 1, bytes([3])); wr(A["P_STAT_USE"] + 1, bytes([3])); wr(A["P_LEV"], bytes([1]))
clear(EQ, 10)
clear(A["PACK"], 12); put(0, KIDX["Ring of Power named Narya"], ident=KNOWN, pval=1); keyed(WIELD, "a")
fails = 0
for t in range(8):
    keyed(ACTIVATE, "a6")
    set_atime(8, 0)
    fails += "You fail to activate it properly." in msgline()
print("  Narya at level 1, INT 3:", fails, "failures in 8")
expect(fails >= 5, "a level 1 character with INT 3 mostly fails to activate Narya")
cmd(2)
print("ALL OK" if ok else "FAILURES")
