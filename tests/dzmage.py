import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
G = _os.path.join(_GAME, "data", "spells.asm")
_sp = open(G).read()
REC = [tuple(int(m.group(i)) for i in (1, 2, 3, 4)) for m in re.finditer(r"\tdb (\d+),(\d+),(\d+)\n\tdw (\d+)", _sp)]
MAGE = REC[0:63]
SNAMES = [m.group(1) for m in re.finditer(r'^spn_\d+:\tdb "?(.*?)"?,?0$', _sp, re.M)]
install_keys("amb\rMerlin\r")							# a human male mage
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
INV, WIELD, CAST, BROWSE, STUDY = 4, 6, 18, 19, 20
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
    for yy in range(4, 62):								# (cramped: into a room)
        for xx in range(4, 194):
            if all((m[(yy + a)*W + xx + b] & 15) in (1, 2, 14) and not m[(yy + a)*W + xx + b] & 0x80
                   for a in range(-3, 4) for b in range(-3, 4)):
                wr(A["PLAYER_Y"], bytes([yy])); wr(A["PLAYER_X"], bytes([xx])); call(A["UPDATE_VIEW"])
                return open_line()
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

# ---- a new mage
print("  p_spell", rd(A["P_SPELL"], 1)[0], "first", rd(A["P_FIRST_SPELL"], 1)[0], "new", rd(A["S_NEW"], 1)[0], "mana", mana())
shot = keyed(INV, " ", capture=True)
print("  pack:", lines_of(shot))
expect(rd(A["P_SPELL"], 1)[0] == 1 and any("Book of Magic Spells [Magic for Beginners]" in l for l in lines_of(shot)),
       "a mage, carrying 'a Book of Magic Spells [Magic for Beginners]'")
expect(rd(A["S_NEW"], 1)[0] >= 1 and mana() == (0, 0), "able to learn spells, no mana until one is known")
book = next(i for i, l in enumerate(lines_of(shot)) if "Magic for Beginners" in l)
BL = chr(97 + book)

# ---- browse
shot = keyed(BROWSE, BL + " ", capture=2)
ls = lines_of(shot)
print("  browse:", ls[:3], len(ls), ls[-1])
MINE = [sp for sp in range(9) if MAGE[sp][0] < 99]
expect(ls[0].startswith("a) Magic Missile") and ls[0].endswith("unknown") and len(ls) == len(MINE), "browsing lists the book's spells a mage can learn, unknown so far")

# ---- study
n0 = rd(A["S_NEW"], 1)[0]
keyed(STUDY, "a")
print("  learnt:", hex(bits("S_LEARNED")), "new", rd(A["S_NEW"], 1)[0], "mana", mana(), repr(msgline()))
expect(bits("S_LEARNED") & 1 and rd(A["S_NEW"], 1)[0] == n0 - 1, "'G' then 'a': Magic Missile learnt")
tick()
cm, mm = mana()
intel = rd(A["P_STAT_USE"] + 1, 1)[0]
halves = [0,2,2,3,4,5,6,8,9,10,11,12,13,14,15,16][min(stat_adj(intel), 15)]
want = halves * 1 // 2 + 1
print("  INT", intel, "stat_adj", stat_adj(intel), "mana", (cm, mm), "C:", want)
expect(mm == want and cm == mm, "mana as calc_mana gives it at level 1")

# ---- cast
ln = open_line(); race = next(i for i, r in enumerate(RACES) if r["level"] < 5 and not r["raw"][13] & 1)
place_mon(race, ln[1], ln[2]); h0 = mon_hp()
e0 = r16("P_EXP") if False else struct.unpack("<I", rd(A["P_EXP"], 4))[0]
keyed(CAST, BL + "a" + str(ln[0]))
cm2, _ = mana(); e1 = struct.unpack("<I", rd(A["P_EXP"], 4))[0]
print("  cast ->", repr(msgline()), "hp", h0, "->", mon_hp(), "mana", cm, "->", cm2, "exp", e0, "->", e1)
expect((2 <= h0 - mon_hp() <= 12 and e1 == e0 + 4) or "failed" in msgline(), "Magic Missile: 2d6 at the monster, and 4 experience the first time (or it failed)")
expect(cm2 == cm - 1, "it costs a point of mana")
kill_mon()

# ---- failure chances, as spell_chance gives them
wr(A["S_LEARNED"], (0x1FF).to_bytes(4, "little"))
wr(A["P_LEV"], bytes([5])); w16("P_CMANA", 3)
shot = keyed(BROWSE, BL + " ", capture=2); ls = lines_of(shot)
got = [int(re.search(r"(\d+)%", l).group(1)) for l in ls]
want = [chance(s, 5, intel, 3) for s in MINE]
print("  fail%:", got, "C:", want)
expect(got == want, "every failure chance is spell_chance's")
expect(all(re.search(r"\s(\d+)\s+(\d+)\s+\d+%", l).groups() == (str(MAGE[s][0]), str(MAGE[s][1])) for s, l in zip(MINE, ls)), "and level and mana as magic_spell has them")

# ---- not enough mana: faint
wr(A["S_LEARNED"], (1).to_bytes(8, "little"))
w16("P_CMANA", 0)
wr(A["P_PARALYSED"], bytes([0]))
keyed(CAST, BL + "ay5")
print("  faint ->", repr(msgline()), "paralysed", rd(A["P_PARALYSED"], 1)[0], mana())
expect(1 <= rd(A["P_PARALYSED"], 1)[0] <= 5 and mana()[0] == 0, "casting with no mana: you faint for 1d(5 x 1)")
wr(A["P_PARALYSED"], bytes([0]))

# ---- regeneration
w16("P_CMANA", 0); w16("P_CMANA_FRAC", 0); tick(30)
print("  mana after 30 turns:", mana(), "frac", r16("P_CMANA_FRAC") & 0xFFFF)
expect(mana()[0] >= 1 or r16("P_CMANA_FRAC") != 0, "mana comes back (slowly, as in the C)")

# ---- level up: more spells, more mana
wr(A["S_LEARNED"], (1).to_bytes(8, "little")); wr(A["S_NEW"], bytes([0]))
wr(A["P_LEV"], bytes([10])); wr(A["P_UPDATE"], bytes([1])); tick()
print("  at level 10: new", rd(A["S_NEW"], 1)[0], "mana", mana())
expect(rd(A["S_NEW"], 1)[0] > 0 and mana()[1] > mm, "a higher level: more to learn and more mana")
_, m10 = mana()
put(3, KIDX["Set of Leather Gloves"]); keyed(WIELD, "d"); tick()
print("  with gloves:", mana(), "expected", 3 * m10 // 4)
expect(mana()[1] == 3 * m10 // 4, "gloves cost a mage a quarter of the mana")

# ---- spells' effects
wr(A["P_LEV"], bytes([50])); wr(A["P_UPDATE"], bytes([1])); tick()
w16("P_CMANA", 200)
def learn(*spells):
    v = bits("S_LEARNED")
    for s in spells: v |= 1 << s
    wr(A["S_LEARNED"], v.to_bytes(8, "little"))
def cast_ok(keys):
    for t in range(8):
        w16("P_CMANA", 200)
        keyed(CAST, keys)
        if "failed" not in msgline(): break
    print("   ", keys, "->", repr(msgline()))
learn(2, 5)
y0 = py(); cast_ok(BL + "c")
print("  phase door:", y0, "->", py())
expect(py() != y0, "Phase Door moves you")
w16("P_CHP", 1)
cast_ok(BL + "f")
expect(r16("P_CHP") >= 5, "Cure Light Wounds heals 4d4")
clear(A["PACK"], 12)
put(0, KIDX["[Magic for Beginners]"]); put(1, KIDX["[Conjurings and Tricks]"]); put(2, KIDX["[Sorcery and Evocations]"])
put(3, KIDX["[Resistance of Scarabtarices]"]); put(4, KIDX["[Mordenkainen's Escapes]"]); put(5, KIDX["[Tenser's Transformations]"])
learn(10, 29, 33, 34, 37, 49, 55, 57, 58)
ln = open_line(); place_mon(race, ln[1], ln[2]); h0 = mon_hp()
cast_ok("bb" + str(ln[0]))
dice = 3 + (50 - 5) // 4
print("  lightning bolt:", h0 - mon_hp(), "of", f"{dice}d8")
expect(dice <= h0 - mon_hp() <= dice * 8, "Lightning Bolt: (3 + (lev - 5) / 4)d8")
kill_mon()
w16("P_FAST", 0); cast_ok("cd")
print("  haste self: fast", r16("P_FAST"))
expect(51 <= r16("P_FAST") <= 70, "Haste Self: 1d20 + level")
cast_ok("ea")
tick()
f = set(rd(0xC000 + (py()[0] - 1)*W + py()[1] - 1, 3) + rd(0xC000 + (py()[0] + 1)*W + py()[1] - 1, 3))
print("  door creation:", [b & 15 for b in rd(0xC000 + (py()[0] - 1)*W + py()[1] - 1, 3)])
expect(any((b & 15) == 5 for b in f), "Door Creation: closed doors around you")
cast_ok("eb")
expect(rd(0xC000 + py()[0]*W + py()[1], 1)[0] & 15 in (8, 9), "Stair Creation: a staircase underfoot")
w16("P_WORD_RECALL", 0); cast_ok("ee")
expect(26 <= r16("P_WORD_RECALL") <= 55, "Word of Recall: 25 + 1d30")
w16("P_WORD_RECALL", 0)
w16("P_RESIST_HEAT", 0); cast_ok("da")
expect(20 <= r16("P_RESIST_HEAT") <= 40, "Resist Fire: 20 + 1d20")
ac0 = rd(A["P_AC"], 1)[0]; cast_ok("fb"); tick()
print("  shield:", r16("P_SHIELD"), "AC", ac0, "->", rd(A["P_AC"], 1)[0])
expect(29 <= r16("P_SHIELD") <= 50 and rd(A["P_AC"], 1)[0] == min(255, ac0 + 50), "Shield: +50 AC for 30 + 1d20 turns")
cast_ok("fe"); tick()
h = r16("P_CHP"); set_reg(5, 50); w16("KILLER_RACE", 0); call(A["TAKE_HIT"])
expect(r16("P_INVULN") > 0 and r16("P_CHP") == h, "Globe of Invulnerability: nothing hurts")

# ---- a warrior can't
wr(A["P_SPELL"], bytes([0]))
keyed(CAST, "a")
expect("You can't cast spells!" in msgline(), "a non-caster: 'You can't cast spells!'")
cmd(2)
print("ALL OK" if ok else "FAILURES")
