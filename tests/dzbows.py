import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
INV, WIELD, PICKUP, ACTIVATE, THROW = 4, 6, 11, 17, 26
KEY = {(1, -1): "1", (1, 0): "2", (1, 1): "3", (0, -1): "4", (0, 1): "6", (-1, -1): "7", (-1, 0): "8", (-1, 1): "9"}
def keyed(cmdno, keys=" "):
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, 0); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
def kind(name, plain=True):
    return next(i for i, k in enumerate(KINDS) if (k.replace("& ", "").replace("~", "") == name) if plain)
LONG, SHORT, SLING, LIGHTX = kind("Long Bow"), kind("Short Bow"), kind("Sling"), kind("Light Crossbow")
ARROW, PEBBLE, BOLT = kind("Arrow"), kind("Rounded Pebble"), kind("Bolt")
def rec(k, num=1, pval=0, ident=0, hit=0, dam=0, name2=0):
    return bytes([k & 255, k >> 8, num, 0, 0, 1, pval & 255, pval >> 8, ident, hit & 255, dam & 255, 0, name2, 0])
def slot(base, i=0):
    r = rd(base + IS*i, 14)
    return dict(kind=r[0] | r[1] << 8, num=r[2], pval=r[6] | r[7] << 8, ident=r[8], hit=r[9] - 256 if r[9] > 127 else r[9],
                dam=r[10] - 256 if r[10] > 127 else r[10], name2=r[12], empty=r[1] == 255)
def clear_floor():
    for i in range(64): wr(0xB400 + IS*i + 1, bytes([255]))
def bonuses(): cmd(10, bytes([2, 42])); call(A["CALC_BONUSES"])
def s8(name): v = rd(A[name], 1)[0]; return v - 256 if v > 127 else v
calm(); full(); clear_floor(); call(A["LIGHT_REFRESH"])
wr(A["REGENHP"], bytes([0xC9]))
print("  kinds:", LONG, SHORT, SLING, LIGHTX, ARROW, PEBBLE, BOLT)
expect(all(KIND_RECS[k]["raw"][2] == 21 for k in (LONG, SHORT, SLING, LIGHTX)) and all(KIND_RECS[k]["raw"][2] == 22 for k in (ARROW, PEBBLE, BOLT)),
       "slings, bows and crossbows are items now, and shots, arrows and bolts")

# ---- descriptions
clear(A["PACK"], 12)
wr(A["PACK"], rec(LONG, ident=0x44, hit=5, dam=6))
wr(A["PACK"] + IS, rec(ARROW, 23, 7, ident=0x44, hit=2, dam=3))
wr(A["PACK"] + 2*IS, rec(SLING))
install_keys(" "); call(A["MSG_CLEAR"]); set_reg(3, 0); set_reg(4, INV << 8); set_pc(A["DISPATCH"])
run_to(A["READ_ASCII"]); lines = [l.strip() for l in screen() if l.strip()]; run_to(BP)
print("  'i':", [l for l in lines if l[:2] in ("a)", "b)", "c)")])
expect(any("a) a Long Bow (x3) (+5,+6)" in l for l in lines), "'a Long Bow (x3) (+5,+6)'")
expect(any("b) 23 Arrows (1d4) (+2,+3)" in l for l in lines), "'23 Arrows (1d4) (+2,+3)'")
expect(any("c) a Sling (x2)" in l for l in lines), "'a Sling (x2)' (pluses not known yet)")

# ---- wielding: bows in the weapon's hand, their to-dam doesn't count
clear(EQ, 1)
m = keyed(WIELD, "a")
print("  wield:", repr(m))
expect(slot(EQ)["kind"] == LONG and "You are wielding a Long Bow (x3)" in m, "'w': 'You are wielding a Long Bow (x3) (+5,+6).'")
bonuses(); th, td = s8("P_TOHIT"), s8("P_TODAM")
wr(EQ + 9, bytes([15, 20])); bonuses()
print("  bow +5,+6 -> +15,+20: to-hit", th, "->", s8("P_TOHIT"), "to-dam", td, "->", s8("P_TODAM"))
expect(s8("P_TOHIT") == th + 10 and s8("P_TODAM") == td, "a bow's to-hit counts, its to-dam doesn't ('Bows can't damage.')")

# ---- firing
home = py()
dy, dx = open_line(4)
d = KEY[(dy, dx)]
R = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and 1 <= r["level"] <= 5)
mspot = (home[0] + 3*dy, home[1] + 3*dx)
wr(A["TEST_HIT"], bytes([0x37, 0xC9]))
def shoot(bow, ammo, n=12, bhit=0, bdam=0):
    out = []
    for t in range(n):
        wr(A["PLAYER_Y"], bytes([home[0]])); wr(A["PLAYER_X"], bytes([home[1]]))
        calm(); clear(A["PACK"], 12); clear_floor()
        wr(EQ, rec(bow, ident=0x44, hit=bhit, dam=bdam) if bow is not None else bytes([0, 255] + [0]*12)); bonuses()
        wr(A["PACK"], rec(ammo, 10, 1, ident=0x44))
        a = 0xC000 + mspot[0]*W + mspot[1]; wr(a, bytes([rd(a, 1)[0] | 0x20]))
        place(0, R, *mspot, hp=3000)
        call(A["UPDATE_VIEW"]); call(A["MONSTERS_SEE_ALL"])
        keyed(THROW, "a" + d)
        out.append(3000 - mon(0)["hp"])
    return out
bare = shoot(None, ARROW)
lb = shoot(LONG, ARROW)
sl = shoot(SLING, ARROW)
peb = shoot(SLING, PEBBLE)
lbp = shoot(LONG, ARROW, bdam=5)
print("  arrows thrown:", bare, "\n  from a long bow:", lb, "\n  from a sling:", sl, "\n  pebbles from a sling:", peb, "\n  long bow (+0,+5):", lbp)
expect(sum(1 for v in bare if 1 <= v <= 4) >= 9, "thrown by hand, an arrow does its 1d4")
expect(sum(1 for v in lb if v % 3 == 0 and 3 <= v <= 12) >= 9 and max(lb) > 4, "from a long bow: times 3")
expect(sum(1 for v in sl if 1 <= v <= 4) >= 9, "arrows from a sling: no better than throwing them")
expect(sum(1 for v in peb if v in (2, 4)) >= 9, "pebbles from a sling: 1d2 times 2")
expect(sum(1 for v in lbp if v % 3 == 0 and 18 <= v <= 27) >= 9, "the bow's to-dam is added before multiplying ((1d4 + 5) x 3)")
f = rd(0x6000, 1)

# ---- wielding arrows: the whole stack, one blow
clear(A["PACK"], 12); clear(EQ, 1)
wr(A["PACK"], rec(ARROW, 20, 3, ident=0x44))
m = keyed(WIELD, "a"); bonuses()
print("  wield arrows:", repr(m), slot(EQ)["num"], rd(A["P_BLOWS"], 1)[0])
expect(slot(EQ)["kind"] == ARROW and slot(EQ)["num"] == 20 and slot(A["PACK"])["empty"], "wielding arrows takes the whole stack")
expect(rd(A["P_BLOWS"], 1)[0] == 1, "and gives one blow")
clear(EQ, 1); bonuses()

# ---- stacking: only arrows from the same pile
for pv, want in ((7, 1), (9, 2)):
    clear(A["PACK"], 12); clear_floor()
    wr(A["PACK"], rec(ARROW, 5, 7, ident=0x44))
    y, x = py()
    wr(0xB400, rec(ARROW, 3, pv, ident=0x44)[:3] + bytes([y, x]) + rec(ARROW, 3, pv, ident=0x44)[5:])
    m = keyed(PICKUP)
    n = sum(1 for i in range(12) if not slot(A["PACK"], i)["empty"])
    print("  pick up pile", pv, ":", repr(m), "slots", n, slot(A["PACK"])["num"])
    expect(n == want and (want == 2 or slot(A["PACK"])["num"] == 8), "arrows from the same pile stack" if want == 1 else "arrows from different piles don't")

# ---- magic_treasure
def make(k, level):
    R0 = 0xBD00
    cmd(10, bytes([2, 41])); set_reg(6, R0); set_reg(5, k); set_reg(2, level << 8)
    call(A["NEW_ITEM"])
    return slot(R0)
arrows = [make(ARROW, 40) for i in range(40)]
nums = [a["num"] for a in arrows]; piles = [a["pval"] for a in arrows]
egos = sorted({a["name2"] for a in arrows if a["name2"]})
print("  40 piles of arrows: numbers", min(nums), "-", max(nums), "egos", egos, "piles", piles[:5])
expect(all(7 <= v <= 42 for v in nums) and sum(nums) / 40 > 18, "arrows come 7d6 to a pile")
expect(len(set(piles)) == 40, "each pile its own number")
expect(all(a["ident"] & 0x40 for a in arrows), "arrows always show (+h,+d)")
expect(egos and set(egos) <= {15, 43, 44, 55, 45, 77, 83}, "egos: Slaying, Fire, Slay Evil, Slay Animal, Dragon Slaying, Wounding, Backbiting")
bows = [make(LONG, 50) for i in range(60)]
begos = sorted({b["name2"] for b in bows if b["name2"]})
print("  60 long bows at 50: egos", begos, "pluses", [(b["hit"], b["dam"]) for b in bows[:6]])
expect(begos and set(begos) <= {65, 101, 126, 127} | {next(int(l.split()[2]) for l in open("../data/egos.asm") if l.startswith("SN_MIGHT_BOW"))}, "bows of Might and Accuracy (or Beleg Cuthalion, Bard)")
expect(any(b["hit"] > 0 for b in bows), "magic bows have pluses")

# ---- Cubragol
clear(A["PACK"], 12); clear(EQ, 1)
wr(EQ, rec(LIGHTX, pval=1, ident=0x44, hit=10, dam=14, name2=126))
wr(A["PACK"], rec(BOLT, 15, 4, ident=0x44))
wr(A["P_STAT_USE"] + 1, bytes([118])); wr(A["P_LEV"], bytes([30])); bonuses()
m = ""
for t in range(6):
    wr(EQ + 3, bytes([0, 0]))
    m = keyed(ACTIVATE, "a")
    if "fiery" in m: break
b = slot(A["PACK"])
print("  Cubragol:", repr(m), b)
expect("Your bolts are covered in a fiery shield!" in m and b["name2"] == 43 and 4 <= b["hit"] <= 6 and 4 <= b["dam"] <= 6, "Cubragol: 'Your bolts are covered in a fiery shield!' (bolts of Fire, +3+1d3 each)")
for t in range(6):
    wr(EQ + 3, bytes([0, 0]))
    m = keyed(ACTIVATE, "a")
    if "fiery" in m: break
expect("The fiery enchantment fails." in m, "bolts that are already magic: 'The fiery enchantment fails.'")
calm()
cmd(2)
print("ALL OK" if ok else "FAILURES")
