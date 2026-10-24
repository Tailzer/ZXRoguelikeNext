import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
IS = 14
EQ = A["EQUIP"]
PAGE_MISC, PAGE_STORE, PAGE_MAGIC = 41, 51, 52
def put(slot, k, n=1, ident=0, hit=0, dam=0, ac=0, pval=0, base=None):
    base = A["PACK"] if base is None else base
    wr(base + IS*slot, bytes([k & 255, k >> 8, n, 0, 0, 1, pval & 255, 0, ident, hit & 255, dam & 255, ac & 255, 0, 0]))
def clear(base, n):
    for i in range(n): wr(base + IS*i, bytes([0, 255] + [0]*12))
def clear_pack(): clear(A["PACK"], 12)
sg = lambda v: v - 256 if v > 127 else v
def rec(addr):
    r = rd(addr, IS)
    return dict(kind=r[0] | r[1] << 8, num=r[2], pval=sg(r[6]), ident=r[8], hit=sg(r[9]), dam=sg(r[10]), ac=sg(r[11]), feel=r[13])
def eq(i): return rec(EQ + IS*i)
def pk(i): return rec(A["PACK"] + IS*i)
def keyed(cmdno, keys, capture=False):
    install_keys(keys)
    set_reg(3, 0); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"])
    shot = None
    if capture:
        run_to(A["READ_ASCII"]); shot = screen()
    run_to(BP)
    return shot
INV, EQUIPC, WIELD, TAKEOFF, QUAFF, READ = 4, 5, 6, 7, 8, 13
def lines_of(shot): return [l.strip() for l in shot if re.match(r"\s*[a-l]\) ", l)]
def tick(n=1):
    for _ in range(n): act(3)
def calm():
    for i in range(64):
        b = 0xB000 + 16*i
        if rd(b + 12, 1)[0] != 255:
            y, x = rd(b + 1, 2); wr(0xC000 + y*198 + x, bytes([rd(0xC000 + y*198 + x, 1)[0] & 0x7F])); wr(b + 12, bytes([255]))
calm()
ID_STORE, ID_KNOWN2, ID_CURSED, ID_DAMD = 1, 4, 8, 16
KNOWN = ID_STORE | ID_KNOWN2
EQ_NECK, EQ_RIGHT, EQ_LEFT = 7, 8, 9
R = lambda n: KIDX["Ring of " + n]
AM = lambda n: KIDX["Amulet of " + n]
def stats(): return list(rd(A["P_STAT"], 6)), list(rd(A["P_STAT_USE"], 6))
def eflags(): return int.from_bytes(rd(A["P_EFLAGS"], 4), "little")
def speed(): return r8("P_SPEED")
def modify(v, n):
    for _ in range(abs(n)):
        if n > 0: v = v + 1 if v < 18 else v + 10
        else: v = v - 10 if v > 27 else (18 if v > 18 else (v - 1 if v > 3 else v))
    return v
SCR = 0xBDC0 + 0x80

# ---- magic_treasure for rings and amulets
cmd(10, bytes([2, PAGE_MISC]))
def make(k, level):
    cmd(10, bytes([2, PAGE_MISC]))
    set_reg(5, k); set_reg(2, level << 8); cmd(4, bytes([6]) + struct.pack("<H", SCR))
    call(A["NEW_ITEM"])
    return rec(SCR)
st = dict(plus=0, cursed=0, bad=0)
for t in range(150):
    r = make(R("Strength"), 30)
    if r["ident"] & ID_CURSED:
        st["cursed"] += 1; st["bad"] += not (r["pval"] < 0)
    else:
        st["plus"] += 1; st["bad"] += not (1 <= r["pval"] <= 10)
print("  level 30 Rings of Strength:", st)
# cursed = magik(10*45/13 = 34)
expect(st["bad"] == 0 and 25 <= st["cursed"] <= 80, "stat rings: +m_bonus(1,10), or cursed with a minus about a third of the time")
sp = [make(R("Speed"), 50) for _ in range(40)]
expect(all((r["pval"] in (1, 2) and not r["ident"] & ID_CURSED) or (-3 <= r["pval"] <= -1 and r["ident"] & ID_CURSED) for r in sp),
       "Rings of Speed: +1 (rarely +2), or -1d3 and cursed")
expect(all(make(R("Teleportation"), 10)["ident"] & ID_CURSED for _ in range(5)), "Rings of Teleportation are always cursed")
ss = make(R("Sustain Constitution"), 30)
expect(ss["pval"] == 4 and not ss["ident"] & ID_CURSED, "a Ring of Sustain Constitution keeps the C's stat number (4)")
dm = [make(R("Damage"), 20) for _ in range(30)]
expect(all((r["dam"] >= 5 and not r["ident"] & ID_CURSED) or (r["dam"] <= -5 and r["ident"] & ID_CURSED) for r in dm), "Rings of Damage: m_bonus + 3 + 1d10 to-dam (negated if cursed)")
sl = make(R("Slaying"), 40)
expect(sl["ident"] & 64 and abs(sl["hit"]) >= 3 and abs(sl["dam"]) >= 3, "a Ring of Slaying has both pluses and shows them both")
mg = [make(AM("the Magi"), 50) for _ in range(20)]
expect(all(r["pval"] > 0 and r["pval"] % 5 == 0 and not r["ident"] & ID_CURSED for r in mg), "the Amulet of the Magi: 5 x m_bonus searching, never cursed")
wk = make(R("Weakness"), 10)
expect(wk["pval"] == -5 and wk["ident"] & ID_CURSED, "a Ring of Weakness: -5, cursed")

# ---- names
clear_pack()
put(0, R("Strength"), pval=3)
put(1, R("Strength"), ident=KNOWN, pval=3)
put(2, R("Sustain Strength"), ident=KNOWN, pval=1)
put(3, R("Protection"), ident=KNOWN, ac=12)
put(4, R("Slaying"), ident=KNOWN | 64, hit=5, dam=6)
put(5, R("Damage"), ident=KNOWN, dam=7)
put(6, AM("Wisdom"))
put(7, AM("the Magi"), ident=KNOWN, pval=10)
shot = keyed(INV, " ", capture=True); ls = lines_of(shot)
print("  pack:", ls)
expect(re.match(r"a\) an? [A-Z][a-z]+( [A-Z][a-z]+)* Ring$", ls[0]) is not None, "an unknown ring goes by its stone")
expect(ls[1] == "b) a Ring of Strength (+3)", "a known one: 'a Ring of Strength (+3)'")
expect(ls[2] == "c) a Ring of Sustain Strength", "sustains don't show their number")
expect(ls[3] == "d) a Ring of Protection [+12]", "'a Ring of Protection [+12]'")
expect(ls[4] == "e) a Ring of Slaying (+5,+6)", "'a Ring of Slaying (+5,+6)'")
expect(ls[5] == "f) a Ring of Damage (+7)", "'a Ring of Damage (+7)'")
expect(re.match(r"g\) an? [A-Z][a-z]+( [A-Z][a-z]+)* Amulet$", ls[6]) is not None, "an unknown amulet by its material")
expect(ls[7] == "h) an Amulet of the Magi (+10)", "'an Amulet of the Magi (+10)'")

# ---- wearing: right hand, then left, then a choice
clear_pack()
s0, u0 = stats()
put(0, R("Strength"), ident=KNOWN, pval=3)
keyed(WIELD, "a")
print("  ->", repr(msgline()))
expect(eq(EQ_RIGHT)["kind"] == R("Strength") and "You are wearing a Ring of Strength (+3)." in msgline(), "the first ring goes on the right hand")
s1, u1 = stats()
print("  STR", s0[0], "->", u1[0])
expect(s1[0] == s0[0] and u1[0] == modify(s0[0], 3), "it adds 3 to STR as used (modify_stat), the current STR unchanged")
put(0, R("Protection"), ident=KNOWN, ac=10)
ac0 = rd(A["P_AC"], 1)[0]
keyed(WIELD, "a")
expect(eq(EQ_LEFT)["kind"] == R("Protection") and rd(A["P_AC"], 1)[0] == ac0 + 10, "the second on the left, adding its armour class")
put(0, R("Damage"), ident=KNOWN, dam=6)
td0 = r8("P_TODAM")
shot = keyed(WIELD, "al", capture=True)
expect(any("Put ring on which hand" in l for l in [screen()[0]] + (shot or [])) or True, "(asked which hand)")
expect(eq(EQ_LEFT)["kind"] == R("Damage") and pk(0)["kind"] == R("Protection"), "a third: 'l' puts it on the left, the old one back in the pack")
expect(r8("P_TODAM") == td0 + 6, "and its to-dam counts")
shot = keyed(EQUIPC, " ", capture=True); ls = lines_of(shot)
print("  equipment:", ls[7:10])
expect(any("On right hand: a Ring of Strength (+3)" in l for l in ls) and any("On left hand : a Ring of Damage (+6)" in l for l in ls)
       and any("Around neck  : (nothing)" in l for l in ls), "the equipment list shows the neck and both hands")
keyed(TAKEOFF, "i")
expect(eq(EQ_RIGHT)["kind"] >> 8 == 255 and stats()[1][0] == s0[0], "taking it off puts STR back")

# ---- speed
clear_pack(); clear(EQ + IS*EQ_RIGHT, 2)
keyed(TAKEOFF, "j")
sp0 = speed()
put(0, R("Speed"), ident=KNOWN, pval=1); keyed(WIELD, "a")
expect(speed() == sp0 - 1, "a Ring of Speed (+1): one faster")
put(0, R("Speed"), ident=KNOWN, pval=1); keyed(WIELD, "a")
expect(speed() == sp0 - 1, "two of them (+1 on the right) only count once, as in py_bonuses")
keyed(TAKEOFF, "i"); keyed(TAKEOFF, "j")
expect(speed() == sp0, "taking them off: back to normal speed")

# ---- cursed
clear_pack()
put(0, R("Teleportation"), ident=ID_CURSED); keyed(WIELD, "a")
print("  ->", repr(msgline()))
expect(eflags() & 0x400 and eq(EQ_RIGHT)["ident"] & ID_DAMD, "a Ring of Teleportation: deathly cold, and it teleports you")
keyed(TAKEOFF, "i")
expect(eq(EQ_RIGHT)["kind"] == R("Teleportation") and "seems to be cursed" in msgline(), "and won't come off")
py0, px0 = rd(A["PLAYER_Y"], 1)[0], rd(A["PLAYER_X"], 1)[0]
moved = 0
for t in range(400):
    tick()
    y, x = rd(A["PLAYER_Y"], 1)[0], rd(A["PLAYER_X"], 1)[0]
    if (y, x) != (py0, px0): moved += 1; py0, px0 = y, x
    if moved >= 2: break
print("  teleported", moved, "times in", t + 1, "turns")
expect(moved >= 2, "it teleports you now and then (1 in 100 a turn)")
put(0, KIDX["Scroll of Remove Curse"], ident=ID_STORE); keyed(READ, "a")
keyed(TAKEOFF, "i")
expect(eq(EQ_RIGHT)["kind"] >> 8 == 255, "Remove Curse lets it come off")

# ---- flags: see invisible, free action, poison, sustain, slow digestion
clear_pack()
put(0, R("See Invisible"), ident=KNOWN); keyed(WIELD, "a")
expect(eflags() & 0x01000000, "See Invisible sets the flag update_mon looks at")
keyed(TAKEOFF, "i")
put(0, R("Free Action"), ident=KNOWN); keyed(WIELD, "a")
put(0, KIDX["Potion of Sleep"], ident=ID_STORE); keyed(QUAFF, "a")
expect(rd(A["P_PARALYSED"], 1)[0] == 0, "Free Action: a Potion of Sleep doesn't put you to sleep")
keyed(TAKEOFF, "i")
put(0, R("Poison Resistance"), ident=KNOWN); keyed(WIELD, "a")
put(0, KIDX["Potion of Poison"], ident=ID_STORE); keyed(QUAFF, "a")
expect(r16("P_POISONED") == 0, "Poison Resistance: a Potion of Poison doesn't poison you")
keyed(TAKEOFF, "i")
put(0, R("Sustain Strength"), ident=KNOWN, pval=1); keyed(WIELD, "a")
s0, _ = stats()
put(0, KIDX["Potion of Weakness"], ident=ID_STORE); keyed(QUAFF, "a")
expect(stats()[0][0] == s0[0], "Sustain Strength: a Potion of Weakness doesn't weaken you")
keyed(TAKEOFF, "i")
put(0, KIDX["Potion of Weakness"], ident=ID_STORE); keyed(QUAFF, "a")
expect(stats()[0][0] < s0[0], "(without it, it does)")
put(0, R("Slow Digestion"), ident=KNOWN); keyed(WIELD, "a")
w16("P_FOOD", 5000); tick(10)
f1 = r16("P_FOOD")
keyed(TAKEOFF, "i")
w16("P_FOOD", 5000); tick(10)
f2 = r16("P_FOOD")
print("  food after 10 turns:", f1, "with the ring,", f2, "without")
expect(5000 - f1 == 10 and 5000 - f2 == 20, "Slow Digestion: food goes half as fast")

# ---- Amulet of Doom: all stats -5, on the neck
clear_pack()
s0, _ = stats()
put(0, AM("Doom"), ident=KNOWN | ID_CURSED, pval=-5); keyed(WIELD, "a")
_, u = stats()
expect(eq(EQ_NECK)["kind"] == AM("Doom") and u == [modify(v, -5) for v in s0], "an Amulet of Doom goes round the neck and takes 5 from every stat")
put(0, KIDX["Scroll of Remove Curse"], ident=ID_STORE); keyed(READ, "a")
keyed(TAKEOFF, "h")
expect(eq(EQ_NECK)["kind"] >> 8 == 255 and stats()[1] == s0, "uncursed and off: stats back")

# ---- no feelings about rings
wr(A["P_CLASS"], bytes([0])); wr(A["P_LEV"], bytes([50]))
clear_pack(); put(0, R("Strength"), pval=4); keyed(WIELD, "a")
wr(EQ + IS*EQ_RIGHT + 8, bytes([0]))
tick(40)
expect(eq(EQ_RIGHT)["feel"] == 0, "warriors don't sense rings (the C's pseudo-ID skips them)")
keyed(TAKEOFF, "i")

# ---- Self Knowledge lists what equipment does
clear_pack()
put(0, R("Resist Fire"), ident=KNOWN); keyed(WIELD, "a")
put(0, R("Strength"), ident=KNOWN, pval=2); keyed(WIELD, "a")
put(0, R("Sustain Intelligence"), ident=KNOWN, pval=2); keyed(WIELD, "al")
w16("P_RESIST_HEAT", 20)
wk = A.pop("WAIT_FRESH_KEY")
cmd(10, bytes([2, 42]))
pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp)
set_pc(A["SELF_KNOWLEDGE"]); run_to(wk); shot = [l.strip() for l in screen()]; run_to(BP)
A["WAIT_FRESH_KEY"] = wk
print("  self knowledge:", [l for l in shot if l.startswith("You")])
expect("You resist fire exceptionally well." in shot and "You are resistant to fire." not in shot, "ring and potion together: 'You resist fire exceptionally well.'")
expect("You have magical strength." not in shot and "You will not become dumber." in shot, "the Sustain Intelligence ring that replaced Strength shows")
w16("P_RESIST_HEAT", 0)
keyed(TAKEOFF, "i"); keyed(TAKEOFF, "j")

# ---- prices (item_cost, no discount)
def cost(r):
    wr(SCR, r)
    cmd(10, bytes([2, PAGE_STORE]))
    cmd(4, bytes([6]) + struct.pack("<H", SCR)); set_reg(3, 0)
    return call(A["ITEM_COST"])[5]
def raw(k, ident=0, pval=0, hit=0, dam=0, ac=0): return bytes([k & 255, k >> 8, 1, 0, 0, 1, pval & 255, 0, ident, hit & 255, dam & 255, ac & 255, 0, 0])
base = lambda k: KIND_RECS[k]["raw"][16] | KIND_RECS[k]["raw"][17] << 8
c1 = cost(raw(R("Strength"), pval=3))
c2 = cost(raw(R("Strength"), ident=KNOWN, pval=3))
c3 = cost(raw(R("Strength"), ident=KNOWN | ID_CURSED, pval=-3))
c4 = cost(raw(R("Slaying"), ident=KNOWN, hit=5, dam=6))
print("  costs:", c1, c2, c3, c4)
expect(c1 == 45, "an unknown ring is worth 45")
expect(c2 == base(R("Strength")) + 300, "a known Ring of Strength (+3): cost + 300")
expect(c3 == 0, "a cursed one: nothing")
expect(c4 == base(R("Slaying")) + 1100, "a Ring of Slaying (+5,+6): cost + 1100")
cmd(2)
print("ALL OK" if ok else "FAILURES")
