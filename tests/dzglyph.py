import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
PAGE_SCROLL, PAGE_SPELL = 53, 55
C_DISARM = 24
TL = A["TRAP_LIST"]
KEY = {(1, -1): "1", (1, 0): "2", (1, 1): "3", (0, -1): "4", (0, 1): "6", (-1, -1): "7", (-1, 0): "8", (-1, 1): "9"}
def traps(): return [tuple(rd(TL + 4*i, 4)) for i in range(32) if rd(TL + 4*i + 2, 1)[0]]
def sq(y, x): return rd(0xC000 + y*W + x, 1)[0]
def keyed(cmdno, keys=" ", dx=0, dy=0):
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
def page_call(page, sym):
    cmd(10, bytes([2, page])); call(A[sym])
for n in ("Rune of Protection", "Acquirement", "*Acquirement*"):
    expect(any(k == "Scroll~ of " + n or k.endswith(n) for k in KINDS), f"the Scroll of {n} is an item now")
calm(); full(); no_resists(); call(A["LIGHT_REFRESH"])
walk_to_room(); call(A["UPDATE_VIEW"])
home = py(); dy, dx = open_line(3); d = KEY[(dy, dx)]
spot = (home[0] + dy, home[1] + dx)
def fresh():
    wr(TL, bytes(128)); clear(0xB400, 64); calm(); full()
    for t in ("P_BLIND", "P_CONFUSED", "P_AFRAID", "P_POISONED", "P_STUN", "P_CUT"): w16(t, 0)
    wr(A["P_PARALYSED"], bytes([0]))
    for y_, x_ in (home, spot):						# (Morgoth's blows shake the cave)
        q = 0xC000 + y_*W + x_; wr(q, bytes([(rd(q, 1)[0] & 0xF0) | 1]))
    wr(A["PLAYER_Y"], bytes([home[0]])); wr(A["PLAYER_X"], bytes([home[1]]))

# ---- the rune
fresh(); call(A["MSG_CLEAR"]); page_call(PAGE_SCROLL, "SC_RUNE")
t = traps()
print("  rune:", t)
expect(t == [(home[0], home[1], 19, 3)], "Rune of Protection: a glyph of warding (seen, made) where you stand")
page_call(PAGE_SCROLL, "SC_RUNE")
expect(len(traps()) == 1, "not a second on the same square")
# a weak monster can't get at you
JACKAL = next(i for i, n in enumerate(NAMES) if n == "Jackal")
place(0, JACKAL, *spot); wr(0xB000 + 9, bytes([1]))
h = hp()
for t_ in range(30):
    set_reg(6, 0xB000); call(A["MON_TURN"])
print("  jackal: hp", h, "->", hp(), traps())
expect(hp() == h and len(traps()) == 1, "a jackal (level 1) never breaks it: no bites")
# Morgoth breaks it in the end
MORGOTH = next(i for i, n in enumerate(NAMES) if n.startswith("Morgoth"))
calm(); place(0, MORGOTH, *spot, hp=30000); wr(0xB000 + 9, bytes([1]))
wr(A["P_INVULN"], struct.pack("<H", 1000))
cmd(10, bytes([7, 70])); wr(0xE000, bytes(32*80)); cmd(10, bytes([7, 33]))
for t_ in range(80):
    call(A["MSG_CLEAR"]); set_reg(6, 0xB000); call(A["MON_TURN"])
    if not traps(): break
cmd(10, bytes([7, 70])); said = bytes(rd(0xE000, 32*80)).decode("latin-1").split("\0"); cmd(10, bytes([7, 33]))
wr(A["P_INVULN"], bytes(2)); calm(); full()
print("  Morgoth:", [m for m in said if "rune" in m], traps())
expect(not traps() and any("The rune of protection is broken!" in m for m in said), "Morgoth (level 100: 1d550 < 100) breaks it: 'The rune of protection is broken!'")
# disarming one
fresh()
wr(A["PLAYER_Y"], bytes([spot[0]])); wr(A["PLAYER_X"], bytes([spot[1]]))
page_call(PAGE_SCROLL, "SC_RUNE")
wr(A["PLAYER_Y"], bytes([home[0]])); wr(A["PLAYER_X"], bytes([home[1]]))
wr(A["P_DIS"], bytes([120])); e0 = struct.unpack("<I", rd(A["P_EXP"], 4))[0]
m = keyed(C_DISARM, d)
e1 = struct.unpack("<I", rd(A["P_EXP"], 4))[0]
print("  disarm:", repr(m), traps(), e1 - e0)
expect("You have disarmed the trap." in m and not traps() and e1 == e0, "'D': 'You have disarmed the trap.' (no experience)")
# not on stairs
fresh(); a = 0xC000 + home[0]*W + home[1]; old = rd(a, 1)[0]
wr(a, bytes([(old & 0xF0) | 8])); page_call(PAGE_SCROLL, "SC_RUNE"); wr(a, bytes([old]))
expect(not traps(), "not on the stairs")
# the prayer
fresh(); page_call(PAGE_SPELL, "PR_GLYPH")
expect([t_[2] for t_ in traps()] == [19], "the prayer Glyph of Warding makes one too")

# ---- acquirement
fresh(); wr(A["DUN_LEVEL"], bytes([20]))
call(A["MSG_CLEAR"]); page_call(PAGE_SCROLL, "SC_ACQUIRE")
items = floor()
print("  acquirement:", [(kname(r), r["y"], r["x"]) for r in items], repr(msgline()))
expect(len(items) == 1 and (items[0]["y"], items[0]["x"]) == home and KCLASS[items[0]["kind"]] in range(7, 23)
       and "You feel something roll beneath your feet." in msgline(), "Acquirement: something great where you stand, 'You feel something roll beneath your feet.'")
got = []
for t_ in range(12):
    fresh(); page_call(PAGE_SCROLL, "SC_STAR_ACQUIRE")
    got += [(kname(r), max(abs(r["y"] - home[0]), abs(r["x"] - home[1]))) for r in floor()]
print("  *acquirement*:", len(got), got)
expect(len(got) >= 10 and all(abs(r[1]) <= 3 for r in got), "*Acquirement*: something great close by")
wr(A["DUN_LEVEL"], bytes([1]))
cmd(2)
print("ALL OK" if ok else "FAILURES")
