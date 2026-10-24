import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
EGOS_SRC = open(_os.path.join(_GAME, "data", "egos.asm")).read()
SN = {m.group(1): int(m.group(2)) for m in re.finditer(r"^(SN_\w+)\t+equ (\d+)", EGOS_SRC, re.M)}
EREC = [([int(x) for x in m.group(1).split(",")], [int(x) for x in m.group(2).split(",")])
        for m in re.finditer(r"\tdb ([\d,]+)\n\tdw \w+\n\tdb ([\d,]+)", EGOS_SRC)]
ENAME = {int(m.group(1)): m.group(2) for m in re.finditer(r'^egn_(\d+):\tdb "(.*)",0', EGOS_SRC, re.M)}
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
IS = 14
EQ = A["EQUIP"]
PAGE_MISC, PAGE_ITEMS, PAGE_STORE = 41, 42, 51
sg = lambda v: v - 256 if v > 127 else v
def raw(k, ident=0, hit=0, dam=0, ac=0, pval=0, ego=0, n=1):
    return bytes([k & 255, k >> 8, n, 0, 0, 1, pval & 255, 0, ident, hit & 255, dam & 255, ac & 255, ego, 0])
def put(slot, k, base=None, **kw): wr((A["PACK"] if base is None else base) + IS*slot, raw(k, **kw))
def clear(base, n):
    for i in range(n): wr(base + IS*i, bytes([0, 255] + [0]*12))
def rec(addr):
    r = rd(addr, IS)
    return dict(kind=r[0] | r[1] << 8, pval=sg(r[6]), ident=r[8], hit=sg(r[9]), dam=sg(r[10]), ac=sg(r[11]), ego=r[12], feel=r[13])
def eq(i): return rec(EQ + IS*i)
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
for i in range(64):
    b = 0xB000 + 16*i
    if rd(b + 12, 1)[0] != 255:
        y, x = rd(b + 1, 2); wr(0xC000 + y*198 + x, bytes([rd(0xC000 + y*198 + x, 1)[0] & 0x7F])); wr(b + 12, bytes([255]))
ID_STORE, ID_KNOWN2, ID_CURSED, SHOWHD = 1, 4, 8, 64
KNOWN = ID_STORE | ID_KNOWN2
SCR = 0xBDC0 + 0x80
inv = {v: k for k, v in SN.items()}
is_art = lambda e: e and EREC[e][0][12] & 8
def make(k, level, entry="NEW_ITEM"):
    cmd(10, bytes([2, PAGE_MISC]))
    set_reg(5, k); set_reg(2, level << 8); cmd(4, bytes([6]) + struct.pack("<H", SCR))
    call(A[entry]); return rec(SCR)
def made(sn): return rd(A["ART_MADE"] + sn // 8, 1)[0] >> (sn % 8) & 1

# ---- make_artifact: Longswords until one is made, with the C's numbers
cmd(10, bytes([2, PAGE_MISC]))
got = []
for t in range(200):
    wr(SCR, raw(KIDX["Longsword"]))
    cmd(4, bytes([6]) + struct.pack("<H", SCR)); set_reg(5, A["ART_TABLE"])
    r = call(A["MAKE_ARTIFACT"])
    if r[2] & 1:
        got.append(rec(SCR)["ego"])
print("  Longsword artifacts made:", [inv[e] for e in got])
expect(set(got) <= {SN["SN_RINGIL"], SN["SN_ANDURIL"], SN["SN_ANGUIREL"], SN["SN_ELVAGIL"]} and len(got) == len(set(got)) and len(got) >= 3,
       "Longswords become Ringil, Anduril, Anguirel or Elvagil, each only once")
expect(all(made(e) for e in got), "and each is marked made")
# the numbers: force Anduril (if it wasn't made, its bit is clear: make it now by clearing others)
wr(SCR, raw(KIDX["Longsword"], ac=2))
for e in (SN["SN_RINGIL"], SN["SN_ANGUIREL"], SN["SN_ELVAGIL"]):
    v = rd(A["ART_MADE"] + e // 8, 1)[0]; wr(A["ART_MADE"] + e // 8, bytes([v | 1 << e % 8]))
v = rd(A["ART_MADE"] + SN["SN_ANDURIL"] // 8, 1)[0]; wr(A["ART_MADE"] + SN["SN_ANDURIL"] // 8, bytes([v & ~(1 << SN["SN_ANDURIL"] % 8)]))
for t in range(100):
    cmd(4, bytes([6]) + struct.pack("<H", SCR)); set_reg(5, A["ART_TABLE"])
    if call(A["MAKE_ARTIFACT"])[2] & 1: break
an = rec(SCR)
print("  Anduril:", an)
expect(an["ego"] == SN["SN_ANDURIL"] and an["hit"] == 10 and an["dam"] == 15 and an["pval"] == 4 and an["ac"] == 5,
       "Anduril: (+10,+15), 4 STR, AC set to 5 (the C's toac = 5)")

# ---- shops never make artifacts; magic_treasure does now and then
arts = [make(KIDX["Dagger"], 40, "NEW_STORE_ITEM")["ego"] for _ in range(150)]
expect(not any(is_art(e) for e in arts), "a shop's Daggers are never artifacts")
wr(A["ART_MADE"], bytes(24))
found = set()
for k in ("Dagger", "Set of Leather Gloves", "Metal Cap", "Cloak"):
    for _ in range(250):
        e = make(KIDX[k], 50)["ego"]
        if is_art(e): found.add(inv[e])
print("  artifacts from 1000 level-50 items:", sorted(found))
expect(len(found) >= 2, "magic_treasure makes artifacts from daggers, gloves, caps and cloaks")

# ---- names and what they do
clear(A["PACK"], 12)
put(0, KIDX["Longsword"], ident=KNOWN | SHOWHD, hit=22, dam=25, pval=1, ego=SN["SN_RINGIL"])
put(1, KIDX["Longsword"], ident=SHOWHD, hit=22, dam=25, pval=1, ego=SN["SN_RINGIL"])
shot = keyed(INV, " ", capture=True); ls = lines_of(shot)
print("  pack:", ls)
expect(ls[0] == "a) a Longsword named Ringil (4d5) (+22,+25)" and ls[1] == "b) a Longsword (4d5)", "'a Longsword named Ringil (4d5) (+22,+25)' once known (its 4 dice show anyway, as in the C)")
sp0 = r8("P_SPEED")
keyed(WIELD, "a")
print("  wielding ->", repr(msgline()), "dice", rd(A["W_DICE"], 1)[0], rd(A["W_SIDES"], 1)[0])
f1, f2 = int.from_bytes(rd(A["P_EFLAGS"], 4), "little"), int.from_bytes(rd(A["P_EFLAGS2"], 4), "little")
expect(rd(A["W_DICE"], 1)[0] == 4 and r8("P_SPEED") == sp0 - 1 and f1 & 0x01000000 and f1 & 0x800, "Ringil: 4d5, +1 speed, see invisible, regeneration")
set_reg(5, next(i for i, r in enumerate(RACES) if r["raw"][13] & 16)); call(A["RACE_ADDR"]); set_reg(5, 10)
expect(call(A["TOT_DAM"])[5] == 30, "and x3 against undead")

# ---- curses: Remove Curse can't touch Calris; nothing touches the One Ring
clear(A["PACK"], 12)
cal = EREC[SN["SN_CALRIS"]][0]
put(0, KIDX["Bastard Sword"], ident=ID_CURSED | SHOWHD, ego=SN["SN_CALRIS"])
keyed(TAKEOFF, "a"); keyed(WIELD, "a")
put(0, KIDX["Scroll of Remove Curse"], ident=ID_STORE); keyed(READ, "a")
expect(eq(0)["ident"] & ID_CURSED, "Remove Curse can't lift Calris's curse")
put(0, KIDX["Scroll of *Remove Curse*"], ident=ID_STORE); keyed(READ, "a")
expect(not eq(0)["ident"] & ID_CURSED, "*Remove Curse* can")
one = KIDX["Ring of Power"]
cmd(10, bytes([2, PAGE_MISC])); set_reg(5, one); cmd(4, bytes([6]) + struct.pack("<H", SCR)); call(A["NEW_PLAIN"])
r1 = rec(SCR); print("  the One Ring:", r1)
expect(r1["ident"] & ID_CURSED, "the One Ring comes cursed")
wr(A["PACK"], rd(SCR, IS)); keyed(WIELD, "a")
put(0, KIDX["Scroll of *Remove Curse*"], ident=ID_STORE); keyed(READ, "a")
print("  ->", repr(msgline()))
expect(eq(8)["ident"] & ID_CURSED, "*Remove Curse* can't lift the One Ring's curse ('The One Ring resists...')")

# ---- special objects
wr(A["ART_MADE"], bytes(24))
wr(A["DUN_LEVEL"], bytes([99]))
specials = []
cmd(10, bytes([2, PAGE_MISC]))
for t in range(150):
    wr(SCR, raw(0)); wr(A["SP_DONE"], bytes([0]))
    cmd(4, bytes([6]) + struct.pack("<H", SCR))
    r = call(A["TRY_SPECIAL_NOW@AGAIN"])
    if r[2] & 1: specials.append(KINDS[rec(SCR)["kind"]])
print("  special objects at 4950 ft:", specials)
expect(len(specials) >= 3 and len(specials) == len(set(specials)) and all(s.startswith(("Ring of", "Amulet of", "The Phial", "The Star", "The Arkenstone")) for s in specials),
       "the Rings of Power, Tulkas, Barahir and the amulets turn up, each once")

# ---- prices and feelings
def cost(r):
    wr(SCR, r); cmd(10, bytes([2, PAGE_STORE]))
    cmd(4, bytes([6]) + struct.pack("<H", SCR)); set_reg(3, 0)
    return call(A["ITEM_COST"])[5]
c = cost(raw(KIDX["Dagger"], ident=KNOWN, hit=4, dam=3, ego=SN["SN_ANGRIST"]))
ang = EREC[SN["SN_ANGRIST"]][0]
print("  Angrist known:", c, "its cost", ang[8] | ang[9] << 8)
expect(c == min(65535, (ang[8] | ang[9] << 8) + 700), "an artifact is worth its own cost, plus its pluses")
wr(A["P_CLASS"], bytes([0])); wr(A["P_LEV"], bytes([50]))
clear(EQ, 10)
put(0, KIDX["Dagger"], base=EQ, ident=SHOWHD, hit=10, dam=10, ego=SN["SN_ANGRIST"]); wr(A["P_UPDATE"], bytes([1]))
for t in range(60):
    tick()
    if eq(0)["feel"]: break
expect(eq(0)["feel"] == 4, "a warrior feels an artifact is special")

# ---- Self Knowledge: an artifact's resistances
clear(EQ, 10); clear(A["PACK"], 12)
put(0, KIDX["Iron Helm"], ident=KNOWN, pval=4, ac=20, ego=SN["SN_DOR_LOMIN"]); keyed(WIELD, "a")
wk = A.pop("WAIT_FRESH_KEY")
cmd(10, bytes([2, PAGE_ITEMS]))
pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp)
set_pc(A["SELF_KNOWLEDGE"]); run_to(wk); shot = [l.strip() for l in screen()]; run_to(BP)
A["WAIT_FRESH_KEY"] = wk
print("  self knowledge:", [l for l in shot if l.startswith("You")])
expect("You have ESP." in shot and "Your eyes are resistant to blindness." in shot and "You are resistant to lightning." in shot,
       "Dor-Lomin: ESP, resist blindness, resist lightning...")
cmd(2)
print("ALL OK" if ok else "FAILURES")
