import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
IS = 14
EQ = A["EQUIP"]
def put(slot, k, n=1, ident=0, hit=0, dam=0, ac=0, base=None):
    base = A["PACK"] if base is None else base
    wr(base + IS*slot, bytes([k & 255, k >> 8, n, 0, 0, 1, 0, 0, ident, hit & 255, dam & 255, ac & 255, 0, 0]))
def clear_pack():
    for i in range(12): wr(A["PACK"] + IS*i, bytes([0, 255] + [0]*12))
def rec(addr):
    r = rd(addr, IS); sg = lambda v: v - 256 if v > 127 else v
    return dict(kind=r[0] | r[1] << 8, num=r[2], ident=r[8], hit=sg(r[9]), dam=sg(r[10]), ac=sg(r[11]), name2=r[12], feel=r[13])
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
INV, EQUIPC, WIELD, TAKEOFF, READ = 4, 5, 6, 7, 13
def lines_of(shot): return [l.strip() for l in shot if re.match(r"\s*[a-l]\) ", l)]
def tick(n=1):
    for _ in range(n): act(3)
def calm():
    for i in range(64):
        b = 0xB000 + 16*i
        if rd(b + 12, 1)[0] != 255:
            y, x = rd(b + 1, 2); wr(0xC000 + y*198 + x, bytes([rd(0xC000 + y*198 + x, 1)[0] & 0x7F])); wr(b + 12, bytes([255]))
calm()
dagger, mail = KIDX["Dagger"], KIDX["Chain Mail"]
ID_STORE, ID_KNOWN2, ID_CURSED, ID_DAMD, ID_MAGIK, SHOWHD = 1, 4, 8, 16, 32, 64

# ---- magic_treasure: plus distribution at level 30 against the C's odds
SCR = 0xBDC0 + 0x80						# a scratch record in the harness area
stats = dict(plus=0, minus=0, plain=0, cursed=0)
for t in range(300):
    set_reg(5, dagger); set_reg(2, 30 << 8)		# HL = kind, A = level
    cmd(4, bytes([6]) + struct.pack("<H", SCR))	# IX
    cmd(10, bytes([2, 41])); call(A["NEW_ITEM"])
    r = rec(SCR)
    if r["ident"] & ID_CURSED: stats["cursed"] += 1; assert r["hit"] < 0 and r["dam"] < 0
    elif r["hit"] > 0 or r["dam"] > 0: stats["plus"] += 1
    else: stats["plain"] += 1
print("  level 30 daggers:", stats)
# chance 45%, then cursed 1 in (10*45/13 = 34)% of the rest: 45% magic, ~19% cursed
expect(105 <= stats["plus"] + 0 <= 165 and 30 <= stats["cursed"] <= 85, "pluses and curses come about as often as magic_treasure makes them")
# ---- names: pluses only once known
clear_pack(); put(0, dagger, ident=SHOWHD, hit=3, dam=2); put(1, dagger, ident=ID_KNOWN2 | SHOWHD, hit=3, dam=2)
put(2, mail, ident=ID_KNOWN2, ac=4); put(3, mail, ident=ID_KNOWN2 | ID_CURSED | ID_DAMD, ac=-3)
shot = keyed(INV, " ", capture=True); ls = lines_of(shot)
print("  pack:", ls)
expect(ls[:4] == ["a) a Dagger (1d4)", "b) a Dagger (1d4) (+3,+2)", "c) Chain Mail (-2,+0) [32,+4]", "d) Chain Mail (-2,+0) [32,-3] {cursed}"] or
       (ls[0] == "a) a Dagger (1d4)" and ls[1] == "b) a Dagger (1d4) (+3,+2)" and ls[2].endswith(",+4]") and ls[3].endswith("{cursed}")),
       "pluses shown once known: (+3,+2), [ac,+4], {cursed}")
# ---- wielding a cursed dagger
clear_pack(); put(0, dagger, ident=ID_CURSED, hit=-4, dam=-5)
keyed(WIELD, "a")
m = msgline(); print("  wield cursed ->", repr(m))
expect(eq(0)["kind"] == dagger and eq(0)["ident"] & ID_DAMD, "a cursed Dagger: 'Oops! It feels deathly cold!' and it's known cursed")
th = r8("P_TOHIT")
keyed(TAKEOFF, "a")
expect(eq(0)["kind"] == dagger and "seems to be cursed" in msgline(), "'Hmmm, it seems to be cursed.': it won't come off")
clear_pack(); put(0, KIDX["Broadsword"])
keyed(WIELD, "a")
print("  replace ->", repr(msgline()))
expect(eq(0)["kind"] == dagger and "you are wielding appears to be cursed" in msgline(), "nor can it be replaced")
# ---- remove curse
clear_pack(); put(0, KIDX["Scroll of Remove Curse"], ident=ID_STORE)
keyed(READ, "a")
expect(not eq(0)["ident"] & ID_CURSED, "Remove Curse lifts it")
keyed(TAKEOFF, "a")
expect(eq(0)["kind"] == 0xFF00 or eq(0)["kind"] >> 8 == 0xFF, "and it comes off")
# ---- enchant, curse
clear_pack(); put(0, dagger, ident=ID_KNOWN2); keyed(WIELD, "a")
put(0, KIDX["Scroll of Enchant Weapon To-Hit"], ident=ID_STORE); keyed(READ, "a")
print("  enchant ->", repr(msgline()), eq(0))
expect(eq(0)["hit"] == 1, "Enchant Weapon To-Hit: +0 always becomes +1")
put(0, KIDX["Scroll of Enchant Weapon To-Dam"], ident=ID_STORE); keyed(READ, "a")
expect(eq(0)["dam"] == 1, "Enchant Weapon To-Dam likewise")
put(0, KIDX["Scroll of Curse Weapon"], ident=ID_STORE); keyed(READ, "a")
e = eq(0); print("  curse weapon ->", e)
expect(e["ident"] & ID_CURSED and -10 <= e["hit"] <= -2 and -10 <= e["dam"] <= -2, "Curse Weapon: -2d5 each, cursed")
put(0, KIDX["Scroll of Enchant Weapon To-Hit"], ident=ID_STORE); keyed(READ, "a")
expect(not eq(0)["ident"] & ID_CURSED and eq(0)["hit"] == e["hit"] + 1, "enchanting a cursed weapon lifts the curse")
ac0 = eq(1)["ac"]
put(0, KIDX["Scroll of Enchant Armour"], ident=ID_STORE); keyed(READ, "a")
expect(eq(1)["ac"] in (ac0, ac0 + 1), "Enchant Armour on the Chain Mail (the only armour worn)")
# ---- identify reveals pluses
clear_pack(); put(0, KIDX["Scroll of Identify"], ident=ID_STORE); put(1, dagger, ident=SHOWHD, hit=2, dam=1)
keyed(READ, "ab")
shot = keyed(INV, " ", capture=True); ls = lines_of(shot)
print("  identified:", ls)
expect(any("Dagger (1d4) (+2,+1)" in l for l in ls), "Identify shows the pluses")
# ---- the warrior's sense: wielded, always; in the pack, 1 in 5
wr(A["P_CLASS"], bytes([0])); wr(A["P_LEV"], bytes([50]))
clear_pack()
put(0, dagger, hit=4, dam=3, base=EQ); wr(A["P_UPDATE"], bytes([1]))
for t in range(60):
    tick()
    if eq(0)["feel"]: break
m = msgline(); print("  after", t + 1, "turns:", eq(0), repr(m))
expect(eq(0)["feel"] == 2, "a warrior feels the Dagger they're wielding is good")
shot = keyed(EQUIPC, " ", capture=True)
expect(any("Dagger (1d4) {good}" in l for l in shot), "and it's inscribed {good}")
put(0, dagger, base=EQ)
for t in range(60):
    tick()
    if eq(0)["feel"]: break
expect(eq(0)["feel"] == 1, "a plain one is average")
put(0, dagger, ident=ID_CURSED, hit=-2, dam=-2, base=EQ)
for t in range(60):
    tick()
    if eq(0)["ident"] & ID_DAMD: break
expect(eq(0)["ident"] & ID_DAMD, "a cursed one feels worthless (and is known cursed)")
cmd(2)
print("ALL OK" if ok else "FAILURES")
