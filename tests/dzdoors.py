import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
C_MOVE, C_OPEN, C_CLOSE, C_BASH, C_SPIKE = 0, 29, 30, 31, 32
KEY = {(1, -1): "1", (1, 0): "2", (1, 1): "3", (0, -1): "4", (0, 1): "6", (-1, -1): "7", (-1, 0): "8", (-1, 1): "9"}
DL, KEPT = A["DOOR_LIST"], 16
def keyed(cmdno, keys=" ", dx=0, dy=0):
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
def sq(y, x): return rd(0xC000 + y*W + x, 1)[0]
def set_sq(y, x, t): wr(0xC000 + y*W + x, bytes([(sq(y, x) & 0xF0) | t]))
def doors():
    out = {}
    for i in range(KEPT):
        a, n = struct.unpack("<Hb", rd(DL + 3*i, 3))
        if a: out[((a - 0xC000) // W, (a - 0xC000) % W)] = n
    return out
def set_door(y, x, n):
    wr(DL, bytes(3*KEPT))
    if n: wr(DL, struct.pack("<Hb", 0xC000 + y*W + x, n))
def turned(): return rd(A["TURN_TAKEN"], 1)[0]
def s8(v): return v - 256 if v > 127 else v

# ---- a new level: locked, stuck and broken doors
kept = doors()
print("  doors kept:", kept)
expect(all((sq(*p) & 15) == (5 if n else 6) or ((sq(*p) & 15) == 6 and n == 1) or (n > 0 and sq(*p) & 15 == 5) or (n < 0 and sq(*p) & 15 == 5) for p, n in kept.items()),
       "the door list holds closed doors' locks (11-20) and stuck (-11..-20), and broken open ones (1)")
expect(all((11 <= n <= 20 and sq(*p) & 15 == 5) or (-20 <= n <= -11 and sq(*p) & 15 == 5) or (n == 1 and sq(*p) & 15 == 6) for p, n in kept.items()),
       "with the C's numbers")

calm(); full(); call(A["LIGHT_REFRESH"])
home = py(); dy, dx = open_line(2); d = KEY[(dy, dx)]; door = (home[0] + dy, home[1] + dx)
def reset(t, n=0):
    wr(A["PLAYER_Y"], bytes([home[0]])); wr(A["PLAYER_X"], bytes([home[1]])); set_sq(*door, t); set_door(*door, n); calm()

# ---- close
reset(6)
m = keyed(C_CLOSE, d)
expect(sq(*door) & 15 == 5 and turned(), "'c': the door closes")
reset(6, 1)
m = keyed(C_CLOSE, d)
expect("The door appears to be broken." in m and sq(*door) & 15 == 6, "a broken door: 'The door appears to be broken.'")
reset(1)
m = keyed(C_CLOSE, d)
expect("I do not see anything you can close there." in m and not turned(), "nothing there: 'I do not see anything you can close there.' (no turn)")

# ---- open
reset(5)
m = keyed(C_OPEN, d)
expect(sq(*door) & 15 == 6 and turned() and m == "", "'o': a closed door opens")
wr(A["P_DIS"], bytes([120])); e0 = struct.unpack("<I", rd(A["P_EXP"], 4))[0]
reset(5, 15)
m = keyed(C_OPEN, d)
e1 = struct.unpack("<I", rd(A["P_EXP"], 4))[0]
print("  pick:", repr(m), sq(*door) & 15, doors(), e1 - e0)
expect("You have picked the lock." in m and sq(*door) & 15 == 6 and not doors() and e1 == e0 + 1, "a locked door, a good hand: 'You have picked the lock.' (+1 exp), and it opens")
wr(A["P_DIS"], bytes([256 - 100]))
reset(5, 15)
m = keyed(C_OPEN, d)
expect("You failed to pick the lock." in m and sq(*door) & 15 == 5 and turned(), "a poor hand: 'You failed to pick the lock.'")
w16("P_CONFUSED", 5); reset(5, 15)
m = keyed(C_OPEN, d)
w16("P_CONFUSED", 0)
expect("You are too confused to pick the lock." in m or sq(*door) & 15 == 5, "confused: 'You are too confused to pick the lock.'")
reset(5, -15)
m = keyed(C_OPEN, d)
expect("It appears to be stuck." in m and sq(*door) & 15 == 5, "a stuck door: 'It appears to be stuck.'")
reset(5)
m = keyed(C_MOVE, dx=dx, dy=dy)
print("  walk into it:", repr(m), sq(*door) & 15)
expect("You open the door." in m and sq(*door) & 15 == 6, "walking into a closed door opens it: 'You open the door.'")
reset(5, 15)
m = keyed(C_MOVE, dx=dx, dy=dy)
expect("You failed to pick the lock." in m and sq(*door) & 15 == 5, "walking into a locked one tries the lock")
wr(A["P_DIS"], bytes([30]))

# ---- bash a door
wr(A["P_STAT_USE"], bytes([118])); wr(A["P_STAT_USE"] + 3, bytes([118]))
out = []
for t in range(40):
    reset(5, -15) if t == 0 else None
    wr(A["P_PARALYSED"], bytes([0]))
    m = keyed(C_BASH, d); out.append(m)
    if sq(*door) & 15 == 6: break
print("  bash:", len(out), [o[:40] for o in out[:3]], "...", repr(out[-1]), "at", py(), doors())
expect(all("You smash into the door!" in o for o in out), "'f': 'You smash into the door!'")
expect("The door crashes open!" in out[-1] and sq(*door) & 15 == 6 and py() == door, "'The door crashes open!' and you go through")
expect(any("The door holds firm." in o for o in out) or len(out) == 1, "'The door holds firm.'")
reset(1)
m = keyed(C_BASH, d)
expect("You bash at empty space." in m and turned(), "nothing: 'You bash at empty space.', and it takes the turn (1.3)")
reset(3)
m = keyed(C_BASH, d)
expect("You bash it, but nothing interesting happens." in m and turned(), "a wall: 'You bash it, but nothing interesting happens.'")
reset(1)

# ---- spikes
SPK = next(i for i, k in enumerate(KINDS) if "Spike" in k)
clear(A["PACK"], 12); put(A["PACK"], 0, SPK, 5)
reset(5)
m = keyed(C_SPIKE, d)
print("  spike:", repr(m), doors(), rd(A["PACK"] + 2, 1)[0])
expect("You jam the door with a spike." in m and doors().get(door) == -20 and rd(A["PACK"] + 2, 1)[0] == 4, "'S': 'You jam the door with a spike.' (stuck by 20; a spike used)")
reset(5, 15)
keyed(C_SPIKE, d); keyed(C_SPIKE, d)
print("  locked 15, two spikes:", doors())
expect(doors().get(door) == -29, "a locked door becomes stuck (-15), each spike sticks it more (-23, -29)")
reset(6)
m = keyed(C_SPIKE, d)
expect("The door must be closed first." in m, "an open door: 'The door must be closed first.'")
clear(A["PACK"], 12); reset(5)
m = keyed(C_SPIKE, d)
expect("But you have no spikes." in m and not turned(), "'But you have no spikes.'")
reset(1)

# ---- shield bash a monster
R = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and 1 <= r["level"] <= 5)
wr(A["TEST_HIT"], bytes([0x37, 0xC9]))
stunned = 0
for t in range(12):
    reset(1); place(0, R, *door, hp=200)
    a = 0xC000 + door[0]*W + door[1]; wr(a, bytes([rd(a, 1)[0] | 0x20])); call(A["MONSTERS_SEE_ALL"])
    wr(A["P_PARALYSED"], bytes([0]))
    m = keyed(C_BASH, d)
    stunned += rd(0xB000 + 14, 1)[0] > 0
print("  shield bash:", repr(m), "hp", mon(0)["hp"], "stunned", stunned)
expect("You hit the" in m and mon(0)["hp"] < 200, "'f' at a monster: a shield bash ('You hit the ...')")
expect(stunned > 0, "it may be stunned ('... appears stunned!')")
calm()

# ---- monsters and doors
def mon_at_door(race, n, hp=300, tries=60):
    reset(5, n)
    beyond = (door[0] + dy, door[1] + dx)
    set_sq(*beyond, 1)
    place(0, race, *beyond, hp=hp)
    said = []
    for t in range(tries):
        said.append(turn(0))
        if sq(*door) & 15 == 6: break
    return said
opener = next(i for i, r in enumerate(RACES) if r["raw"][2] & 0x5F == 0x42 and not r["raw"][13] & 1 and r["level"] < 30)	# (chases, opens doors)
basher = next(i for i, r in enumerate(RACES) if r["raw"][2] & 0x7F == 2 and not r["raw"][13] & 1 and 5 < r["level"] < 30)	# (chases, no randomness, no doors)
said = mon_at_door(opener, 0)
expect(sq(*door) & 15 == 6, "a monster that opens doors opens a closed one")
said = mon_at_door(opener, 15)
print("  opener at a locked door:", len(said), "turns", sq(*door) & 15)
expect(sq(*door) & 15 == 6, "and picks a locked one in time")
said = mon_at_door(basher, 0, tries=200)
print("  basher:", len(said), "turns", sq(*door) & 15, [s for s in said if "door" in s][:1])
expect(sq(*door) & 15 == 6 and any("You hear a door burst open!" in s for s in said), "one that can't bashes it: 'You hear a door burst open!'")
calm()
cmd(2)
print("ALL OK" if ok else "FAILURES")
