import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
C_MOVE, C_LOOK, C_MAP, C_LOCATE, C_MESSAGES, C_SYMBOL, C_KNOWLEDGE = 0, 33, 34, 35, 36, 37, 38
KEY = {(1, -1): "1", (1, 0): "2", (1, 1): "3", (0, -1): "4", (0, 1): "6", (-1, -1): "7", (-1, 0): "8", (-1, 1): "9"}
def shots(cmdno, keys, n, dx=0, dy=0, stop="READ_ASCII"):
    """run a command, taking the screen at each of its first n key waits"""
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"])
    out = []
    for i in range(n):
        run_to(A[stop]); out.append(screen())
    run_to(BP)
    return out
def keyed(cmdno, keys=" ", dx=0, dy=0):
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
def turned(): return rd(A["TURN_TAKEN"], 1)[0]
calm(); full(); call(A["LIGHT_REFRESH"])
home = py(); dy, dx = open_line(3) or open_line(2); d = KEY[(dy, dx)]

# ---- ^P: old messages
wsq = 0xC000 + (home[0] + dy)*W + home[1] + dx; old = rd(wsq, 1)[0]
wr(wsq, bytes([(old & 0xF0) | 3]))					# (a wall, for a moment)
for t in range(3):									# "There is a wall in the way." x3
    keyed(C_MOVE, dx=dx, dy=dy)
wr(wsq, bytes([old]))
sc = shots(C_MESSAGES, " ", 1)[0]
lines = [l.strip() for l in sc[:30] if l.strip()]
print("  ^P, last lines:", lines[-3:])
expect(lines and lines[-1] == "There is a wall in the way." and lines.count("There is a wall in the way.") >= 3, "^P: the messages, the latest at the bottom")
expect(not turned(), "and no turn taken")

# ---- M: the map
sc = shots(C_MAP, " ", 1)[0]
border = [i for i, l in enumerate(sc) if l.strip().startswith("+--")]
inside = sc[border[0] + 1:border[1]] if len(border) == 2 else []
print("  map: border rows", border, "width", len(sc[border[0]].strip()) if border else 0, "@ in", [i for i, l in enumerate(sc) if "@" in l])
expect(len(border) == 2 and border[1] - border[0] == 23 and len(sc[border[0]].strip()) == 68, "'M': the level a third the size (66 x 22) in a border")
expect(sum(l.count("@") for l in inside) == 1 and any("#" in l for l in inside), "with you on it, and the walls you know")
expect(not turned(), "no turn")

# ---- W: locate
vx0 = rd(A["VIEW_X"], 1)[0]
way, word = ("6", "east") if vx0 < 60 else ("4", "west")
sc = shots(C_LOCATE, way + " ", 2)
m1, m2 = sc[0][0].strip(), sc[1][0].strip()
print("  locate:", repr(m1), "|", repr(m2))
expect(re.fullmatch(r"Map sector \[\d+,\d+\], which is your sector\. Look which direction\?", m1), "'W': 'Map sector [y,x], which is your sector.'")
expect(word + " of your sector" in m2, f"a direction moves it: '... which is {word} of your sector.'")
expect(rd(A["VIEW_X"], 1)[0] == vx0, "and the view comes back after")

# ---- x: look
DAG = next(i for i, k in enumerate(KINDS) if "Dagger" in k)
R = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and 1 <= r["level"] <= 5 and r["raw"][0] == ord("k")) if any(r["raw"][0] == ord("k") for r in RACES) else 1
for i in range(64): wr(0xB400 + IS*i + 1, bytes([255]))
item_sq = (home[0] + 2*dy, home[1] + 2*dx); mon_sq = (home[0] + 3*dy, home[1] + 3*dx)
wr(0xB400, bytes([DAG & 255, DAG >> 8, 1, item_sq[0], item_sq[1], 1, 0, 0, 0, 0, 0, 0, 0, 0]))
for p in (item_sq, mon_sq):
    a = 0xC000 + p[0]*W + p[1]; wr(a, bytes([rd(a, 1)[0] | 0x20]))
place(0, R, *mon_sq, hp=100, maxhp=100); call(A["MONSTERS_SEE_ALL"])
sc = shots(C_LOOK, d + "xxx", 3)
said = [x[0].strip() for x in sc]
print("  look:", said, "then", repr(msgline()), [l.strip() for l in screen()[:2]])
expect(said[0].startswith("Look which direction?"), "'x': 'Look which direction?'")
expect(said[1].startswith("You see a Dagger") and said[1].endswith("---pause---"), "'You see a Dagger (1d4) ---pause---' (nearest first)")
expect(re.match(r"You see an? .*\(unhurt\)\.", said[2]), "'You see a Kobold (unhurt).'")
expect("That's all you see in that direction." in msgline() and not turned(), "'That's all you see in that direction.' (no turn)")
wr(0xB000 + 3, struct.pack("<h", 30))						# 30 of 100: wounded
sc = shots(C_LOOK, d + "xxx", 3)
expect("(wounded)." in sc[2][0], "a hurt one: '(wounded)'")
sc = shots(C_LOOK, d + " ", 2)
expect("--Aborting look--" in msgline(), "space stops it: '--Aborting look--'")
back = {v: k for k, v in KEY.items()}
opp = KEY[(-dy, -dx)]
keyed(C_LOOK, opp + "xxxxxxxx")
print("  the other way:", repr(msgline()))
expect("in that direction." in msgline(), "the other way: nothing there, or something else")
calm()

# ---- /: identify a symbol
for keys, want in (("k", "k - Kobold."), ("D", "D - An Ancient Dragon (Beware).")):
    m = keyed(C_SYMBOL, keys)
    expect(m == want, f"'/' {keys}: '{want}'")
wr(A["ASCII_SYM"], bytes([2]))								# (as if Symbol Shift were held)
m = keyed(C_SYMBOL, "3")
wr(A["ASCII_SYM"], bytes([0]))
print("  Symbol Shift + 3:", repr(m))
expect(m == "# - A stone wall.", "Symbol Shift + 3 is '#': '# - A stone wall.'")
m = keyed(C_SYMBOL, "x")
expect(m == "Not Used.", "'Not Used.'")

# ---- %: self knowledge
install_keys(" "); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
set_reg(3, 0); set_reg(4, C_KNOWLEDGE << 8); set_pc(A["DISPATCH"])
run_to(A["DISPATCH@AFTER"]); sc = screen(); run_to(BP)
print("  %:", [l.strip() for l in sc[:4]])
expect(any(l.strip() for l in sc[1:30]) and not turned(), "'%': Self Knowledge (no turn)")
cmd(2)
print("ALL OK" if ok else "FAILURES")
