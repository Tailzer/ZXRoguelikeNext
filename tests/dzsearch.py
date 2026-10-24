import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
STAY = 3
def keyed(cmdno, dx=0, dy=0):
    call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
def sq(y, x): return rd(0xC000 + y*W + x, 1)[0]
def set_sq(y, x, t): wr(0xC000 + y*W + x, bytes([(sq(y, x) & 0xF0) | t]))
calm(); full(); call(A["LIGHT_REFRESH"])
print("  skills: srh", rd(A["P_SRH"], 1)[0], "fos", rd(A["P_FOS"], 1)[0], "race+class", rd(A["P_SRH_RACE"], 1)[0], rd(A["P_FOS_RACE"], 1)[0])
expect(rd(A["P_SRH"], 1)[0] == rd(A["P_SRH_RACE"], 1)[0] and rd(A["P_FOS_RACE"], 1)[0] > 0, "searching skill and frequency come from race and class")
y0, x0 = py()
dy, dx = open_line(2)
dy2, dx2 = -dx, dy if (dx, dy) != (0, 0) else (1, 0)	# a square beside the path
door = (y0 + dy, x0 + dx)
# 's' with a sharp eye finds it
set_sq(*door, 7); wr(A["P_SRH"], bytes([100]))
m = keyed(STAY)
print("  s:", repr(m), sq(*door) & 15)
expect("You have found a secret door." in m and sq(*door) & 15 == 5, "'s' finds a secret door beside you: 'You have found a secret door.'")
# no skill, never
set_sq(*door, 7); wr(A["P_SRH"], bytes([0]))
for t in range(20): keyed(STAY)
expect(sq(*door) & 15 == 7, "with no skill, it stays hidden")
# in the dark, a tenth of the chance
wr(A["P_SRH"], bytes([30])); wr(A["P_LIGHT"], bytes([0]))
found = 0
for t in range(60):
    set_sq(*door, 7)
    a = 0xC000 + y0*W + x0; wr(a, bytes([rd(a, 1)[0] & ~0x60 & 255]))	# (the player's square dark)
    keyed(STAY); found += sq(*door) & 15 == 5
dark = found
wr(A["P_LIGHT"], bytes([1])); call(A["LIGHT_REFRESH"]); found = 0
for t in range(60):
    set_sq(*door, 7); keyed(STAY); found += sq(*door) & 15 == 5
print("  skill 30, 60 searches: in the dark", dark, "lit", found)
expect(dark <= 6 and found >= 8, "in the dark only a tenth of the chance (30 -> 3)")
# walking past: frequency 1 searches every step
set_sq(*door, 7); wr(A["P_SRH"], bytes([100])); wr(A["P_FOS_RACE"], bytes([1])); wr(A["P_FOS"], bytes([1]))
side = next(((y0 + a, x0 + b) for a, b in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1))
             if (y0 + a, x0 + b) != door and sq(y0 + a, x0 + b) & 15 in (1, 2, 14) and max(abs(y0 + a - door[0]), abs(x0 + b - door[1])) == 1), None)
m = keyed(0, side[1] - x0, side[0] - y0)
print("  walking beside it:", repr(m), sq(*door) & 15, "player", py())
expect(sq(*door) & 15 == 5 and "You have found a secret door." in m, "walking: frequency 1 searches every step and finds it")
# frequency 50: rarely
set_sq(*door, 7); wr(A["P_FOS"], bytes([50])); found = 0
here = py()
for t in range(20):
    wr(A["PLAYER_Y"], bytes([y0])); wr(A["PLAYER_X"], bytes([x0])); set_sq(*door, 7)
    keyed(0, side[1] - x0, side[0] - y0); found += sq(*door) & 15 == 5
print("  frequency 50, 20 steps:", found)
expect(found <= 4, "with a high frequency number, searching as you walk is rare (1 in 50)")
cmd(2)
print("ALL OK" if ok else "FAILURES")
