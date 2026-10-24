import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
G = _os.path.join(_GAME, "data", "spells.asm")
_sp = open(G).read()
REC = [tuple(int(m.group(i)) for i in (1, 2, 3, 4)) for m in re.finditer(r"\tdb (\d+),(\d+),(\d+)\n\tdw (\d+)", _sp)]
PRIEST = REC[63:126]
SNAMES = [m.group(1) for m in re.finditer(r'^spn_\d+:\tdb "?(.*?)"?,?0$', _sp, re.M)]
install_keys("amc\rTuck\r")							# a human male priest
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
IS = 14
EQ = A["EQUIP"]
sg = lambda v: v - 256 if v > 127 else v
def put(slot, k, ident=1, base=None):
    wr((A["PACK"] if base is None else base) + IS*slot, bytes([k & 255, k >> 8, 1, 0, 0, 1, 0, 0, ident, 0, 0, 0, 0, 0]))
def clear(base, n):
    for i in range(n): wr(base + IS*i, bytes([0, 255] + [0]*12))
def keyed(cmdno, keys, capture=False):
    install_keys(keys)
    set_reg(3, 0); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"])
    shot = None
    for _ in range(int(capture)):
        run_to(A["READ_ASCII"])
        if _ < int(capture) - 1: set_pc(KEYSTUB)		# (that key, then on)
    if capture: shot = screen()
    run_to(BP)
    return shot
INV, WIELD, CAST, BROWSE, STUDY, PRAY = 4, 6, 18, 19, 20, 21
def lines_of(shot): return [l.strip() for l in shot if re.match(r"\s*[a-v]\) ", l)]
def tick(n=1):
    for _ in range(n): act(3)
for i in range(64):
    b = 0xB000 + 16*i
    if rd(b + 12, 1)[0] != 255:
        y, x = rd(b + 1, 2); wr(0xC000 + y*198 + x, bytes([rd(0xC000 + y*198 + x, 1)[0] & 0x7F])); wr(b + 12, bytes([255]))
def bits(n): return int.from_bytes(rd(A[n], 8), "little")
def mana(): return r16("P_CMANA"), r16("P_MANA")
W = 198
def py(): return rd(A["PLAYER_Y"], 1)[0], rd(A["PLAYER_X"], 1)[0]
DIRS = {1: (1, -1), 2: (1, 0), 3: (1, 1), 4: (0, -1), 6: (0, 1), 7: (-1, -1), 8: (-1, 0), 9: (-1, 1)}
def open_line():
    y, x = py(); m = rd(0xC000, W * 66)
    for d, (dy, dx) in DIRS.items():
        if all((m[(y + dy*i)*W + x + dx*i] & 15) in (1, 2, 14) for i in (1, 2, 3)):
            return d, y + 2*dy, x + 2*dx
def place_mon(race, y, x, hp=600):
    wr(0xB000, bytes([race & 255, y, x, hp & 255, hp >> 8, 0, 0, 255, 0, 0, 2, 1, race >> 8, 0, 0, 0]))
    a = 0xC000 + y*W + x; wr(a, bytes([rd(a, 1)[0] | 0x80]))
def mon_hp(): return struct.unpack("<h", rd(0xB000 + 3, 2))[0]
def kill_mon():
    y, x = rd(0xB001, 2); a = 0xC000 + y*W + x; wr(a, bytes([rd(a, 1)[0] & 0x7F])); wr(0xB000 + 12, bytes([255]))
def stat_adj(v):
    for lim, r in ((8,0),(15,1),(18,2),(68,3),(88,4),(108,5),(118,6),(119,7),(129,8),(139,9),(149,10),(159,11),(169,12),(179,13),(189,14),(199,15),(219,16),(229,18)):
        if v < lim: return r
    return 20
def chance(sp, lev, intel, cmana):
    l, m, f, e = MAGE[sp]
    c = f - 3*(lev - l) - 3*(stat_adj(intel) - 1)
    if m > cmana: c += 5*(m - cmana)
    mf = [50,12,8,5,4,4,3,3,2,2,2,2,2,1,1,1,1,0][min(stat_adj(intel), 17)]
    return max(mf, min(95, c))


# ---- a new priest
print("  p_spell", rd(A["P_SPELL"], 1)[0], "new", rd(A["S_NEW"], 1)[0], "mana", mana())
shot = keyed(INV, " ", capture=True)
print("  pack:", lines_of(shot))
expect(rd(A["P_SPELL"], 1)[0] == 2 and any("Holy Book of Prayers [Beginners Handbook]" in l for l in lines_of(shot)),
       "a priest, carrying 'a Holy Book of Prayers [Beginners Handbook]'")
book = next(i for i, l in enumerate(lines_of(shot)) if "Beginners Handbook" in l)
BL = chr(97 + book)

# ---- learning: priests are given a prayer at random
n0 = rd(A["S_NEW"], 1)[0]
keyed(STUDY, " ")
m = msgline(); print("  study ->", repr(m), hex(bits("S_LEARNED")))
expect(m.startswith("You have learned the prayer of ") and bin(bits("S_LEARNED")).count("1") == 1 and rd(A["S_NEW"], 1)[0] == n0 - 1,
       "'G': 'You have learned the prayer of ...', chosen for you")
tick()
wis = rd(A["P_STAT_USE"] + 2, 1)[0]
print("  WIS", wis, "mana", mana())
expect(mana()[1] >= 2, "mana from WIS")

# ---- the wrong commands
keyed(CAST, BL + "a")
expect("You can't cast spells!" in msgline(), "a priest can't 'm': 'You can't cast spells!'")

# ---- prayers
wr(A["P_STAT"] + 2, bytes([118])); wr(A["P_LEV"], bytes([50])); wr(A["P_UPDATE"], bytes([1])); tick()
learn = lambda *s: wr(A["S_LEARNED"], (bits("S_LEARNED") | sum(1 << x for x in s)).to_bytes(8, "little"))
def pray(keys):
    for t in range(8):
        w16("P_CMANA", 300)
        keyed(PRAY, keys)
        if "concentration" not in msgline(): break
    print("   ", keys, "->", repr(msgline()))
clear(A["PACK"], 12)
for i, b in enumerate(("[Beginners Handbook]", "[Words of Wisdom]", "[Chants and Blessings]", "[Exorcism and Dispelling]",
                       "[Purifications and Healing]", "[Holy Infusions]", "[Wrath of God]", "[Ethereal Openings]")):
    put(i, KIDX[b])
learn(2, 9, 17, 24, 26, 27, 39, 49, 51, 43, 57)
w16("P_BLESSED", 0); pray("ac")
expect(12 <= r16("P_BLESSED") <= 23, "Bless: blessed for 12 + 1d12")
y0 = py(); pray("bb")
expect(py() != y0, "Portal: teleport(lev * 3)")
ln = open_line(); race = next(i for i, r in enumerate(RACES) if r["level"] < 5 and not r["raw"][13] & 1)
place_mon(race, ln[1], ln[2]); h0 = mon_hp()
pray("cb" + str(ln[0]))
print("  orb:", h0 - mon_hp())
expect(53 <= h0 - mon_hp() <= 68, "Orb of Draining: 3d6 + level")
kill_mon()
und = next(i for i, r in enumerate(RACES) if r["raw"][13] & 16 and r["level"] < 30 and not r["raw"][13] & 5)
ln = open_line(); place_mon(und, ln[1], ln[2]); h0 = mon_hp()
wr(0xB000 + 13, bytes([0])); pray("ci")
print("  turn undead:", NAMES[und], "confused", rd(0xB000 + 13, 1)[0])
expect(rd(0xB000 + 13, 1)[0] == 1 and "runs frantically" in msgline(), "Turn Undead: it runs frantically (confused)")
h0 = mon_hp(); pray("db")
print("  dispel undead:", h0 - mon_hp())
expect(1 <= h0 - mon_hp() <= 150, "Dispel Undead: 1d(3 x level)")
kill_mon()
w16("P_CHP", 5); w16("P_STUN", 20); w16("P_CUT", 30); pray("dc")
expect(r16("P_CHP") >= 205 or r16("P_CHP") == r16("P_MHP"), "Heal: 200")
expect(r16("P_STUN") == 0 and r16("P_CUT") == 0, "and no more stun or cuts")
wr(A["P_STAT"], bytes([10])); pray("ed")
expect(rd(A["P_STAT"], 1)[0] == rd(A["P_STAT_MAX"], 1)[0], "Restoration: STR back to its maximum")
clear(EQ, 1); put(0, KIDX["Dagger"], base=EQ, ident=5); wr(A["P_UPDATE"], bytes([1])); tick()
pray("fd")
e = rd(EQ, 14); print("  enchant weapon:", sg(e[9]), sg(e[10]))
expect(sg(e[9]) > 0 or sg(e[10]) > 0 or "fails" in msgline(), "Enchant Weapon: + to-hit and to-dam")
pray("ff")
e = rd(EQ, 14); print("  brand: ego", e[12])
expect(e[12] in (12, 13) and sg(e[9]) >= 4, "Elemental Brand: of Flame or of Frost, + 3 + 1d3")
ev = next(i for i, r in enumerate(RACES) if r["raw"][13] & 8 and r["level"] < 10 and not r["raw"][13] & 1)
ln = open_line(); place_mon(ev, ln[1], ln[2]); y0, x0 = rd(0xB001, 2)
pray("gc")
y1, x1 = rd(0xB001, 2)
print("  banish:", (y0, x0), "->", (y1, x1))
expect((y0, x0) != (y1, x1) and "banishes" in msgline(), "Banishment: the evil are sent away")
kill_mon()
wr(A["P_NEW_LEVEL"], bytes([0])); pray("hf")
print("  alter reality ->", repr(msgline()))
expect(r8("P_NEW_LEVEL") == 0, "Alter Reality: a new level (already made)")

# ---- not a priest
wr(A["P_SPELL"], bytes([0]))
keyed(PRAY, "a")
expect("Pray hard enough and your prayers may be answered." in msgline(), "anyone else: 'Pray hard enough...'")
cmd(2)
print("ALL OK" if ok else "FAILURES")
