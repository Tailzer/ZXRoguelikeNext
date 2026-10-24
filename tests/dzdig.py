import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
PAGE_LEVEL, PAGE_MISC, PAGE_TRAP = 40, 41, 58
EQ = A["EQUIP"]
DIGGERS = {k["name"]: i for i, k in enumerate(KIND_RECS) if k["raw"][25] == 14}
print("  diggers:", {n: (i, KIND_RECS[i]["raw"][12], KIND_RECS[i]["raw"][2]) for n, i in DIGGERS.items()})
expect(set(DIGGERS) == {"Orcish Pick", "Dwarven Pick", "Gnomish Shovel", "Dwarven Shovel", "Pick", "Shovel"},
       "the six picks and shovels are items")
expect([KIND_RECS[DIGGERS[n]]["raw"][12] for n in ("Orcish Pick", "Dwarven Pick", "Gnomish Shovel", "Dwarven Shovel", "Pick", "Shovel")] == [2, 3, 1, 2, 1, 0]
       and all(KIND_RECS[i]["raw"][2] == 7 for i in DIGGERS.values()), "how well each digs (p1), wielded as weapons")
FL = 0xB400
def make(k, level):
    clear(FL, 64); put(FL, 0, 0)
    cmd(10, bytes([2, PAGE_MISC]))
    pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp)
    set_reg(6, FL); set_reg(5, k); set_reg(2, level << 8); set_pc(A["NEW_ITEM"]); run_to(BP)
    r = rd(FL, IS); return r[6] - 256 if r[6] > 127 else r[6], r[8]
DP = DIGGERS["Dwarven Pick"]
made = [make(DP, 60) for _ in range(40)]
pv = [p for p, _ in made]
print("  Dwarven Picks at 60:", sorted(pv))
expect(all(i & 0x40 for _, i in made), "always (+h,+d) shown (ID_SHOW_HITDAM)")
expect(any(p > 3 for p in pv) and any(p < 0 for p in pv) and all((p < 0) == bool(i & 8) for p, i in made),
       "magic: better at digging, or cursed and worse")
plain = [make(DP, 1)[0] for _ in range(20)]
expect(all(p >= 3 or p < 0 for p in plain) and plain.count(3) >= 10, "shallow: mostly just as made (3)")

# the name
clear(FL, 64); wr(FL, bytes([DP & 255, DP >> 8, 1, 0, 0, 0, 3, 0, 0x44, 0, 0, 0, 0, 0]))
call(A["MSG_BEGIN"]); set_reg(6, FL); call(A["OBJDES_MSG"])
name = bytes(rd(A["MSG_BUF"], 60)).split(b"\0")[0].decode()
print("  name:", repr(name))
expect(name == "a Dwarven Pick (1d4) (+0,+0) (+3)", "'a Dwarven Pick (1d4) (+0,+0) (+3)'")

# digging with it
def power(pval, k=DP):
    wr(EQ, bytes([k & 255, k >> 8, 1, 0, 0, 0, pval & 255, 0, 0x44, 0, 0, 0, 0, 0]))
    cmd(10, bytes([2, PAGE_TRAP])); call(A["DIG_POWER"]); return regs()[5]
st = rd(A["P_STAT_USE"], 1)[0]
p3, pm = power(3), power(-2)
print("  dig power: STR", st, "pick +3", p3, "cursed -2", pm)
expect(p3 == st + 25 + 150, "a digger: STR + 25 + 50 x its number")
expect(pm == max(0, st + 25 - 100), "cursed: less, at worst nothing")
wr(EQ, bytes([0, 255] + [0]*12))

# ---- the level's rating
def gen(lvl):
    wr(A["DUN_LEVEL"], bytes([lvl])); call(A["NEW_LEVEL"]); calm()
    return struct.unpack("<H", rd(A["LV_RATING"], 2))[0], rd(A["LV_SPECIAL"], 1)[0]
r = [gen(40) for _ in range(5)]
print("  level 40 ratings:", r)
expect(any(x[0] > 0 for x in r), "things out of their depth rate a level")
r1 = [gen(1) for _ in range(4)]
print("  level 1 ratings:", r1)

# ---- the feeling
def feel(rating, special=0, turn=500, old=200, lvl=5):
    wr(A["DUN_LEVEL"], bytes([lvl]))
    wr(A["LV_RATING"], struct.pack("<H", rating)); wr(A["LV_SPECIAL"], bytes([special]))
    wr(A["GAME_TURN"], struct.pack("<H", turn)); wr(A["LV_OLD_TURN"], struct.pack("<H", old))
    call(A["MSG_CLEAR"]); cmd(10, bytes([2, PAGE_LEVEL])); call(A["LEVEL_FEELING"])
    return msgline()
expected = [(101, "You have a superb feeling about this level."), (81, "You have an excellent feeling that your luck is turning..."),
            (61, "You have a very good feeling."), (41, "You have a good feeling."), (31, "You feel strangely lucky."),
            (21, "You feel your luck is turning..."), (11, "You like the look of this place."), (10, "")]
for rt, words in expected:
    m = feel(rt)
    expect(m == words, f"rating {rt}: {words!r}")
expect(feel(5, special=1) == "You feel there is something special about this level.", "something special: 'You feel there is something special about this level.'")
expect(feel(200, turn=500, old=0) == "", "the first level of a game (old turn 0): no feeling")
expect(feel(200, lvl=0) == "", "the town: none")
short = sum(feel(200, turn=202, old=200) != "" for _ in range(10))
expect(short == 0, "2 turns on the last level: never (1d50)")
expect(struct.unpack("<H", rd(A["LV_OLD_TURN"], 2))[0] == 202, "and the new level's turn is kept for the next")
wr(A["DUN_LEVEL"], bytes([1]))
cmd(2)
print("ALL OK" if ok else "FAILURES")
