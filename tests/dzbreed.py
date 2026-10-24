import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
PAGE_RUN, MEM_PAGE = 59, 74
MM = A["MON_MULT"]
cmd(10, bytes([2, 57])); call(A["MEM_FORGET"])
BREEDERS = [i for i, r in enumerate(RACES) if r["raw"][2] & 0x80]
print("  breeders:", len(BREEDERS), [NAMES[i] for i in BREEDERS[:6]])
B = BREEDERS[0]
expect(len(BREEDERS) > 10 and any("worm mass" in NAMES[i] for i in BREEDERS), "the MULTIPLY races breed (worm masses...)")
calm(); full(); call(A["LIGHT_REFRESH"])
walk_to_room(); call(A["UPDATE_VIEW"])
y0, x0 = py()
spot = (y0 + 2, x0 + 2)
def mult(): return rd(MM, 1)[0]
def run(n):
    for t in range(n):
        for sl in range(64):
            if rd(0xB000 + 16*sl + 12, 1)[0] != 255:
                wr(0xB000 + 16*sl + 7, bytes([0, 0])); wr(0xB000 + 16*sl + 9, bytes([1]))
                set_reg(6, 0xB000 + 16*sl); call(A["MON_TURN"])
def rest(mode, count=0):
    cmd(10, bytes([2, PAGE_RUN])); wr(A["RR_MODE"], bytes([mode])); wr(A["RR_COUNT"], struct.pack("<H", count))
def fresh():
    calm(); wr(MM, bytes([0])); place(0, B, *spot)
    wr(0xB000 + 9, bytes([1]))

# ---- it breeds (seen: telepathy)
wr(A["P_EFLAGS2"], bytes([0x20]))
fresh(); run(60)
n, m = nmons(), mult()
print("  60 turns:", n, "monsters, bred", m)
expect(n > 1 and m == n - 1, "a worm mass breeds beside itself, awake; the level's count rises with each")
expect(all(mon(sl)["race"] == B for sl in range(64) if not mon(sl)["free"]), "the same kind")
# crowded: four round it, never
fresh()
for k, (a, b) in enumerate(((0, 1), (1, 0), (0, -1))):
    place(k + 1, B, spot[0] + a, spot[1] + b)
wr(MM, bytes([0]))
for t in range(40):
    set_reg(6, 0xB000); wr(0xB000 + 9, bytes([1]))
    cmd(10, bytes([2, 40])); call(A["MON_BREED"])
expect(mult() == 0, "four in the 9 squares (itself too): never")
# the level's cap
fresh(); wr(MM, bytes([76])); run(40)
expect(nmons() == 1 and mult() == 76, "75 bred on the level already: no more")
# resting
fresh(); rest(1, 5); run(40)
expect(nmons() == 1, "resting with a count: only on every 8th turn of it (5: never)")
fresh(); rest(1, 16)
for t in range(200):
    set_reg(6, 0xB000); wr(0xB000 + 7, bytes([0, 0])); cmd(10, bytes([2, 40])); call(A["MON_BREED"])
expect(nmons() > 1, "... 16: as if not resting")
rest(0)
# a death lowers the count
fresh(); run(60); m0 = mult()
sl = next(k for k in range(1, 64) if not mon(k)["free"])
set_reg(6, 0xB000 + 16*sl); call(A["MON_REMOVE"])
expect(mult() == m0 - 1, "any monster gone: one fewer counted")
# a new level: none bred
wr(A["DUN_LEVEL"], bytes([3])); call(A["NEW_LEVEL"])
expect(mult() == 0, "a new level starts the count again")
# remembered
cmd(10, bytes([1, MEM_PAGE + (B >> 8)])); cm = struct.unpack("<I", rd(0x2000 + (B & 255)*32, 4))[0]
print("  memory:", hex(cm))
expect(cm & 0x200000, "seen breeding: 'breed explosively' remembered")
cmd(2)
print("ALL OK" if ok else "FAILURES")
