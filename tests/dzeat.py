import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
PAGE_LEVEL, MEM_PAGE = 40, 74
cmd(10, bytes([2, 57])); call(A["MEM_FORGET"])
def steady(r): return r["raw"][2] & 2 and not r["raw"][2] & 0x1D and not r["raw"][13] & 1
def exp_(i): return RACES[i]["raw"][3] | RACES[i]["raw"][4] << 8
cmd(10, bytes([1, 77])); RI = rd(A["RINFO_TABLE"], len(NAMES) * 11)
def eats(i): return RI[i*11 + 2] & 8
EATERS = [i for i in range(len(NAMES)) if eats(i)]
print("  eaters:", [NAMES[i] for i in EATERS])
expect(len(EATERS) == 12, "twelve races eat others (CM_EATS_OTHER)")
EATER = next(i for i in EATERS if steady(RACES[i]) and not RACES[i]["raw"][14] & 6)
WEAK = next(i for i, r in enumerate(RACES) if exp_(i) < exp_(EATER) and not eats(i) and not r["raw"][13] & 1 and r["level"] > 0)
STRONG = next(i for i, r in enumerate(RACES) if exp_(i) > exp_(EATER) and not r["raw"][13] & 1 and not r["raw"][14] & 6)
PLAIN = next(i for i, r in enumerate(RACES) if steady(r) and not eats(i) and exp_(i) > exp_(WEAK) and not r["raw"][14] & 6)
print("  eater", NAMES[EATER], exp_(EATER), " weak", NAMES[WEAK], exp_(WEAK), " strong", NAMES[STRONG], exp_(STRONG), " plain", NAMES[PLAIN])
calm(); full(); call(A["LIGHT_REFRESH"])
walk_to_room(); call(A["UPDATE_VIEW"])
y0, x0 = py(); dy, dx = open_line(3)
near, far = (y0 + dy, x0 + dx), (y0 + 2*dy, x0 + 2*dx)
wr(A["P_EFLAGS2"], bytes([0x20]))					# (telepathy: all seen)
def setup(mover, other):
    calm(); place(0, mover, *far); place(1, other, *near, hp=50)
    for s_ in (0, 1): wr(0xB000 + 16*s_ + 9, bytes([1])); wr(0xB000 + 16*s_ + 11, bytes([1]))	# (seen)
    set_reg(6, 0xB000); call(A["MON_TURN"])
    return (mon(0)["y"], mon(0)["x"]), not mon(1)["free"]
at, alive = setup(EATER, WEAK)
print("  eats:", at, alive, "near", near, "far", far, "move", hex(RACES[EATER]["raw"][2]), "speed", RACES[EATER]["raw"][8])
expect(at == near and not alive, f"{NAMES[EATER]} steps where the {NAMES[WEAK]} stood, and it's gone (eaten)")
cmd(10, bytes([1, MEM_PAGE + (EATER >> 8)])); cm = struct.unpack("<I", rd(0x2000 + (EATER & 255)*32, 4))[0]
expect(cm & 0x80000, "seen: 'kill weaker creatures' remembered")
at, alive = setup(EATER, STRONG)
expect(at == far or at != near and alive, f"worth more ({NAMES[STRONG]}): not eaten")
expect(alive, "and still there")
at, alive = setup(PLAIN, WEAK)
expect(at != near and alive, f"one that doesn't eat ({NAMES[PLAIN]}): no")

# ---- the black ooze breeds onto weaker neighbours
OOZE = next(i for i, n in enumerate(NAMES) if n == "Black ooze")
cy, cx = far
def ring(race):
    calm(); place(0, OOZE, cy, cx); k = 1
    for a in (-1, 0, 1):
        for b in (-1, 0, 1):
            if (a or b) and (cy + a, cx + b) != (y0, x0):
                place(k, race, cy + a, cx + b); k += 1
    return k - 1
cheap = next(i for i, r in enumerate(RACES) if exp_(i) < exp_(OOZE) and not r["raw"][13] & 1 and r["level"] > 0)
dear = next(i for i, r in enumerate(RACES) if exp_(i) > exp_(OOZE) and not r["raw"][13] & 1 and r["level"] > 0)
n = ring(cheap)
cmd(10, bytes([2, PAGE_LEVEL])); set_reg(6, 0xB000); r_ = call(A["BREED_EAT"], de=(cy << 8) | cx)
races = [mon(s_)["race"] for s_ in range(64) if not mon(s_)["free"]]
print("  ooze among", NAMES[cheap], ":", races.count(OOZE), "oozes,", races.count(cheap), "of", n)
expect(races.count(OOZE) == 2 and races.count(cheap) == n - 1, "a black ooze breeds onto a weaker neighbour, eating it")
n = ring(dear)
cmd(10, bytes([2, PAGE_LEVEL])); set_reg(6, 0xB000); call(A["BREED_EAT"], de=(cy << 8) | cx)
races = [mon(s_)["race"] for s_ in range(64) if not mon(s_)["free"]]
expect(races.count(OOZE) == 1 and races.count(dear) == n, "but not onto one worth more")
cmd(2)
print("ALL OK" if ok else "FAILURES")
