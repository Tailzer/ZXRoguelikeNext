import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
KIDX = {k: i for i, k in enumerate(KINDS)}
SN = {m.group(1): int(m.group(2)) for m in re.finditer(r"^(SN_\w+)\t+equ (\d+)", open(_os.path.join(_GAME, "data", "egos.asm")).read(), re.M)}
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
IS = 14
EQ = A["EQUIP"]
PAGE_MISC, PAGE_ITEMS, PAGE_STORE = 41, 42, 51
sg = lambda v: v - 256 if v > 127 else v
def raw(k, ident=0, hit=0, dam=0, ac=0, pval=0, ego=0, n=1):
    return bytes([k & 255, k >> 8, n, 0, 0, 1, pval & 255, 0, ident, hit & 255, dam & 255, ac & 255, ego, 0])
def put(slot, k, base=None, **kw):
    wr((A["PACK"] if base is None else base) + IS*slot, raw(k, **kw))
def clear(base, n):
    for i in range(n): wr(base + IS*i, bytes([0, 255] + [0]*12))
def clear_pack(): clear(A["PACK"], 12)
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
ID_STORE, ID_KNOWN2, ID_CURSED, ID_DAMD, SHOWHD = 1, 4, 8, 16, 64
KNOWN = ID_STORE | ID_KNOWN2
EQ_WEAPON, EQ_BODY, EQ_SHIELD, EQ_HELM, EQ_CLOAK, EQ_GLOVES, EQ_BOOTS = range(7)
SCR = 0xBDC0 + 0x80
def make(k, level):
    cmd(10, bytes([2, PAGE_MISC]))
    set_reg(5, k); set_reg(2, level << 8); cmd(4, bytes([6]) + struct.pack("<H", SCR))
    call(A["NEW_ITEM"])
    return rec(SCR)
_eg = open(_os.path.join(_GAME, "data", "egos.asm")).read()
ART = {i for i, m in enumerate(re.finditer(r"\tdb ([\d,]+)\n\tdw ", _eg)) if int(m.group(1).split(",")[12]) & 8}
def egos_of(k, level, n):
    out = [make(k, level) for _ in range(n)]
    for r in out:
        if r["ego"] in ART: r["ego"], r["art"] = 0, True	# (artifacts: dzarts)
    return out, {e: sum(1 for r in out if r["ego"] == e) for e in {r["ego"] for r in out}}
inv = {v: k for k, v in SN.items()}
names = lambda d: {inv.get(e, e): c for e, c in sorted(d.items())}

# ---- magic_treasure's egos at level 40 (chance 55, special 13)
rs, d = egos_of(KIDX["Dagger"], 40, 300)
print("  daggers:", names(d))
weapon_egos = {SN[k] for k in ("SN_HA", "SN_DF", "SN_FT", "SN_FB", "SN_SA", "SN_SD", "SN_SE", "SN_SU", "SN_SO", "SN_ST", "SN_SG", "SN_SDEM", "SN_WEST", "SN_MORGUL")}
expect(set(d) - {0} <= weapon_egos and 10 <= sum(c for e, c in d.items() if e) <= 60, "daggers: weapon egos about 55% x 13*1.5% of the time")
ha = [r for r in rs if r["ego"] == SN["SN_HA"]]
df = [r for r in rs if r["ego"] == SN["SN_DF"]]
expect(all(1 <= r["pval"] <= 4 and r["ac"] >= 1 for r in ha) and all(1 <= r["pval"] <= 3 and r["ac"] >= 6 for r in df),
       "Holy Avengers 1d4 strength and AC, Defenders 1d3 stealth and 5+1d5 AC")
mg = [r for r in rs if r["ego"] == SN["SN_MORGUL"]]
expect(all(r["ident"] & ID_CURSED and r["ac"] == -10 for r in mg), f"weapons of Morgul are cursed with AC -10 ({len(mg)})")
rs, d = egos_of(KIDX["Whip"], 40, 120)
print("  whips:", names(d))
expect(set(d) - {0} <= {SN["SN_FIRE"], SN["SN_FIRE2"], SN["SN_MORGUL"]} and d.get(SN["SN_FIRE"], 0) > 0, "whips' only ego is of Fire")
rs, d = egos_of(KIDX["Set of Gauntlets"], 40, 300)
print("  gauntlets:", names(d))
expect(set(d) - {0} <= {SN[k] for k in ("SN_FREE_ACTION", "SN_SLAYING", "SN_AGILITY", "SN_POWER", "SN_CLUMSINESS", "SN_WEAKNESS")} and len(d) >= 4, "gloves: free action, slaying, agility, power (or clumsiness, weakness)")
expect(all(3 <= r["pval"] <= 4 for r in rs if r["ego"] == SN["SN_AGILITY"]) and all(r["pval"] < 0 for r in rs if r["ego"] in (SN["SN_CLUMSINESS"], SN["SN_WEAKNESS"])),
       "agility 2+1d2, clumsiness and weakness a minus")
rs, d = egos_of(KIDX["Pair of Metal Shod Boots"], 40, 300)
print("  metal shod boots:", names(d))
expect(SN["SN_STEALTH"] not in d and SN["SN_SLOW_DESCENT"] in d, "metal shod boots never of stealth")
rs, d = egos_of(KIDX["Metal Cap"], 40, 300)
print("  metal caps:", names(d))
expect(set(d) - {0} <= {SN[k] for k in ("SN_INTELLIGENCE", "SN_WISDOM", "SN_INFRAVISION", "SN_LIGHT", "SN_TELEPATHY", "SN_STUPIDITY", "SN_DULLNESS", "SN_WEAKNESS", "SN_TELEPORTATION", "SN_UGLINESS")}, "helms: helm egos only")
rs, d = egos_of(KIDX["Iron Crown"], 40, 200)
print("  iron crowns:", names(d))
expect(len(set(d) & {SN[k] for k in ("SN_MIGHT", "SN_LORDLINESS", "SN_MAGI", "SN_BEAUTY", "SN_SEEING", "SN_REGENERATION")}) >= 3, "crowns: Might, Lordliness, the Magi, Beauty, Seeing, Regeneration")
rs, d = egos_of(KIDX["Cloak"], 40, 300)
print("  cloaks:", names(d))
expect(any(not r["ego"] and not r.get("art") and r["ac"] > 0 for r in rs), "plain magical cloaks get pluses too (1.3's fix)")
expect({SN["SN_PROTECTION"], SN["SN_STEALTH"]} <= set(d), "cloaks of Protection and Stealth")
rs, d = egos_of(KIDX["Soft Leather Armour"], 40, 300)
print("  soft leather:", names(d))
expect({SN["SN_RF"], SN["SN_RC"], SN["SN_RL"]} <= set(d), "armour of resist fire, cold, lightning")

# ---- names
clear_pack()
put(0, KIDX["Dagger"], ident=KNOWN | SHOWHD, hit=3, dam=3, ac=7, pval=2, ego=SN["SN_DF"])
put(1, KIDX["Dagger"], ident=SHOWHD, hit=3, dam=3, ac=7, pval=2, ego=SN["SN_DF"])
put(2, KIDX["Pair of Soft Leather Boots"], ident=KNOWN, ac=5, pval=1, ego=SN["SN_SPEED"])
put(3, KIDX["Set of Gauntlets"], ident=KNOWN | SHOWHD, hit=3, dam=4, ac=2, pval=3, ego=SN["SN_POWER"])
put(4, KIDX["Whip"], ident=KNOWN | SHOWHD, hit=5, dam=5, ego=SN["SN_FIRE2"])
put(5, KIDX["Soft Leather Armour"], ident=KNOWN, ac=10, ego=SN["SN_R"])
shot = keyed(INV, " ", capture=True); ls = lines_of(shot)
print("  pack:", ls)
expect(ls[0] == "a) a Dagger (Defender) (1d4) (+3,+3) [+7] (+2 to stealth)", "'a Dagger (Defender) (1d4) (+3,+3) [+7] (+2 to stealth)'")
expect(ls[1] == "b) a Dagger (1d4)", "not known: no ego, no pluses")
expect(ls[2] == "c) a Pair of Soft Leather Boots of Speed [2,+5] (+1)", "'... Boots of Speed [2,+5] (+1)'")
expect(ls[3].startswith("d) a Set of Gauntlets of Power (+3,+4) [") and ls[3].endswith(",+2] (+3)"), "'a Set of Gauntlets of Power (+3,+4) [..,+2] (+3)'")
expect(ls[4] == "e) a Whip of Fire (2d6) (+5,+5)", "a whip of fire with two dice (whips are 1d6)")
expect(ls[5].startswith("f) Soft Leather Armour of Resistance [") and ls[5].endswith(",+10]"), "'Soft Leather Armour of Resistance [8,+10]'")

# ---- slays and brands (tot_dam)
clear_pack(); put(0, KIDX["Dagger"], ident=KNOWN, ego=SN["SN_SE"]); keyed(WIELD, "a")
def tot(race, dmg=10):
    set_reg(5, race); call(A["RACE_ADDR"])
    set_reg(5, dmg); return call(A["TOT_DAM"])[5]
evil = next(i for i, r in enumerate(RACES) if r["raw"][13] & 8 and not r["raw"][13] & 48)
good = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 8)
print("  slay evil:", NAMES[evil], tot(evil), NAMES[good], tot(good))
expect(tot(evil) == 20 and tot(good) == 10, "Slay Evil: double damage to evil monsters only")
clear_pack(); put(0, KIDX["Dagger"], ident=KNOWN, ego=SN["SN_FB"]); keyed(WIELD, "a")
cold = next(i for i, r in enumerate(RACES) if r["raw"][15] & 1)
warm = next(i for i, r in enumerate(RACES) if not r["raw"][15] & 1)
print("  frost brand:", NAMES[cold], tot(cold), NAMES[warm], tot(warm))
expect(tot(cold) == 10 and tot(warm) == 30, "Frost Brand: triple, but not to those immune to cold")
clear_pack(); put(0, KIDX["Dagger"], ident=KNOWN, ego=SN["SN_HA"], pval=2); keyed(WIELD, "a")
und = next(i for i, r in enumerate(RACES) if r["raw"][13] & 16)
dem = next(i for i, r in enumerate(RACES) if r["raw"][13] & 32)
ani = next(i for i, r in enumerate(RACES) if r["raw"][14] & 8 and not r["raw"][13] & 8)
print("  holy avenger:", NAMES[und], tot(und), NAMES[dem], tot(dem), NAMES[evil], tot(evil), NAMES[ani], tot(ani))
expect(tot(und) == 30 and tot(dem) == 30 and tot(evil) == 20 and tot(ani) == 10, "Holy Avenger: x3 undead and demons (first match), x2 evil, nothing else")
expect(rd(A["P_SUSTAIN"], 1)[0] & 2, "and its number (2) sustains INT")

# ---- what egos do
clear_pack()
sp0 = r8("P_SPEED")
put(0, KIDX["Pair of Soft Leather Boots"], ident=KNOWN, ac=5, pval=1, ego=SN["SN_SPEED"]); keyed(WIELD, "a")
expect(r8("P_SPEED") == sp0 - 1, "Boots of Speed: one faster")
stl0, n0 = r8("P_STL"), r16("P_NOTICE")
put(0, KIDX["Cloak"], ident=KNOWN, ac=3, pval=3, ego=SN["SN_STEALTH"]); keyed(WIELD, "a")
print("  stealth", stl0, "->", r8("P_STL"), " notice", n0, "->", r16("P_NOTICE"))
expect(r8("P_STL") == stl0 + 3 and r16("P_NOTICE") < n0, "a Cloak of Stealth +3: three more stealth, so monsters notice less")
inf0 = rd(A["P_INFRA"], 1)[0]
put(0, KIDX["Metal Cap"], ident=KNOWN, pval=4, ego=SN["SN_INFRAVISION"]); keyed(WIELD, "a")
expect(rd(A["P_INFRA"], 1)[0] == inf0 + 4, "a Helm of Infra-Vision +4: 40 ft more infravision")
put(0, KIDX["Iron Crown"], ident=KNOWN, ego=SN["SN_REGENERATION"]); keyed(WIELD, "a")
w16("P_FOOD", 5000); tick(10)
f1 = r16("P_FOOD"); print("  food with regeneration after 10 turns:", f1)
fast = max(0, -r8("P_SPEED")) ** 2						# (the boots of speed are still on)
expect(5000 - f1 == 10 * (5 + fast), "a Crown of Regeneration: food goes 5 a turn, not 2 (and the speed's 1)")
put(0, KIDX["Metal Cap"], ident=KNOWN, ego=SN["SN_TELEPATHY"]); keyed(WIELD, "a")
expect(int.from_bytes(rd(A["P_EFLAGS2"], 4), "little") & 0x20, "a Helm of Telepathy gives ESP")
put(0, KIDX["Robe"], ident=KNOWN, ac=12, pval=10, ego=SN["SN_MAGI_ROBE"]); keyed(WIELD, "a")
expect(rd(A["P_SUSTAIN"], 1)[0] == 0x3F, "a Robe of the Magi sustains every stat")
put(0, KIDX["Set of Gauntlets"], ident=KNOWN | SHOWHD, hit=2, dam=2, pval=3, ego=SN["SN_POWER"]); keyed(WIELD, "a")
expect(rd(A["P_STAT_USE"], 1)[0] > rd(A["P_STAT"], 1)[0], "Gauntlets of Power raise STR")

# ---- telepathy: monsters out of sight are seen
import random
level_mons = [b for b in range(64) if rd(0xB000 + 16*b + 12, 1)[0] != 255]
py_, px_ = rd(A["PLAYER_Y"], 1)[0], rd(A["PLAYER_X"], 1)[0]
vx, vy = rd(A["VIEW_X"], 1)[0], rd(A["VIEW_X"] + 1, 1)[0]
# put a monster 6 squares away, wherever that is (walls and all)
b = 0xB000
wr(b, bytes([0])); wr(b + 1, bytes([py_, px_ + 6])); wr(b + 12, bytes([0])); wr(b + 3, bytes([50, 0]))
wr(b + 7, bytes([255, 0]))
tick()
seen = rd(b + 11, 1)[0]
print("  monster 6 squares away seen:", seen)
expect(seen == 1, "with ESP a monster near you is seen, walls or not")
wr(b + 12, bytes([255]))

# ---- Morgul: Remove Curse doesn't touch it, *Remove Curse* does
clear_pack()
clear(EQ, 10)
put(0, KIDX["Dagger"], ident=ID_CURSED | SHOWHD, hit=-20, dam=-20, ac=-10, ego=SN["SN_MORGUL"]); keyed(WIELD, "a")
w0 = r16("W_WEIGHT")
expect(w0 == (KIND_RECS[KIDX["Dagger"]]["raw"][5] | KIND_RECS[KIDX["Dagger"]]["raw"][6] << 8) + 100, "a Dagger of Morgul weighs 10 lb more")
put(0, KIDX["Scroll of Remove Curse"], ident=ID_STORE); keyed(READ, "a")
expect(eq(EQ_WEAPON)["ident"] & ID_CURSED, "Remove Curse can't lift Morgul's curse")
put(0, KIDX["Scroll of *Remove Curse*"], ident=ID_STORE); keyed(READ, "a")
expect(not eq(EQ_WEAPON)["ident"] & ID_CURSED, "*Remove Curse* can")
keyed(TAKEOFF, "a")

# ---- Self Knowledge
clear_pack()
put(0, KIDX["Dagger"], ident=KNOWN, ego=SN["SN_HA"], pval=1); keyed(WIELD, "a")
put(0, KIDX["Metal Cap"], ident=KNOWN, ego=SN["SN_TELEPATHY"]); keyed(WIELD, "a")
wk = A.pop("WAIT_FRESH_KEY")
cmd(10, bytes([2, PAGE_ITEMS]))
pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp)
set_pc(A["SELF_KNOWLEDGE"]); run_to(wk); shot = [l.strip() for l in screen()]; run_to(BP)
A["WAIT_FRESH_KEY"] = wk
print("  self knowledge:", [l for l in shot if l.startswith("You")])
expect("You have ESP." in shot and "Your weapon strikes at undead with holy wrath." in shot and "Your weapon fights against evil with holy fury." in shot
       and "Your weapon strikes at demons with holy wrath." in shot and "You will not become weaker." in shot, "Self Knowledge lists ESP and the Holy Avenger's slays and sustain")

# ---- feelings and prices
wr(A["P_CLASS"], bytes([0])); wr(A["P_LEV"], bytes([50]))
clear(EQ, 10)
put(0, KIDX["Dagger"], base=EQ, ident=SHOWHD, hit=3, dam=3, ego=SN["SN_SE"]); wr(A["P_UPDATE"], bytes([1]))
for t in range(60):
    tick()
    if eq(0)["feel"]: break
expect(eq(0)["feel"] == 3, "a warrior feels an ego weapon is excellent")
def cost(r):
    wr(SCR, r); cmd(10, bytes([2, PAGE_STORE]))
    cmd(4, bytes([6]) + struct.pack("<H", SCR)); set_reg(3, 0)
    return call(A["ITEM_COST"])[5]
base = lambda k: KIND_RECS[k]["raw"][16] | KIND_RECS[k]["raw"][17] << 8
c1 = cost(raw(KIDX["Dagger"], ident=KNOWN, hit=3, dam=3, ego=SN["SN_SE"]))
c2 = cost(raw(KIDX["Dagger"], ident=KNOWN, hit=3, dam=3, ac=7, pval=2, ego=SN["SN_DF"]))
c3 = cost(raw(KIDX["Dagger"], hit=3, dam=3, ego=SN["SN_SE"]))
print("  prices:", c1, c2, c3, " base", base(KIDX["Dagger"]))
expect(c1 == base(KIDX["Dagger"]) + 4000 + 600, "a Dagger of Slay Evil (+3,+3): cost + 4000 + 600")
expect(c2 == (base(KIDX["Dagger"]) + 7500 + 1000) * 2 + 1300, "a Defender: (cost + 7500 + 2 x 500) x 2, + 1300 for the pluses")
expect(c3 == base(KIDX["Dagger"]), "not known: the plain cost")
cmd(2)
print("ALL OK" if ok else "FAILURES")
