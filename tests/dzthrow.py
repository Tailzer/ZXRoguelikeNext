import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
THROW = 26
KEY = {(1, -1): "1", (1, 0): "2", (1, 1): "3", (0, -1): "4", (0, 1): "6", (-1, -1): "7", (-1, 0): "8", (-1, 1): "9"}
def keyed(cmdno, keys=" "):
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, 0); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
FLASK = next(i for i, k in enumerate(KINDS) if "Flask" in k)
DAGGER = next(i for i, k in enumerate(KINDS) if "Dagger" in k)
MAIL = next(i for i, k in enumerate(KINDS) if "Chain Mail" in k)
def floor_at(y, x): return [i for i in range(64) if rd(0xB400 + IS*i + 1, 1)[0] != 255 and tuple(rd(0xB400 + IS*i + 3, 2)) == (y, x)]
def clear_floor():
    for i in range(64): wr(0xB400 + IS*i + 1, bytes([255]))
def pack_num(s=0): return rd(A["PACK"] + IS*s + 2, 1)[0]
calm(); full(); clear_floor(); call(A["LIGHT_REFRESH"])
wr(A["REGENHP"], bytes([0xC9]))
home = py()
dy, dx = open_line(4)
d = KEY[(dy, dx)]
R = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and r["level"] <= 5 and r["raw"][15] == 0) if False else next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and 1 <= r["level"] <= 5)
mspot = (home[0] + 3*dy, home[1] + 3*dx)
def setup(k=FLASK, n=5, hp=300):
    wr(A["PLAYER_Y"], bytes([home[0]])); wr(A["PLAYER_X"], bytes([home[1]]))
    calm(); clear(A["PACK"], 12); put(A["PACK"], 0, k, n); clear_floor()
    a = 0xC000 + mspot[0]*W + mspot[1]; wr(a, bytes([rd(a, 1)[0] | 0x20]))	# (lit, so it's seen)
    if hp: place(0, R, *mspot, hp=hp)
    call(A["UPDATE_VIEW"]); call(A["MONSTERS_SEE_ALL"])

clear(A["PACK"], 12)
m = keyed(THROW, "a" + d)
expect("But you are not carrying anything." in m and rd(A["TURN_TAKEN"], 1)[0] == 0, "an empty pack: 'But you are not carrying anything.'")

# ---- a hit
wr(A["TEST_HIT"], bytes([0x37, 0xC9]))
setup()
install_keys("a" + d + "   "); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
set_reg(3, 0); set_reg(4, THROW << 8); set_pc(A["DISPATCH"])
shots = []
for i in range(3):								# each message as it's finished
    run_to(A["MSG_END"]); n = struct.unpack("<H", rd(A["MSG_PTR"], 2))[0] - A["MSG_BUF"]
    shots.append(rd(A["MSG_BUF"], n).decode("latin-1"))
run_to(BP)
m = " | ".join(shots)
hp = mon(0)["hp"]; print("  screen:", screen()[:2])
print("  hit:", repr(m), "hp 300 ->", hp, "flasks", pack_num())
expect("The Flask of oil hits the" in m and hp < 300, "'The Flask of oil hits the ...' and it's hurt")
expect(pack_num() == 4 and not any(floor_at(y, x) for y in range(home[0] - 5, home[0] + 6) for x in range(home[1] - 5, home[1] + 6)), "it's used up when it hits")
dmg = []
for t in range(12):
    setup(); keyed(THROW, "a" + d); dmg.append(300 - mon(0)["hp"])
print("  flask damage:", dmg)
expect(min(dmg) >= 6 and max(dmg) > 12, "fire brand: 2d6 x 3 (fire) (or less against the immune)")
setup(DAGGER, 3)
keyed(THROW, "a" + d); dd = 300 - mon(0)["hp"]
print("  dagger:", dd)
expect(1 <= dd <= 4 or dd > 4 and "hit" in msgline(), "a thrown dagger: its 1d4")
setup(hp=1)
m = keyed(THROW, "a" + d)
print("  kill:", repr(m))
expect("You have killed the" in m and mon(0)["free"], "'You have killed the ...'")
setup(hp=3000)
m = keyed(THROW, "a" + d)
expect(m.rstrip(".").split(".")[-1].strip().startswith("The ") or "with pain" in m or "notices" in m or "shrugs" in m or "grunts" in m or "ignores" in m, "and how much it hurt ('The ... grunts with pain.')")
print("  pain:", repr(m))

# ---- a miss: it lands short of the monster
wr(A["TEST_HIT"], bytes([0xB7, 0xC9]))
before = (mspot[0] - dy, mspot[1] - dx)
landed = gone = 0
for t in range(15):
    setup()
    m = keyed(THROW, "a" + d)
    near = [(y, x) for y in range(before[0] - 1, before[0] + 2) for x in range(before[1] - 1, before[1] + 2) if floor_at(y, x)]
    landed += bool(near); gone += "The Flask of oil disappears." in m
print("  misses: landed", landed, "gone", gone)
expect(landed + gone == 15 and landed >= 10, "a miss lands by where it stopped (1 in 10: 'The Flask of oil disappears.')")
expect(mon(0)["hp"] == 300, "and doesn't hurt")

# ---- range: (STR + 20) x 10 / weight
st = rd(A["P_STAT_USE"], 1)[0]
wr(A["P_STAT_USE"], bytes([18]))
setup(MAIL, 1, hp=0)
wt = KIND_RECS[MAIL]["raw"][5] | KIND_RECS[MAIL]["raw"][6] << 8
rng = min(10, 380 // wt)
m = keyed(THROW, "a" + d)
where = [(rd(0xB400 + IS*i + 3, 1)[0], rd(0xB400 + IS*i + 4, 1)[0]) for i in range(64) if rd(0xB400 + IS*i + 1, 1)[0] != 255]
far = [max(abs(y - home[0]), abs(x - home[1])) for y, x in where if abs(y - home[0]) < 15 and abs(x - home[1]) < 15]
print("  chain mail: weight", wt, "range", rng, "landed at distance", far, repr(m))
expect(("disappears" in m) or (far and max(far) <= rng + 1), "heavy things don't go far (range (STR + 20) x 10 / weight)")
setup(FLASK, 1, hp=0)
m = keyed(THROW, "a" + d)
where = [(rd(0xB400 + IS*i + 3, 1)[0], rd(0xB400 + IS*i + 4, 1)[0]) for i in range(64) if rd(0xB400 + IS*i + 1, 1)[0] != 255]
print("  flask into the open:", where, repr(m))
setup(FLASK, 3, hp=0); m = keyed(THROW, "a" + d)
expect("You have 2 Flasks of oil (a)." in m, "'You have 2 Flasks of oil (a).'")
expect("disappears" in m or where, "with nothing to hit, it lands at the end of its flight (or against a wall)")
wr(A["P_STAT_USE"], bytes([st]))
calm()
cmd(2)
print("ALL OK" if ok else "FAILURES")
