import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
def exp(): return struct.unpack("<I", rd(A["P_EXP"], 4))[0]
def set_exp(v): wr(A["P_EXP"], struct.pack("<I", v))
# every blow lands (the test, not the game)
wr(A["TEST_HIT"], bytes([0x37, 0xC9]))
STUB = 0xBD80							# call mon_race : jp mon_attack
wr(STUB, bytes([0xCD]) + struct.pack("<H", A["MON_RACE"]) + bytes([0xC3]) + struct.pack("<H", A["MON_ATTACK"]))
R = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and 18 <= r["level"] <= 25 and not r["raw"][13] & 4)
LEV = RACES[R]["level"]
print("  attacker:", NAMES[R], "level", LEV)
def race_wr(ofs, data):
    cmd(10, bytes([1, 44 + R // 128])); wr(0x2000 + (R % 128)*64 + ofs, bytes(data))
def blow(t, d, dice=1, sides=1):
    race_wr(16, [t, d, dice, sides] + [0]*12)
y0, x0 = py()
dy, dx = open_line(1)
def attack():
    call(A["MSG_CLEAR"])
    set_reg(6, 0xB000); call(STUB)
    return msgline()
def setup(hp=300):
    calm(); place(0, R, y0 + dy, x0 + dx, hp=hp)
full(); no_resists()
wr(A["P_AC"], bytes([0])); wr(A["P_SAVE"], bytes([0x9C])); wr(A["P_SUSTAIN"], bytes([0]))
for t in ("P_CUT", "P_STUN", "P_CONFUSED", "P_AFRAID", "P_BLIND", "P_POISONED", "P_SLOW"): w16(t, 0)
setup()

# 1: plain, with armour
blow(1, 1, 3, 1); h = hp(); m = attack()
print("  hit:", repr(m), h - hp())
expect("hits you." in m and h - hp() == 3, "normal blow: 'hits you.' for its dice")
wr(A["P_AC"], bytes([100])); blow(1, 2, 20, 1); h = hp(); attack()
expect(h - hp() == 20 - (75 * 20) // 200, "armour absorbs (ac * 3/4 * dam) / 200")
wr(A["P_AC"], bytes([0])); full()
# criticals
blow(1, 2, 50, 1); w16("P_CUT", 0); attack()
print("  big bite: cut", r16("P_CUT"))
expect(r16("P_CUT") >= 5000, "a maximum 50-point bite: a mortal wound")
w16("P_CUT", 0); blow(1, 17, 50, 1); w16("P_STUN", 0); attack()
expect(101 <= r16("P_STUN") <= 110, "a maximum 50-point trample: knocked out")
w16("P_STUN", 0); full()
blow(1, 19); m = attack()
print("  insult:", repr(m))
expect(any(w in m for w in ("insults", "finger", "humiliates", "wets", "defiles", "dances", "obscene", "moons")), "desc 19: one of the C's nine insults")
blow(1, 15); m = attack()
expect("You've been slimed!" in m, "desc 15: 'You've been slimed!'")

# 2-4
def until(t, d, pred, n=30):
    blow(t, d)
    for _ in range(n):
        m = attack()
        if pred(m): return m
    return None
blow(2, 1); st = rd(A["P_STAT"], 1)[0]
m = until(2, 1, lambda m: "You feel weaker." in m)
expect(m and rd(A["P_STAT"], 1)[0] < st, "lose strength: 'You feel weaker.' and it drops (half the time)")
wr(A["P_SUSTAIN"], bytes([1])); m = attack()
expect("You feel weaker for a moment, but it passes." in m, "sustained strength")
wr(A["P_SUSTAIN"], bytes([0])); full()
m = until(3, 1, lambda m: "You feel confused." in m)
c = r16("P_CONFUSED")
expect(m and 4 <= c <= LEV + 3, "confusion: 1d(level) + 3")
w16("P_CONFUSED", 0)
blow(4, 1); m = attack()
expect("You are suddenly afraid!" in m and 4 <= r16("P_AFRAID") <= LEV + 3, "fear: 3 + 1d(level)")
wr(A["P_SAVE"], bytes([127])); w16("P_AFRAID", 0); m = attack()
expect("You stand your ground!" in m and r16("P_AFRAID") == 0, "fear: saved")
wr(A["P_SAVE"], bytes([0x9C])); full()

# 5-9: elements
blow(5, 5, 30, 1); h = hp(); m = attack()
expect("You are enveloped in flames!" in m and h - hp() == 30, "fire blow: fire_dam")
rflag(2, 0x08); h = hp(); attack()
expect(h - hp() == 10, "fire blow resisted: a third")
no_resists()
blow(7, 5, 30, 1); h = hp(); m = attack()
expect("covered with frost" in m and h - hp() == 30, "cold blow")
blow(8, 5, 30, 1); h = hp(); m = attack()
expect("Lightning strikes you!" in m and h - hp() == 30, "lightning blow")
clear(EQ, 10); blow(6, 5, 30, 1); h = hp(); m = attack()
expect("covered in acid" in m and h - hp() == 30, "acid blow, no armour")
blow(9, 5, 10, 1); h = hp(); m = attack()
print("  corrosion:", repr(m), h - hp())
expect("stinging red gas" in m and 11 <= h - hp() <= 18, "corrosion: 1d8 (no armour to take it) and the blow's 10")
full()

# 10, 11, 14
blow(10, 7); m = attack()
expect("Your eyes begin to sting." in m and 11 <= r16("P_BLIND") <= LEV + 10, "blindness: 10 + 1d(level)")
w16("P_BLIND", 0)
blow(11, 5); wr(A["P_PARALYSED"], bytes([0])); m = attack()
p = rd(A["P_PARALYSED"], 1)[0]
expect("You are paralysed." in m and 4 <= p <= LEV + 3, "paralysis: 1d(level) + 3")
wr(A["P_PARALYSED"], bytes([0])); rflag(2, 0x80); m = attack()
expect("You are unaffected." in m and rd(A["P_PARALYSED"], 1)[0] == 0, "paralysis: free action")
no_resists()
blow(14, 4); w16("P_POISONED", 0); m = attack()
expect("You feel very sick." in m and 6 <= r16("P_POISONED") <= LEV + 5, "poison: 1d(level) + 5")
w16("P_POISONED", 0); rflag(3, 0x10); m = attack()
expect("The poison has no effect." in m and r16("P_POISONED") == 0, "poison resisted")
no_resists(); full()

# 12, 13: theft
check("before theft")
wr(A["P_STAT_USE"] + 3, bytes([3]))		# clumsy: can't hold on
wr(A["P_GOLD"], struct.pack("<I", 1000)); blow(12, 14); m = attack()
g = struct.unpack("<I", rd(A["P_GOLD"], 4))[0]
print("  steal gold:", repr(m), 1000, "->", g, "thief", "gone" if (mon(0)["y"], mon(0)["x"]) != (y0 + dy, x0 + dx) else "stays")
expect(("Your purse feels lighter." in m or "puff of smoke" in m) and 1000 - 125 <= g <= 1000 - 101, "steal gold: au / 10 + 1d25")
setup()
food = next(i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 1)
clear(A["PACK"], 12); put(A["PACK"], 0, food, num=5)
blow(13, 5)
cmd(10, bytes([1, 44 + R // 128])); print("  attack bytes", list(rd(0x2000 + (R % 128)*64 + 16, 8)), "gold", struct.unpack("<I", rd(A["P_GOLD"], 4))[0])
check("before stealing")
m = attack()
print("  steal object:", repr(m), pack()[0], "gold", struct.unpack("<I", rd(A["P_GOLD"], 4))[0])
expect("Your backpack feels lighter." in m and pack()[0]["num"] == 4, "steal object: one of the stack")
setup()
wr(A["P_STAT_USE"] + 3, bytes([118]))
w = 0
for _ in range(20):
    put(A["PACK"], 0, food, num=5)
    m = attack(); w += pack()[0]["num"] == 5
    setup()
print("  kept hold", w, "of 20")
expect(w >= 10, "18/100 DEX mostly keeps hold of the pack")
wr(A["P_GOLD"], struct.pack("<I", 0)); blow(12, 14); m = attack()
expect(m == "", "nothing to steal: the blow misses (and nothing is said)")

# 15-18, 25: stats
setup(); full()
st0 = list(rd(A["P_STAT"], 6))
for t, i, word in ((15, 3, "more clumsy"), (16, 4, "health is damaged"), (18, 2, "wisdom is drained")):
    blow(t, 1); m = attack()
    expect(word in m and rd(A["P_STAT"] + i, 1)[0] < st0[i], f"type {t}: '{word}'")
blow(17, 1); m = attack()
expect("You have trouble thinking clearly." in m and rd(A["P_STAT"] + 1, 1)[0] < st0[1], "type 17: trouble thinking, INT drops")
wr(A["P_SUSTAIN"], bytes([2])); m = attack()
expect("But your mind quickly clears." in m, "type 17 sustained: 'But your mind quickly clears.'")
wr(A["P_SUSTAIN"], bytes([0]))
wr(A["P_STAT"], bytes([18]*6)); blow(25, 1); m = attack()
print("  drain all:", list(rd(A["P_STAT"], 6)))
expect(all(v < 18 for v in rd(A["P_STAT"], 6)), "drain all stats: all six drop")
wr(A["P_STAT"], bytes(st0)); full()

# 19: experience
set_exp(10000); blow(19, 5, 1, 1); m = attack()
expect("draining away" in m and exp() == 10000 - 1 - 200, "lose experience: damage + exp / 100 * 2")

# 20: aggravate
place(1, R, y0 + 8*dy if False else y0, x0, hp=10) if False else None
sl = None
for i in range(2, 64):
    pass
blow(20, 5); place(1, R, y0 - dy, x0 - dx); wr(0xB000 + 16 + 7, bytes([200, 0])); wr(0xB000 + 16 + 9, bytes([0]))
m = attack()
r1 = rd(0xB000 + 16, 16)
print("  aggravate:", repr(m), "sleep", r1[7] | r1[8] << 8, "speed", r1[9])
expect("sudden stirring" in m and (r1[7] | r1[8] << 8) == 0 and r1[9] == 1, "aggravate: wakes and quickens monsters within 20")
setup()

# 21: disenchant every worn piece
armour = next(i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 8 and k["raw"][9] > 0)
dagger = KIDX["Dagger"]
clear(EQ, 10)
for sl in (1, 2, 3, 4, 5, 6): put(EQ, sl, armour, toac=5)
wr(EQ, bytes([dagger & 255, dagger >> 8, 1, 0, 0, 1, 0, 0, 0, 5, 5, 0, 0, 0]))
blow(21, 5); m = attack()
pl = [sum(max(0, v - 256 if v > 127 else v) for v in rd(EQ + IS*sl + 9, 3)) for sl in range(7)]
print("  disenchant:", repr(m), pl)
expect("static feeling" in m and sum(pl) < 10 + 30 and sum(pl) >= 10 + 30 - 6, "disenchant: one piece loses 1d2 of each plus")
clear(EQ, 10)

# 22, 24
clear(A["PACK"], 12); put(A["PACK"], 0, food, num=3)
blow(22, 5); m = attack()
expect("It got at your rations!" in m and pack()[0]["num"] == 2, "eat food: one ration")
wand = next(i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 4)
clear(A["PACK"], 12); wr(A["PACK"], bytes([wand & 255, wand >> 8, 1, 0, 0, 1, 5, 0, 0, 0, 0, 0, 0, 0]))
setup(hp=100); blow(24, 5); m = attack()
print("  eat charges:", repr(m), "charges", rd(A["PACK"] + 6, 1)[0], "monster hp", mon(0)["hp"])
expect("Energy drains from your pack!" in m and rd(A["PACK"] + 6, 1)[0] == 0 and mon(0)["hp"] == 100 + 5*LEV, "eat charges: the monster gains level x charges")
expect(rd(A["PACK"] + 8, 1)[0] & 2, "and the wand is marked empty")
clear(A["PACK"], 12)

# a DESTRUCT monster's heavy blow shakes the cave
setup(hp=500); full()
cmd(10, bytes([1, 67])); a = 0x2000 + R*12 + 10; wr(a, bytes([rd(a, 1)[0] | 2]))
blow(1, 1, 30, 1)
before = rd(0xC000, W*66)
check("before the quake")
m = attack()
print("  monsters after:", [(NAMES[k["race"]], k["y"], k["x"]) for k in mons()], "player", py())
after = rd(0xC000, W*66)
changed = sum(1 for i in range(W*66) if (before[i] & 15) != (after[i] & 15))
mm_ = rd(0xC000, W*66); ms_ = mons()
flagged = {(i // W, i % W) for i, b in enumerate(mm_) if b & 0x80}
pos = {(k["y"], k["x"]) for k in ms_}
ok_ = flagged == pos and all((mm_[k["y"]*W + k["x"]] & 15) in (1, 2, 5, 6, 8, 9, 14) for k in ms_) and (mm_[py()[0]*W + py()[1]] & 15) in (1, 2, 6, 8, 9, 14)
print("  flags", sorted(flagged - pos)[:3], sorted(pos - flagged)[:3])
print("  quake:", repr(m), changed, "squares changed")
expect(changed > 0 and ok_, "shatter_quake: the cave changes, and every monster still stands on open ground")
cmd(2)
print("ALL OK" if ok else "FAILURES")
