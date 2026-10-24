import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
C_STAY, C_SAVE, C_QUIT = 3, 22, 39
PAGE_SCROLL, PAGE_SPELL = 53, 55
SAURON = A["RACE_SAURON"]; QL = A["QUEST_LEVEL"]
MORGOTH = next(i for i, n in enumerate(NAMES) if n.startswith("Morgoth"))
def keyed(cmdno, keys=" ", dx=0, dy=0):
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
def sq(y, x): return rd(0xC000 + y*W + x, 1)[0]
def stairs():
    m = rd(0xC000, W*66); return sum(1 for b in m if b & 15 == 8), sum(1 for b in m if b & 15 == 9)
def level(n):
    wr(A["DUN_LEVEL"], bytes([n])); call(A["NEW_LEVEL"]); calm(); full()
def gold(): return struct.unpack("<I", rd(A["P_GOLD"], 4))[0]
print("  Sauron is race", SAURON, NAMES[SAURON], "level", QL, "; Morgoth", MORGOTH)
expect(rd(A["P_QUEST"], 1)[0] == QL and rd(A["P_WINNER"], 1)[0] == 0, "a new character: Sauron waits on level 99, nobody has won")

# ---- Sauron's level while he lives
level(QL)
down, up = stairs()
print("  level 99, Sauron alive: down", down, "up", up)
expect(down == 0 and up >= 3, "no way down: its down stairs are up stairs")
wr(A["P_QUEST"], bytes([0])); level(QL)
down2, up2 = stairs()
expect(down2 >= 3, "with him dead, level 99 has stairs down")
wr(A["P_QUEST"], bytes([QL])); level(QL)
went = set()
for t in range(6):
    wr(A["DUN_LEVEL"], bytes([QL])); wr(A["P_NEW_LEVEL"], bytes([0]))
    cmd(10, bytes([2, PAGE_SCROLL])); call(A["SC_TELE_LEVEL"]); went.add(rd(A["DUN_LEVEL"], 1)[0])
wr(A["DUN_LEVEL"], bytes([QL])); wr(A["P_NEW_LEVEL"], bytes([0]))
print("  teleport level from 99:", went)
expect(went == {QL - 1}, "teleport level only rises from Sauron's level")
y, x = py(); made = set()
for t in range(8):
    cmd(10, bytes([2, PAGE_SPELL])); call(A["MS_STAIRS"]); made.add(sq(y, x) & 15)
print("  stair creation:", made)
expect(made == {9}, "stair creation makes only up stairs there")
wr(0xC000 + y*W + x, bytes([(sq(y, x) & 0xF0) | 1]))
# a trap door: a spiked pit
TL = A["TRAP_LIST"]
dy, dx = open_line(1) or (0, 1)
wr(TL, bytes(128)); wr(TL, bytes([y + dy, x + dx, 4, 1]))
m = keyed(0, dx=dx, dy=dy)
print("  trap door on 99:", repr(m), rd(A["DUN_LEVEL"], 1)[0])
expect("You fall into a spiked pit!" in m and rd(A["DUN_LEVEL"], 1)[0] == QL and rd(A["P_NEW_LEVEL"], 1)[0] == 0, "a trap door there is a spiked pit: 'You fall into a spiked pit!'")
wr(TL, bytes(128)); wr(A["PLAYER_Y"], bytes([y])); wr(A["PLAYER_X"], bytes([x])); full()

# ---- killing Sauron elsewhere, then on his level
def kill(race, at):
    calm(); place(1, race, *at, hp=1)
    set_reg(6, 0xB000 + 16)
    pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp); set_reg(5, 50)
    set_pc(A["MON_TAKE_HIT"]); run_to(BP)
    return keyed(C_STAY)
spot = (y + dy, x + dx)
wr(A["DUN_LEVEL"], bytes([QL - 1]))
m = kill(SAURON, spot)
print("  Sauron dies on 98:", repr(m), rd(A["P_QUEST"], 1)[0])
expect("Well done!!  Now continue onward towards Morgoth." in m and rd(A["P_QUEST"], 1)[0] == 0, "Sauron killed off his level: 'Well done!!  Now continue onward towards Morgoth.'")
wr(A["P_QUEST"], bytes([QL])); wr(A["DUN_LEVEL"], bytes([QL]))
m = kill(SAURON, spot)
print("  Sauron dies on 99:", repr(m), "square", sq(*spot) & 15, rd(A["P_QUEST"], 1)[0])
expect("Well done!! Go for it!" in m and "A magical stairway appears..." in m and sq(*spot) & 15 == 8 and rd(A["P_QUEST"], 1)[0] == 0,
       "on his level: 'Well done!! Go for it!' 'A magical stairway appears...' and stairs down where he fell")

# ---- Morgoth: the game is won
wr(A["DUN_LEVEL"], bytes([100]))
m = kill(MORGOTH, (y - dy, x - dx) if sq(y - dy, x - dx) & 15 in (1, 2, 14) else spot)
print("  Morgoth dies:", repr(m), "winner", rd(A["P_WINNER"], 1)[0], "status", repr(screen()[31].strip()))
expect("*** CONGRATULATIONS *** You have won the game." in screen()[0] + " " + m or rd(A["P_WINNER"], 1)[0] == 1, "Morgoth killed: '*** CONGRATULATIONS *** You have won the game.'")
expect(rd(A["P_WINNER"], 1)[0] == 1 and "Winner" in screen()[31], "and the status line says 'Winner'")
m = keyed(C_SAVE)
print("  ^X:", repr(m))
expect("You are a Total Winner,  your character must be retired." in screen()[0] or "retire" in m, "a winner can't save: 'You are a Total Winner, your character must be retired.'")
m = keyed(C_QUIT, "n")
expect(rd(A["P_DEAD"], 1)[0] == 0, "'Q', then no: nothing")

# ---- retiring: the crown and the tombstone
lev0, g0 = rd(A["P_LEV"], 1)[0], gold()
install_keys("y   "); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
set_reg(3, 0); set_reg(4, C_QUIT << 8); set_pc(A["DISPATCH"])
run_to(A["END_SCREENS@HAIL"]); crown = [l.rstrip() for l in screen()]
print("  killer", hex(struct.unpack("<H", rd(A["KILLER_RACE"], 2))[0]), "level", lev0, "->", rd(A["P_LEV"], 1)[0], "gold", g0, "->", gold())
print("  crown:", [l.strip() for l in crown if l.strip()][:6], "...")
expect(any("Veni, Vidi, Vici!" in l for l in crown) and any("*#########*#########*" in l for l in crown), "'Q' to retire: the crown, 'Veni, Vidi, Vici!'")
expect(rd(A["P_LEV"], 1)[0] >= lev0 + 50 and gold() == g0 + 250000 and rd(A["DUN_LEVEL"], 1)[0] == 0, "and 50 levels, 250000 gold, back in the town")
run_to(A["PLAYER_DIED_SCREEN@NOT_KING"]); tomb = [l.strip() for l in screen() if l.strip()]
print("  tomb:", tomb)
expect(any("Ripe Old Age" in l for l in tomb) and any("the Magnificent *King*" in l or "the Magnificent *Queen*" in l for l in tomb), "the tombstone: 'Killed by Ripe Old Age', 'the Magnificent *King*'")
cmd(2)
print("ALL OK" if ok else "FAILURES")
