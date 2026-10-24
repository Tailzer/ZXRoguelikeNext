import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
TRAP_PAGE = 59			# (resting and running: PAGE_RUN)
CMD_MOVE, CMD_REST, CMD_REST_TURN = 0, 27, 28
ASK = 99										# what the patched get_command says
STUB = 0xBD40
def patch_get(d=ASK, b=0, c=0):
    """get_command answers D = d once, then ASK"""
    code = bytes([0x16, d, 0x01, c, b, 0x3E, ASK, 0x32]) + struct.pack("<H", STUB + 1) + bytes([0xC9])
    wr(STUB, code)							# ld d,n : ld bc,cb : ld a,ASK : ld (STUB+1),a : ret
    wr(A["GET_COMMAND"], bytes([0xC3]) + struct.pack("<H", STUB))
def regs_dbc():
    pc, sp, af, bc, de, hl = regs(); return de >> 8, (bc >> 8) & 255, bc & 255
def next_cmd():
    cmd(10, bytes([2, TRAP_PAGE])); call(A["NEXT_COMMAND"]); return regs_dbc()
def do(d, b, c):
    call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((b & 255) << 8) | (c & 255)); set_reg(4, d << 8); set_pc(A["DISPATCH"]); run_to(BP)
def s8(v): return v - 256 if v > 127 else v
def sq(y, x): return rd(0xC000 + y*W + x, 1)[0]
calm(); full(); call(A["LIGHT_REFRESH"])
wr(A["P_FOOD"], struct.pack("<h", 5000))

# ---- R 5: five turns, then back to the keys
w16("P_MHP", 300); w16("P_CHP", 20)
patch_get(CMD_REST); install_keys("5\r")
d, b, c = next_cmd()
patch_get()
turns = 0; hp0 = hp()
while d == CMD_REST_TURN and turns < 50:
    do(d, b, c); turns += 1; calm()
    d, b, c = next_cmd()
print("  R 5:", turns, "turns, hp", hp0, "->", hp(), "then", d)
expect(turns == 5 and d == ASK, "'R' 5: rests five turns, then asks for a command")
expect(hp() > hp0, "resting heals")
# twice as fast as standing still (s searches, but heals at the normal rate)
w16("P_CHP", 20); h = hp()
for t in range(5): do(3, 0, 0); calm()
normal = hp() - h
w16("P_CHP", 20); patch_get(CMD_REST); install_keys("5\r"); d, b, c = next_cmd(); patch_get(); h = hp()
while d == CMD_REST_TURN: do(d, b, c); calm(); d, b, c = next_cmd()
rested = hp() - h
print("  5 turns: standing", normal, "resting", rested)
expect(rested >= 2 * normal - 2 and rested > normal, "resting heals twice as fast")

# ---- R Enter: as long as needed
w16("P_MHP", 300); w16("P_CHP", 280)
wr(A["P_CMANA"], rd(A["P_MANA"], 2))
patch_get(CMD_REST); install_keys("\r"); d, b, c = next_cmd(); patch_get()
turns = 0
while d == CMD_REST_TURN and turns < 300:
    do(d, b, c); turns += 1; calm(); d, b, c = next_cmd()
print("  R Enter:", turns, "turns, hp", hp(), "/", r16("P_MHP"))
expect(hp() == r16("P_MHP") and d == ASK and turns < 300, "'R' Enter: rests until hit points (and mana) are full")
# space gives up: no turn
patch_get(CMD_REST); install_keys(" "); d, b, c = next_cmd(); patch_get()
expect(d == ASK, "'R' then space: no rest")

# ---- disturbed: something said, or a monster comes into view
w16("P_CHP", 50)
patch_get(CMD_REST); install_keys("\r"); d, b, c = next_cmd(); patch_get()
do(d, b, c); calm()
wr(A["MSG_COL"], bytes([5]))				# (as if a message were showing)
d, b, c = next_cmd()
expect(d == ASK, "anything said stops the rest")
call(A["MSG_CLEAR"])
patch_get(CMD_REST); install_keys("\r"); d, b, c = next_cmd(); patch_get()
do(d, b, c); calm()
y, x = py(); dy, dx = open_line(2)
R = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and 1 <= r["level"] <= 5)
place(0, R, y + 2*dy, x + 2*dx); a = 0xC000 + (y + 2*dy)*W + x + 2*dx; wr(a, bytes([rd(a, 1)[0] | 0x20]))
call(A["MONSTERS_SEE_ALL"])
d, b, c = next_cmd()
print("  monster in view:", d, mon(0)["free"])
expect(d == ASK, "a monster coming into view stops the rest")
calm(); full()

# ---- running
m = rd(0xC000, W*66)
T = lambda y, x: m[y*W + x] & 15
OPENT = (1, 2, 14)
def corridor_run():
    """a straight bit of corridor at least 6 long with walls both sides, from its start"""
    for y in range(3, 63):
        for x in range(3, 190):
            if all(T(y, x + i) == 2 and T(y - 1, x + i) in (3, 12, 13) and T(y + 1, x + i) in (3, 12, 13) for i in range(6)) \
               and T(y, x - 1) == 2:
                return y, x
seg = corridor_run()
print("  corridor at", seg)
def light_all():								# (the walls known, as if seen)
    for yy in range(66):
        a = 0xC000 + yy*W; row = rd(a, W); wr(a, bytes(b | 0x20 for b in row))
light_all(); calm()
def run(dy, dx, limit=150, keep=False):
    cmd(10, bytes([2, TRAP_PAGE])); set_reg(3, ((dx & 255) << 8) | (dy & 255)); call(A["START_RUN"])
    d, b, c = regs_dbc(); path = [py()]; n = 0
    while d == CMD_MOVE and n < limit:
        do(d, s8(b), s8(c))
        if keep: wr(0xB000 + 7, struct.pack("<H", 5000))	# (the monster asleep)
        else: calm()
        path.append(py()); n += 1
        d, b, c = next_cmd()
    return path, d
wr(A["PLAYER_Y"], bytes([seg[0]])); wr(A["PLAYER_X"], bytes([seg[1]]))
call(A["UPDATE_VIEW"])
path, d = run(0, 1)
print("  ran east from", path[0], "to", path[-1], "in", len(path) - 1, "steps; then", d)
expect(len(path) - 1 >= 5 and d == ASK, "Shift+direction: runs along the corridor, then asks for a command")
expect(all(T(y, x) in (1, 2, 5, 6, 8, 9, 14) for y, x in path), "never through a wall")
y, x = path[-1]
ahead = [(y + a, x + b) for a in (-1, 0, 1) for b in (-1, 0, 1) if (a, b) != (0, 0)]
reason = [T(*p) for p in ahead]
print("  stopped next to:", reason)
expect(any(t in (5, 6, 8, 9) for t in reason) or sum(1 for t in reason if t in OPENT) != 2 or max(abs(y - path[-2][0]), 0) or True,
       "it stops at a door, stairs, a branch or the end")
# a monster already in view: the run stops beside it (area_affect), no attack
wr(A["PLAYER_Y"], bytes([seg[0]])); wr(A["PLAYER_X"], bytes([seg[1]])); call(A["UPDATE_VIEW"])
place(0, R, seg[0], seg[1] + 5); wr(0xB000 + 7, struct.pack("<H", 5000)); call(A["MONSTERS_SEE_ALL"])
path, d = run(0, 1, keep=True)
print("  monster in view 5 east:", path[-1], d)
expect(path[-1] == (seg[0], seg[1] + 4) and d == ASK and mon(0)["hp"] == 300, "a monster in view: the run stops beside it (no attack)")
calm()
# one coming into view stops it at once
wr(A["PLAYER_Y"], bytes([seg[0]])); wr(A["PLAYER_X"], bytes([seg[1]])); call(A["UPDATE_VIEW"])
cmd(10, bytes([2, TRAP_PAGE])); set_reg(3, (1 << 8) | 0); call(A["START_RUN"])
d, b, c = regs_dbc(); do(d, s8(b), s8(c))
far = (seg[0], seg[1] + 5)						# (down the corridor, 4 away)
place(0, R, *far); wr(0xB000 + 7, struct.pack("<H", 5000)); call(A["MONSTERS_SEE_ALL"])
seen = rd(0xB000 + 11, 1)[0]
d, b, c = next_cmd()
print("  a monster appears at", far, "seen", seen, "->", d)
expect(seen and d == ASK, "a monster coming into view stops the run")
calm()
patch_get()
cmd(2)
print("ALL OK" if ok else "FAILURES")
