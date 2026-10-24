import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
IS = 14
LS = EQ + 10*IS							# the light slot
KN = lambda name: next(i for i, k in enumerate(KIND_RECS) if k["name"] == name)
TORCH, LANTERN, FLASK = KN("Wooden Torch"), KN("Brass Lantern"), KN("Flask of oil")
PHIAL = next(i for i, k in enumerate(KIND_RECS) if "Phial" in k["name"])
def item(k, num=1, fuel=0, ident=5):
    return bytes([k & 255, k >> 8, num, 0, 0, 1, fuel & 255, fuel >> 8, ident, 0, 0, 0, 0, 0])
def fuel(base=LS): return struct.unpack("<H", rd(base + 6, 2))[0]
def light(): return rd(A["P_LIGHT"], 1)[0]
def lamp_lit():
    y, x = py(); return all(rd(0xC000 + (y + a)*W + x - 1, 3)[i] & 0x40 for a in (-1, 0, 1) for i in range(3))
WIELD, TAKEOFF, READ, FUEL, STAY = 6, 7, 13, 23, 3
def keyed(cmdno, keys=""):
    install_keys(keys or " ")
    call(A["MSG_CLEAR"])
    wr(A["TURN_TAKEN"], bytes([0]))					# (as the main loop does)
    set_reg(3, 0); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
def turn(): return keyed(STAY)
# a dark corridor, away from rooms
m = rd(0xC000, W*66)
spot = next((i // W, i % W) for i, b in enumerate(m) if b & 15 == 2 and not b & 0x10 and all(m[i + d] & 15 in (2, 3, 12, 13) for d in (-1, 1, -W, W)))
wr(A["PLAYER_Y"], bytes([spot[0]])); wr(A["PLAYER_X"], bytes([spot[1]]))
for i in range(-1, 2):					# forget the light the harness left
    a = 0xC000 + (spot[0] + i)*W + spot[1] - 1; wr(a, bytes(b & ~0x60 & 255 for b in rd(a, 3)))
clear(EQ, 11); wr(A["P_LIGHT"], bytes([0])); cmd(10, bytes([2, 42])); call(A["CALC_BONUSES"])
clear(A["PACK"], 12)
wr(A["PACK"], item(TORCH, 5, 4000))
scroll = next(i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 3)
wr(A["PACK"] + IS, item(scroll, 1))
turn()
print("  in the dark:", light(), lamp_lit())
expect(light() == 0 and not lamp_lit(), "no light source: the squares round you stay dark")
m_ = keyed(READ, "b")
expect("You have no light to read by." in m_, "reading in the dark: 'You have no light to read by.'")

# wield a torch from the bundle of five
m_ = keyed(WIELD, "a")
print("  wield:", repr(m_), "pack", pack()[0]["num"], "slot fuel", fuel(), "light", light())
expect("Your light source is a Wooden Torch with" in m_ and "turns of light" in m_, "'Your light source is a Wooden Torch with 4000 turns of light.'")
expect(pack()[0]["num"] == 4 and rd(LS + 2, 1)[0] == 1, "one torch from the bundle; four left in the pack")
expect(light() == 1 and fuel() == 3999 and lamp_lit(), "the light comes on, and the torch burns a turn of fuel")
turn(); turn()
expect(fuel() == 3997, "a turn of fuel each turn")

# growing faint, then out
wr(LS + 6, struct.pack("<H", 30)); faint = 0
for t in range(29):
    faint += "growing faint" in turn()
print("  faint messages in 29 turns:", faint, "fuel", fuel())
expect(faint >= 1 and fuel() == 1, "under 40: 'Your light is growing faint.' (1 in 5 a turn)")
m_ = turn()
print("  out:", repr(m_), light(), lamp_lit())
expect("Your light has gone out!" in m_ and light() == 0 and not lamp_lit(), "at 0: 'Your light has gone out!' and the dark")

# torches stack by fuel
clear(A["PACK"], 12); wr(A["PACK"], item(TORCH, 2, 4000))
m_ = keyed(TAKEOFF, "k")
print("  take off:", repr(m_), [(r["num"], r["value"]) for r in pack() if r])
expect("Your light source was a Wooden Torch with 0 turns of light." in m_, "'Your light source was a Wooden Torch with 0 turns of light.'")
expect(sum(1 for r in pack() if r) == 2, "a burnt-out torch doesn't stack with fresh ones")

# lanterns and oil
clear(A["PACK"], 12)
wr(LS, item(LANTERN, 1, 7000)); wr(A["P_LIGHT"], bytes([1]))
wr(A["PACK"], item(FLASK, 3, 7500))
m_ = keyed(FUEL)
print("  refill:", repr(m_), fuel(), pack()[0]["num"])
expect("Your lamp is more than half full." in m_ and fuel() in (14500, 14499), "a flask: 'Your lamp is more than half full.'")
expect(pack()[0]["num"] == 2, "and one flask is used")
m_ = keyed(FUEL)
print("  overflow:", repr(m_), fuel())
expect(fuel() in (15000, 14999) and pack()[0]["num"] == 1, "too much: 'Your lamp overflows...', 'Your lamp is full.' (15000)")
wr(LS + 6, struct.pack("<H", 100)); keyed(FUEL)
expect(fuel() in (7600, 7599), "from 100: 7600")
clear(A["PACK"], 12); m_ = keyed(FUEL)
expect("You have no oil." in m_, "no flasks: 'You have no oil.'")
wr(LS, item(TORCH, 1, 500)); wr(A["PACK"], item(FLASK, 1, 7500)); m_ = keyed(FUEL)
print("  torch refill:", repr(m_), fuel())
expect("But you are not using a lamp." in m_ and fuel() == 500, "a torch can't be refilled: 'But you are not using a lamp.'")

# the Phial: a light that never burns down, and its activation
clear(A["PACK"], 12); clear(EQ, 11); wr(A["P_LIGHT"], bytes([0]))
wr(A["PACK"], item(PHIAL, 1, 0, 5))
m_ = keyed(WIELD, "a")
for t in range(5): turn()
print("  phial:", repr(m_), light(), lamp_lit())
expect("Phial" in m_ and "turns of light" not in m_ and light() == 1 and lamp_lit(), "the Phial of Galadriel: no fuel, and it shines on")
wr(A["P_STAT_USE"] + 1, bytes([118])); wr(A["P_LEV"], bytes([30]))
m_ = keyed(17, "a")
print("  activate:", repr(m_))
expect("The phial wells with clear light..." in m_ or "white light" in m_, "activating it: 'The phial wells with clear light...'")

# a monster that eats light
clear(EQ, 11); wr(LS, item(TORCH, 1, 5000)); wr(A["P_LIGHT"], bytes([1]))
wr(A["TEST_HIT"], bytes([0x37, 0xC9]))
STUB = 0xBD80
wr(STUB, bytes([0xCD]) + struct.pack("<H", A["MON_RACE"]) + bytes([0xC3]) + struct.pack("<H", A["MON_ATTACK"]))
R = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and 5 <= r["level"] <= 25)
cmd(10, bytes([1, 44 + R // 128])); wr(0x2000 + (R % 128)*64 + 16, bytes([23, 5, 1, 1] + [0]*12))
calm(); y, x = py(); dy, dx = open_line(1) or (0, 1); place(0, R, y + dy, x + dx)
call(A["MSG_CLEAR"]); set_reg(6, 0xB000); call(STUB)
print("  eat light:", repr(msgline()), fuel())
expect("Your light dims." in msgline() and 4500 <= fuel() <= 4749, "a blow that eats light: 250 + 1d250 fuel gone ('Your light dims.')")
calm()
cmd(2)
print("ALL OK" if ok else "FAILURES")
