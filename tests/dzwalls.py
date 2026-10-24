import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
C_MOVE = 0
PAGE_RECALL, MEM_PAGE = 73, 74
DL = A["DOOR_LIST"]
cmd(10, bytes([2, 57])); call(A["MEM_FORGET"])
def sq(y, x): return rd(0xC000 + y*W + x, 1)[0]
def set_sq(y, x, t): wr(0xC000 + y*W + x, bytes([(sq(y, x) & 0xF0) | t]))
def mem(race):
    cmd(10, bytes([1, MEM_PAGE + (race >> 8)])); r = rd(0x2000 + (race & 255)*32, 32)
    return struct.unpack("<I", r[0:4])[0], struct.unpack("<I", r[20:24])[0]
def keyed(cmdno, keys=" ", dx=0, dy=0):
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
# steady chasers (MV_ATT_NORM, no random moves), awake, not unique
def steady(r): return r["raw"][2] & 2 and not r["raw"][2] & 0x1D and not r["raw"][13] & 1
PHASER = next(i for i, r in enumerate(RACES) if r["raw"][14] & 2 and steady(r) and not r["raw"][13] & 4)
BORER = next(i for i, r in enumerate(RACES) if r["raw"][14] & 4 and not r["raw"][14] & 2 and steady(r))
PLAIN = next(i for i, r in enumerate(RACES) if not r["raw"][14] & 6 and steady(r) and r["level"] > 2 and not r["raw"][2] & 0x40)
print("  phaser:", NAMES[PHASER], " borer:", NAMES[BORER], " plain:", NAMES[PLAIN])
calm(); full(); no_resists(); call(A["LIGHT_REFRESH"])
y0, x0 = py()
dy, dx = open_line(3)
wall = (y0 + 2*dy, x0 + 2*dx)						# player . WALL monster
far = (y0 + 3*dy, x0 + 3*dx)
def setup(race, t):
    calm(); wr(DL, bytes(48))
    for k in (1, 2, 3, 4):
        set_sq(y0 + k*dy, x0 + k*dx, 1)
    set_sq(*wall, t)
    place(0, race, *far)
    wr(0xB000 + 7, bytes([0, 0]))					# awake
def go(n=1):
    for i in range(n):
        call(A["MSG_CLEAR"]); set_reg(6, 0xB000); call(A["MON_TURN"])
    return msgline()

# ---- a plain monster: the wall stops it
setup(PLAIN, 3); go()
expect((mon(0)["y"], mon(0)["x"]) != wall and sq(*wall) & 15 == 3, f"{NAMES[PLAIN]}: granite stops it")

# ---- passing through
for t, what in ((3, "granite"), (12, "magma"), (10, "rubble"), (5, "a closed door")):
    setup(PHASER, t); go()
    expect((mon(0)["y"], mon(0)["x"]) == wall and sq(*wall) & 15 == t and sq(*wall) & 0x80,
           f"{NAMES[PHASER]} (CM_PHASE) steps into {what}, which stays")
setup(PHASER, 4); go()
expect((mon(0)["y"], mon(0)["x"]) != wall, "but not into permanent rock")
setup(PHASER, 3); wr(0xC000 + wall[0]*W + wall[1], bytes([sq(*wall) | 0x20])); go()
cm, cd = mem(PHASER)
print("  phaser memory:", hex(cm), "ml", rd(0xB000 + 11, 1)[0])
expect(cm & 0x40000 and rd(0xB000 + 11, 1)[0], "seen doing it (a lit wall): 'pass through walls' remembered")

# ---- digging through
setup(BORER, 3); go()
print("  borer:", (mon(0)["y"], mon(0)["x"]), wall, sq(*wall) & 15)
expect((mon(0)["y"], mon(0)["x"]) == wall and sq(*wall) & 15 in (1, 2, 14), f"{NAMES[BORER]} (BREAK_WALL) digs through granite, and steps in")
cm, cd = mem(BORER)
expect(cd & 0x200000, "it's known to bore, seen or not (BREAK_WALL)")
setup(BORER, 13); go()
expect(sq(*wall) & 15 in (1, 2, 14), "quartz too")
setup(BORER, 4); go()
expect(sq(*wall) & 15 == 4 and (mon(0)["y"], mon(0)["x"]) != wall, "permanent rock: never")
setup(BORER, 5); m = go()
doors = {struct.unpack("<H", rd(DL + 3*i, 2))[0]: rd(DL + 3*i + 2, 1)[0] for i in range(16)}
print("  door:", repr(m), sq(*wall) & 15, doors.get(0xC000 + wall[0]*W + wall[1]))
expect(sq(*wall) & 15 == 6 and doors.get(0xC000 + wall[0]*W + wall[1]) == 1 and "You hear a door burst open!" in m,
       "a closed door: 'You hear a door burst open!', and it's broken")
setup(BORER, 7); m = go()
expect(sq(*wall) & 15 == 6 and "You hear a door burst open!" in m, "a secret door too")
# in a room: like the floor beside it
room = [(y, x) for y in range(5, 60) for x in range(5, 190) if sq(y, x) & 0x10 and sq(y, x) & 15 == 3
        and any(sq(y + a, x + b) & 15 in (1, 14) for a in (-1, 0, 1) for b in (-1, 0, 1))]
if room:
    ry, rx = room[0]
    nb = next(sq(ry + a, rx + b) for a in (-1, 0, 1) for b in (-1, 0, 1) if sq(ry + a, rx + b) & 15 in (1, 14))
    cmd(10, bytes([2, 58])); set_reg(6, 0xB000)
    call(A["MON_DIG"], de=(ry << 8) | rx)
    print("  room wall:", hex(sq(ry, rx)), "beside", hex(nb))
    expect(sq(ry, rx) & 15 == nb & 15 and (sq(ry, rx) & 0x20) == (nb & 0x20), "a room's wall: floor like the floor beside it, lit or not (twall)")

# ---- the player and a monster in the rock
setup(PHASER, 3)
for t in range(3): go()
mon0 = (mon(0)["y"], mon(0)["x"])
calm(); place(0, PHASER, y0 + dy, x0 + dx, hp=500); set_sq(y0 + dy, x0 + dx, 3)
wr(0xB000 + 11, bytes([1]))
cmd(10, bytes([7, 70])); wr(0xE000, bytes(32*80)); cmd(10, bytes([7, 33]))
m = keyed(C_MOVE, dx=dx, dy=dy)
cmd(10, bytes([7, 70])); lg = bytes(rd(0xE000, 32*80)).decode("latin-1"); cmd(10, bytes([7, 33]))
said = [l for l in lg.split("\0") if l.startswith("You")]
print("  seen in the wall:", said[:2])
expect(any(l.startswith(("You hit", "You miss")) for l in said) and py() == (y0, x0), "walking into a seen monster in the rock attacks it")
wr(0xB000 + 11, bytes([0]))
m = keyed(C_MOVE, dx=dx, dy=dy)
print("  unseen:", repr(m))
expect("There is a wall in the way." in m and mon(0)["hp"] >= 0, "unseen: 'There is a wall in the way.'")
set_sq(y0 + dy, x0 + dx, 1); calm()

# ---- recalled
cmd(10, bytes([1, MEM_PAGE + (BORER >> 8)])); wr(0x2000 + (BORER & 255)*32 + 16, struct.pack("<H", 1))
install_keys(" "); cmd(10, bytes([2, PAGE_RECALL]))
pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp); set_reg(5, BORER)
set_pc(A["ROFF_RECALL"]); run_to(A["READ_ASCII"]); t = " ".join(l.strip() for l in screen() if l.strip()); run_to(BP)
expect("It can bore through rock." in t, "recall: 'It can bore through rock.'")
cmd(2)
print("ALL OK" if ok else "FAILURES")
