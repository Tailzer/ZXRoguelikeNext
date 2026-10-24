import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
wr(A["READ_ASCII"], bytes([0x3A]) + struct.pack("<H", A["ASCII_KEY"]) + bytes([0xC9]))
IS = 14
EQ = A["EQUIP"]
def calm():
    for i in range(64):
        b = 0xB000 + 16*i
        if rd(b + 12, 1)[0] != 255:
            y, x = rd(b + 1, 2); wr(0xC000 + y*W + x, bytes([rd(0xC000 + y*W + x, 1)[0] & 0x7F])); wr(b + 12, bytes([255]))
calm()
def py(): return rd(A["PLAYER_Y"], 1)[0], rd(A["PLAYER_X"], 1)[0]
DIRS = {1: (1, -1), 2: (1, 0), 3: (1, 1), 4: (0, -1), 6: (0, 1), 7: (-1, -1), 8: (-1, 0), 9: (-1, 1)}
OPEN = (1, 2, 14)
def open_line(n=3):
    y, x = py(); m = rd(0xC000, W * 66)
    for d, (dy, dx) in DIRS.items():
        if all((m[(y + dy*i)*W + x + dx*i] & 15) in OPEN and not m[(y + dy*i)*W + x + dx*i] & 0x80 for i in range(1, n + 1)):
            return dy, dx
    return None
def walk_to_room():
    """put the player somewhere with room all round (a 9x9 open block)"""
    m = rd(0xC000, W * 66)
    for y in range(6, 60):
        for x in range(6, 190):
            if all((m[(y + a)*W + x + b] & 15) in OPEN for a in range(-3, 4) for b in range(-3, 4)):
                wr(A["PLAYER_Y"], bytes([y])); wr(A["PLAYER_X"], bytes([x])); return y, x
    raise SystemExit("no room")
walk_to_room()
call(A["UPDATE_VIEW"])
def place(slot, race, y, x, hp=300, maxhp=None):
    b = 0xB000 + 16*slot
    mh = hp if maxhp is None else maxhp
    wr(b, bytes([race & 255, y, x, hp & 255, (hp >> 8) & 255, mh & 255, mh >> 8, 0, 0, 1, 0, 0, race >> 8, 0, 0, 0]))
    a = 0xC000 + y*W + x; wr(a, bytes([rd(a, 1)[0] | 0x80]))
def mon(slot):
    r = rd(0xB000 + 16*slot, 16)
    return dict(race=r[0] | r[12] << 8, y=r[1], x=r[2], hp=struct.unpack("<h", r[3:5])[0], speed=r[9] - 256 if r[9] > 127 else r[9], free=r[12] == 255)
def nmons(): return sum(1 for i in range(64) if rd(0xB000 + 16*i + 12, 1)[0] != 255)
def set_spells(race, casts, smart=False, freq=1):
    v = freq
    for c in casts: v |= 1 << (c - 1)
    cmd(10, bytes([1, A["MSPELL_PAGE"] if "MSPELL_PAGE" in A else 67]))
    wr(0x2000 + race*12, v.to_bytes(10, "little") + bytes([1 if smart else 0, 0]))
    cmd(10, bytes([1, 44 + race // 128]))
    a = 0x2000 + (race % 128)*64 + 15
    wr(a, bytes([rd(a, 1)[0] | 0x80]))
def turn(slot=0):
    call(A["MSG_CLEAR"])
    set_reg(6, 0xB000 + 16*slot); call(A["MON_TURN"])
    return msgline()
def hp(): return r16("P_CHP")
def full(): w16("P_MHP", 3000); w16("P_CHP", 3000)
def rflag(ofs, v): wr(A["P_EFLAGS"] + ofs, bytes([v]))
def rflag2(ofs, v): wr(A["P_EFLAGS2"] + ofs, bytes([v]))
def no_resists():
    wr(A["P_EFLAGS"], bytes(4)); wr(A["P_EFLAGS2"], bytes(4))
    for t in ("P_RESIST_HEAT", "P_RESIST_COLD", "P_RESIST_ACID", "P_RESIST_LIGHT", "P_RESIST_POISON", "P_INVULN"): w16(t, 0)
def clear(base, n):
    for i in range(n): wr(base + IS*i, bytes([0, 255] + [0]*12))
def put(base, slot, k, num=1, ident=0, toac=0):
    wr(base + IS*slot, bytes([k & 255, k >> 8, num, 0, 0, 1, 0, 0, ident, 0, 0, toac & 255, 0, 0]))
def floor_item(k, y, x):
    for i in range(64):
        b = 0xB400 + IS*i
        if rd(b + 1, 1)[0] == 255:
            wr(b, bytes([k & 255, k >> 8, 1, y, x, 1, 0, 0, 0, 0, 0, 0, 0, 0])); return b
def timers(*names): return [r16(n) for n in names]

# a caster: not unique, level about 20, no special resistances
R = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and 18 <= r["level"] <= 25 and not r["raw"][15] & 0x7F and not r["raw"][13] & 4)
LEV = RACES[R]["level"]
print("  caster:", NAMES[R], "level", LEV)
full(); no_resists()
wr(A["P_SAVE"], bytes([0x9C]))							# -100: never saves
wr(A["P_LEV"], bytes([1]))
y0, x0 = py()
dy, dx = open_line(3)
cy, cx = y0 + 2*dy, x0 + 2*dx

# ---- blink: 5 + teleport away a little
set_spells(R, [5]); place(0, R, cy, cx)
m = turn()
print("  blink:", repr(m), (cy, cx), "->", (mon(0)["y"], mon(0)["x"]))
expect(m.endswith("blinks away.") and (mon(0)["y"], mon(0)["x"]) != (cy, cx), "blink: '... blinks away.' and it moves")
calm()

# ---- teleport to
set_spells(R, [7])
far = open_line(3)
place(0, R, y0 + 3*far[0], x0 + 3*far[1])
m = turn(); p = py()
dd = max(abs(p[0] - mon(0)["y"]), abs(p[1] - mon(0)["x"]))
print("  teleport to:", repr(m), (y0, x0), "->", p, "monster at", (mon(0)["y"], mon(0)["x"]))
expect("commands you to return!" in m and dd <= 2, "teleport to: 'commands you to return!' and the player lands beside it")
calm()
wr(A["PLAYER_Y"], bytes([y0])); wr(A["PLAYER_X"], bytes([x0])); call(A["UPDATE_VIEW"])

# ---- light wounds, with and without a saving throw
set_spells(R, [8]); place(0, R, cy, cx)
h = hp(); m = turn()
print("  light wound:", repr(m), h, "->", hp())
expect("points at you and curses." in m and 3 <= h - hp() <= 24, "light wounds: 3d8 when the player fails to save")
wr(A["P_SAVE"], bytes([127])); h = hp(); m = turn()
expect("You resist the effects of the spell." in m and hp() == h, "light wounds: nothing when the player saves")
wr(A["P_SAVE"], bytes([0x9C]))
set_spells(R, [29]); h = hp(); m = turn()
expect("incanting terribly!" in m and 10 <= h - hp() <= 150, "critical wounds: 10d15")
full()

# ---- hold person: free action, then paralysis
set_spells(R, [10])
rflag(2, 0x80); wr(A["P_PARALYSED"], bytes([0])); m = turn()
expect("You are unaffected." in m and rd(A["P_PARALYSED"], 1)[0] == 0, "hold person: free action leaves the player unaffected")
rflag(2, 0); m = turn(); p = rd(A["P_PARALYSED"], 1)[0]
print("  hold:", repr(m), p)
expect("gazes deep into your eyes!" in m and 5 <= p <= 9, "hold person: paralysed 1d5 + 4")
m = turn()
expect(rd(A["P_PARALYSED"], 1)[0] == p + 2, "and 2 more if already paralysed")
wr(A["P_PARALYSED"], bytes([0]))

# ---- blindness, confusion, fear, slowness
set_spells(R, [11]); w16("P_BLIND", 0); m = turn(); b = r16("P_BLIND")
expect("burning your eyes!" in m and 13 <= b <= 15, "blindness: 12 + 1d3")
w16("P_BLIND", 0); rflag2(2, 0x80); m = turn()
expect("You blink and your vision clears." in m and r16("P_BLIND") == 0, "blindness: resisted by TR_RES_BLIND")
rflag2(2, 0)
set_spells(R, [12]); w16("P_CONFUSED", 0); m = turn(); c = r16("P_CONFUSED")
expect("mesmerising illusion" in m and 4 <= c <= 8, "confusion: 1d5 + 3")
w16("P_CONFUSED", 0); rflag2(1, 0x80); m = turn()
expect("You disbelieve the feeble spell." in m and r16("P_CONFUSED") == 0, "confusion: resisted by TR_RES_CONF")
rflag2(1, 0)
set_spells(R, [13]); w16("P_AFRAID", 5); m = turn()
expect("fearful illusion" in m and r16("P_AFRAID") == 7, "fear: 2 more turns when already afraid")
w16("P_AFRAID", 0)
set_spells(R, [16]); w16("P_SLOW", 0); m = turn(); s_ = r16("P_SLOW")
expect("drains power from your muscles!" in m and 4 <= s_ <= 8, "slow: 1d5 + 3")
w16("P_SLOW", 0)

# ---- drain mana
set_spells(R, [17]); w16("P_CMANA", 20); place(0, R, cy, cx, hp=100)
m = turn(); cm = r16("P_CMANA"); mh = mon(0)["hp"]
print("  drain mana:", repr(m), "mana 20 ->", cm, "monster hp 100 ->", mh)
expect("draws psychic energy from you!" in m and 20 - cm >= 1 and mh - 100 == 6 * (20 - cm), "drain mana: 1d(level)/2 + 1 drained, 6 x that healed")
w16("P_CMANA", 0); m = turn()
expect(m == "" and mon(0)["hp"] == mh, "drain mana: nothing to drain, nothing said")

# ---- heal self and haste self
set_spells(R, [46]); place(0, R, cy, cx, hp=10, maxhp=500)
m = turn()
expect("concentrates on its wounds." in m and "looks healthier." in m and mon(0)["hp"] == 10 + 6*LEV, "heal: + 6 x level")
place(0, R, cy, cx, hp=495, maxhp=500); m = turn()
expect("looks REALLY healthy!" in m and mon(0)["hp"] == 500, "heal: up to its maximum")
m = turn()
expect("looks as healthy as can be." in m, "heal: when already well")
set_spells(R, [47]); place(0, R, cy, cx)
m = turn()
print("  haste:", repr(m), mon(0)["speed"], "race speed", RACES[R]["raw"][8])
expect("casts a spell." in m and ("starts moving faster." in m) == (RACES[R]["raw"][8] <= 15 and 1 <= RACES[R]["raw"][8] - 10), "haste self: faster if not already")
calm()

# ---- fire breath: hp / 3, resisted, immune; the pack burns; so does the floor
no_resists(); full()
set_spells(R, [24]); place(0, R, cy, cx, hp=300)
h = hp(); m = turn()
print("  fire breath:", repr(m), h - hp())
expect("breathes fire." in m and h - hp() == 100, "fire breath: hp / 3")
rflag(2, 0x08); h = hp(); turn()
expect(h - hp() == 33, "resisting fire: a third")
w16("P_RESIST_HEAT", 10); h = hp(); turn()
expect(h - hp() == 11, "resisting twice over: a ninth")
rflag2(0, 0x40); h = hp(); turn()
expect(h - hp() == 1, "immune: 1")
no_resists(); full()
scroll = next(i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 3)
potion = next(i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 2)
fy, fx = y0 - dy, x0 - dx
fb = floor_item(scroll, fy, fx)
clear(A["PACK"], 12)
for i in range(12): put(A["PACK"], i, scroll, num=40)
gone = 0
for t in range(25):
    full()
    before = sum(r["num"] for r in pack() if r)
    m = turn()
    gone += before - sum(r["num"] for r in pack() if r)
print("  25 fire breaths at 12 stacks of scrolls:", gone, "destroyed")
expect(rd(fb + 1, 1)[0] == 255, "the scroll on the floor beside the player burns")
expect(1 <= gone <= 25, "scrolls in the pack burn, 3% a stack a breath")
full()

# ---- frost: potions shatter; poison gas poisons
set_spells(R, [23]); clear(A["PACK"], 12)
for i in range(12): put(A["PACK"], i, potion, num=40)
gone = 0; saw = False
for t in range(10):
    full(); before = sum(r["num"] for r in pack() if r); m = turn()
    gone += before - sum(r["num"] for r in pack() if r); saw |= "Something shatters inside your pack!" in m
expect(gone >= 1 and saw, "frost breath: potions shatter ('Something shatters inside your pack!')")
clear(A["PACK"], 12)
set_spells(R, [21]); place(0, R, cy, cx, hp=60); w16("P_POISONED", 0); full()
h = hp(); m = turn(); pz = r16("P_POISONED")
print("  gas:", repr(m), h - hp(), "poisoned", pz)
expect("breathes gas." in m and h - hp() == 20 and 13 <= pz <= 32, "gas: hp / 3, and poisoned 12 + 1d(dam)")
w16("P_POISONED", 0); rflag(3, 0x10); h = hp(); turn()
expect(h - hp() == 12 and r16("P_POISONED") == 0, "resisting poison: 3/5, and not poisoned")
no_resists()

# ---- acid: armour takes it
set_spells(R, [22]); place(0, R, cy, cx, hp=90); full()
clear(EQ, 10)
armour = next(i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 8 and k["raw"][9] > 0)
put(EQ, 1, armour, ident=5, toac=5)
h = hp(); m = turn(); toac = rd(EQ + IS*1 + 11, 1)[0]
print("  acid:", repr(m), h - hp(), "toac", toac)
expect("is damaged!" in m and toac == 4 and h - hp() == 15, "acid: the armour is damaged, and the player takes half")
clear(EQ, 10); h = hp(); m = turn()
expect(h - hp() == 30, "acid with no armour: all of it")

# ---- a bystander in the ball; a monster in the way of a bolt
calm(); full()
set_spells(R, [24]); place(0, R, y0 + 2*dy, x0 + 2*dx, hp=300)
by = (y0 - dy, x0 - dx); place(1, R, by[0], by[1], hp=200)
turn()
expect(mon(1)["hp"] == 200 - 50, "fire breath: a monster beside the player takes half")
calm()
set_spells(R, [26]); place(0, R, y0 + 3*dy, x0 + 3*dx, hp=300)
place(1, R, y0 + dy, x0 + dx, hp=200)
h = hp(); m = turn()
print("  bolt with a monster in the way:", repr(m), "player", h - hp(), "blocker", 200 - mon(1)["hp"])
expect("casts a Frost bolt." in m and hp() == h and 6 + LEV//3 <= 200 - mon(1)["hp"] <= 48 + LEV//3, "frost bolt: the monster in the way takes it")
calm(); set_spells(R, [26]); place(0, R, cy, cx)
h = hp(); turn()
expect(6 + LEV//3 <= h - hp() <= 48 + LEV//3, "frost bolt: 6d8 + level / 3 at the player")

# ---- summons
calm(); set_spells(R, [14]); place(0, R, cy, cx)
n0 = nmons(); m = turn()
print("  summon:", repr(m), n0, "->", nmons())
expect("magically summons help!" in m and nmons() > n0, "summon monster: help arrives")
calm(); set_spells(R, [62]); place(0, R, cy, cx)
m = turn(); new = [mon(i) for i in range(1, 64) if not mon(i)["free"]]
print("  spiders:", [NAMES[k["race"]] for k in new])
expect("magically summons Spiders." in m and new and all(RACES[k["race"]]["raw"][0] == ord("S") for k in new), "summon spiders: only 'S'")
calm(); set_spells(R, [15]); place(0, R, cy, cx)
m = turn(); new = [mon(i) for i in range(1, 64) if not mon(i)["free"]]
expect("beyond the grave" in m and new and all(RACES[k["race"]]["raw"][13] & 16 for k in new), "summon undead: undead")
calm()

# ---- teleported away; an exotic breath (9d-3b) leaves it to move
set_spells(R, [45]); place(0, R, cy, cx)
m = turn(); p = py()
print("  teleport away:", repr(m), (y0, x0), "->", p)
expect("teleports you away." in m and max(abs(p[0] - y0), abs(p[1] - x0)) > 3, "teleport away: the player goes")
calm(); wr(A["PLAYER_Y"], bytes([y0])); wr(A["PLAYER_X"], bytes([x0])); call(A["UPDATE_VIEW"])
calm()

# ---- intelligent and badly hurt: escapes, half the time
set_spells(R, [6, 25], smart=True)
blinks = 0
for t in range(40):
    place(0, R, cy, cx, hp=1, maxhp=300)
    m = turn(); blinks += "teleports away." in m
    calm()
print("  desperate teleports:", blinks, "of 40")
expect(blinks >= 24, "a desperate intelligent caster mostly teleports away (3/4 of the time)")

# =============================================================== 9d-3b
def exp(): return struct.unpack("<I", rd(A["P_EXP"], 4))[0]
def set_exp(v): wr(A["P_EXP"], struct.pack("<I", v))
def home():
    calm(); wr(A["PLAYER_Y"], bytes([y0])); wr(A["PLAYER_X"], bytes([x0])); call(A["UPDATE_VIEW"])
home(); full(); no_resists()
for t in ("P_CUT", "P_STUN", "P_CONFUSED", "P_SLOW", "P_BLIND"): w16(t, 0)

set_spells(R, [34]); place(0, R, cy, cx, hp=600)
h = hp(); m = turn()
print("  shards:", repr(m), h - hp(), "cut", r16("P_CUT"))
expect("breathes shards." in m and h - hp() == 100 and r16("P_CUT") >= 200, "shards: hp / 6, and cut by hp / 3")
w16("P_CUT", 0); rflag2(2, 0x20); h = hp(); turn()
expect(h - hp() == 100 and r16("P_CUT") == 0, "resisting shards: no cut")
no_resists(); full()
set_spells(R, [35]); h = hp(); m = turn()
expect("breathes sound." in m and h - hp() == 100 and 1 <= r16("P_STUN") <= 35, "sound: hp / 6 and stunned 1d35")
w16("P_STUN", 0)
set_spells(R, [36]); m = turn()
expect("breathes confusion." in m and 11 <= r16("P_CONFUSED") <= 30, "confusion breath: confused 1d20 + 10")
w16("P_CONFUSED", 0)
set_spells(R, [71]); h = hp(); m = turn()
expect("breathes plasma." in m and h - hp() == 100 and r16("P_STUN") >= 1, "plasma: hp / 6, stunned")
w16("P_STUN", 0); full()
set_spells(R, [66]); h = hp(); m = turn()
expect("breathes inertia." in m and "less able to move" in m and 4 <= r16("P_SLOW") <= 8, "inertia: slowed 1d5 + 3")
w16("P_SLOW", 0)
set_spells(R, [67]); w16("P_BLIND", 0); h = hp(); m = turn()
print("  light:", repr(m), h - hp(), "blind", r16("P_BLIND"))
expect(h - hp() == 100 and 4 <= r16("P_BLIND") <= 9 and "blinded by the flash" in m, "light: hp / 6, blinded 1d6 + 3")
w16("P_BLIND", 0); full()

# disenchantment: every armour slot worn, so one always loses a plus
armour = next(i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 8 and k["raw"][9] > 0)
clear(EQ, 10)
for sl in (1, 2, 3, 4, 5, 6): put(EQ, sl, armour, toac=5)
set_spells(R, [37]); m = turn()
acs = [rd(EQ + IS*sl + 11, 1)[0] for sl in (1, 2, 3, 4, 5, 6)]
print("  disenchant:", repr(m), acs)
expect("breathes disenchantment." in m and "static feeling" in m and sorted(acs)[0] in (3, 4) and sum(5 - a for a in acs) in (1, 2), "disenchantment: one piece loses 1d2 AC")
clear(EQ, 10); full()

# nether and chaos drain experience
set_spells(R, [38]); set_exp(10000); place(0, R, cy, cx, hp=600)
m = turn()
print("  nether:", repr(m), exp())
expect("breathes nether." in m and "draining away" in m and exp() == 10000 - 200 - 200, "nether: lose hp / 3 + exp / 100 * 2")
set_exp(10000); rflag2(3, 0x01); full(); h = hp(); turn()
expect(exp() == 10000 and h - hp() == 100, "resisting nether: hp / 6 (up to 300), no drain")
no_resists(); full()
set_spells(R, [51]); set_exp(10000); m = turn()
expect("casts a Nether bolt." in m and exp() == 10000 - 400, "nether bolt: lose 200 + exp / 100 * 2")
set_spells(R, [60]); set_exp(20000); full(); m = turn()
expect("casts a Nether Ball." in m and exp() == 20000 - 5000 - 400, "nether ball: lose 5000 + exp / 100 * 2")
full()
by = (y0 + 3*far[0] if False else None)
set_spells(R, [33]); set_exp(20000); w16("P_CONFUSED", 0)
other = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and r["level"] < 5 and i != R)
place(0, R, cy, cx, hp=600); place(1, R if False else other, y0 - dy, x0 - dx, hp=20)
m = turn()
print("  chaos:", repr(m), exp(), "confused", r16("P_CONFUSED"), "bystander", NAMES[other], "->", NAMES[mon(1)["race"]] if not mon(1)["free"] else "gone")
expect("breathes Chaos." in m and exp() == 20000 - 5000 - 400 and 11 <= r16("P_CONFUSED") <= 30, "chaos: drained and confused")
w16("P_CONFUSED", 0); calm(); full()

# the rest
set_spells(R, [72]); place(0, R, cy, cx); h = hp(); m = turn()
expect("fires an arrow at you." in m and 1 <= h - hp() <= 6, "arrow: 1d6")
set_spells(R, [75]); h = hp(); m = turn()
expect("invokes a Mana storm." in m and LEV*5 + 10 <= h - hp() <= LEV*5 + 100, "mana storm: level x 5 + 10d10")
full()
set_spells(R, [59]); w16("P_CONFUSED", 0); h = hp(); m = turn()
print("  whirlpool:", repr(m), h - hp(), r16("P_CONFUSED"))
expect(51 <= h - hp() <= 50 + LEV*5//2 and 7 <= r16("P_CONFUSED") <= 14, "whirlpool: 1d(level x 5 / 2) + 50, confused 1d8 + 6")
w16("P_CONFUSED", 0); w16("P_STUN", 0)
set_spells(R, [42]); m = turn()
expect(m.endswith("casts a spell."), "trap creation: only words (no traps yet)")
set_spells(R, [53]); m = turn()
expect("gestures in shadow." in m, "shadow: 'gestures in shadow.'")
full()
set_spells(R, [69]); w16("P_SLOW", 0); place(0, R, cy, cx, hp=600); h = hp(); m = turn(); p = py()
print("  gravity:", repr(m), h - hp(), "slow", r16("P_SLOW"), (y0, x0), "->", p)
expect(h - hp() == 200 and 4 <= r16("P_SLOW") <= 8 and "Gravity warps around you." in m, "gravity: hp / 3, slowed, moved")
w16("P_SLOW", 0); w16("P_STUN", 0); home(); full()
set_spells(R, [68]); set_exp(30000); place(0, R, cy, cx, hp=300)
st0 = list(rd(A["P_STAT"], 6)); m = turn(); st1 = list(rd(A["P_STAT"], 6))
print("  time:", repr(m), exp(), st0, "->", st1)
expect((exp() < 30000 or st1 != st0 or all(v <= 3 for v in st0)), "time: experience or stats lost")
wr(A["P_STAT"], bytes(st0)); full()

# teleport level: 1 in 3 when the player fails to save
set_spells(R, [57]); tl = None
for t in range(30):
    wr(A["P_NEW_LEVEL"], bytes([0])); lv = rd(A["DUN_LEVEL"], 1)[0]
    m = turn()
    if "through the" in m: tl = (m, lv, rd(A["DUN_LEVEL"], 1)[0], rd(A["P_NEW_LEVEL"], 1)[0]); break
    expect("feet firmly on the ground" in m, "teleport level resisted") if t == 0 else None
print("  teleport level:", tl)
expect(tl and tl[3] == 3 and abs(tl[2] - tl[1]) == 1 and (("sink" in tl[0]) == (tl[2] > tl[1])), "teleport level: up or down a level, said so")
if tl: wr(A["DUN_LEVEL"], bytes([tl[1]]))
wr(A["P_NEW_LEVEL"], bytes([0]))

# forgetting: what's known of the pack's pluses, and the map
set_spells(R, [54]); clear(A["PACK"], 12); put(A["PACK"], 0, armour, ident=4)
got = False
for t in range(20):
    m = turn()
    if "Your memories fade away." in m: got = True; break
mm = rd(0xC000, W*66)
print("  forget:", got, "ident", rd(A["PACK"] + 8, 1)[0], "remembered squares", sum(1 for b in mm if b & 0x20))
expect(got and rd(A["PACK"] + 8, 1)[0] & 4 == 0, "forget: the pack's pluses are unknown again")
clear(A["PACK"], 12)

# summons
for casts, test, what in ((76, lambda r: r["raw"][0] == ord("R"), "reptiles: 'R'"),
                          (77, lambda r: r["raw"][0] == ord("a"), "ants: 'a'"),
                          (78, lambda r: (r["raw"][13] & 1 and r["raw"][0] != ord("P")) or r["raw"][0] == ord("J"), "special opponents: uniques (not 'P') and jabberwocks"),
                          (73, lambda r: r["raw"][0] in b"LVW", "mighty undead: wraiths and greater undead")):
    home(); set_spells(R, [casts]); place(0, R, cy, cx)
    m = turn(); new = [mon(i) for i in range(1, 64) if not mon(i)["free"]]
    print("  summon", casts, repr(m), [NAMES[k["race"]] for k in new][:8])
    expect("?" not in m and m.startswith("The "), "summon %d: its words" % casts)
    expect(new and all(test(RACES[k["race"]]) for k in new), "summon " + what)
home()

# elemental force: 1 in 10 it brings the cave down
set_spells(R, [65]); wall = None
for t in range(60):
    full(); place(0, R, cy, cx, hp=600); p0 = py(); h = hp()
    m = turn()
    if any(w in m for w in ("ceiling collapses", "turns and crushes", "pummeled with debris", "rubble bashes", "nimbly dodge", "against the ceiling", "trapped, crushed")):
        wall = (m, p0, py(), rd(0xC000 + p0[0]*W + p0[1], 1)[0] & 15, h - hp()); break
    expect("breathes elemental force." in m and h - hp() == 100, "force: hp / 6") if t == 0 else None
    calm()
print("  force:", wall)
expect(wall and wall[1] != wall[2] and wall[3] in (3, 12, 13) and wall[4] in (0,) + tuple(range(10, 41)), "force: the player is pushed aside and their square fills with rock")
cmd(2)
print("ALL OK" if ok else "FAILURES")
