import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
C_STAY, C_LOOK, C_SYMBOL = 3, 33, 37
PAGE_RECALL, MEM_PAGE = 73, 74
KEY = {(1, -1): "1", (1, 0): "2", (1, 1): "3", (0, -1): "4", (0, 1): "6", (-1, -1): "7", (-1, 0): "8", (-1, 1): "9"}
def mem(race):
    cmd(10, bytes([1, MEM_PAGE + (race >> 8)])); r = rd(0x2000 + (race & 255)*32, 32)
    return dict(cmove=struct.unpack("<I", r[0:4])[0], spells=r[4:16], kills=struct.unpack("<H", r[16:18])[0],
                deaths=struct.unpack("<H", r[18:20])[0], cdef=struct.unpack("<I", r[20:24])[0], wake=r[24], ignore=r[25],
                attacks=list(r[26:30]), raw=r)
def set_mem(race, raw):
    cmd(10, bytes([1, MEM_PAGE + (race >> 8)])); wr(0x2000 + (race & 255)*32, bytes(raw) + bytes(32 - len(raw)))
def forget(race): set_mem(race, bytes(32))
def shots(cmdno, keys, n, dx=0, dy=0):
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"])
    out = []
    for i in range(n):
        run_to(A["READ_ASCII"]); out.append(screen())
    run_to(BP)
    return out
def recall(race, keys=" "):
    """roff_recall on its own -> the text as one string (lines joined)"""
    install_keys(keys)
    cmd(10, bytes([2, PAGE_RECALL]))
    pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp); set_reg(5, race)
    set_pc(A["ROFF_RECALL"]); run_to(A["READ_ASCII"])
    lines = [l.rstrip() for l in screen()]
    run_to(BP)
    used = [l for l in lines if l.strip()]
    return " ".join(used), lines
def known(race):
    cmd(10, bytes([2, PAGE_RECALL]))
    pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp); set_reg(5, race)
    set_pc(A["RECALL_KNOWN"]); run_to(BP); return not (regs()[2] & 0x40)
def kill(race, at, ml=1):
    calm(); place(1, race, *at, hp=1)
    b = 0xB000 + 16; wr(b + 11, bytes([ml]))
    set_reg(6, b)
    pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp); set_reg(5, 50)
    set_pc(A["MON_TAKE_HIT"]); run_to(BP)
cmd(10, bytes([2, 57])); call(A["MEM_FORGET"])			# (the tests start past load_game)
calm(); full(); no_resists(); call(A["LIGHT_REFRESH"])
home = py(); dy, dx = open_line(3); d = KEY[(dy, dx)]
spot = (home[0] + dy, home[1] + dx)
JACKAL = next(i for i, n in enumerate(NAMES) if n == "Jackal")
print("  races:", len(NAMES), "Jackal", JACKAL)
expect(all(mem(r)["raw"] == bytes(32) for r in (0, JACKAL, 300, len(NAMES) - 1)), "forgotten (mem_load with no roguelike.mem): nothing is known")
expect(not known(JACKAL), "recall_known: nothing of the Jackal")

# ---- the words, with nothing known
t, lines = recall(JACKAL)
print("  ", lines[:4])
expect(lines[0] == "The Jackal:", "'The Jackal:'")
expect("No battles to the death are recalled." in t and "It is a yapping snarling dog" in t, "'No battles to the death are recalled.', then its description (MON_DESC.DAT)")
expect("Nothing is known about its attack." in t and lines[[i for i, l in enumerate(lines) if l.strip()][-1]] == "--pause--", "'Nothing is known about its attack.' and '--pause--'")

# ---- a kill: kills, its kind and worth, what it was seen to drop
GOBLIN = next(i for i, n in enumerate(NAMES) if (n.startswith("Cave orc") or n.startswith("Snaga")))
wr(A["P_LEV"], bytes([3]))
kill(GOBLIN, spot)
m = mem(GOBLIN)
print("  ", NAMES[GOBLIN], "killed:", m["kills"], hex(m["cmove"]))
expect(m["kills"] == 1, "killed, seen: 1 kill remembered")
t, lines = recall(GOBLIN)
print("  ", [l for l in lines if l.strip()][:6])
expect("At least 1 of these creatures has been killed by your ancestors." in t, "'At least 1 of these creatures has been killed by your ancestors.'")
expect(re.search(r"A kill of this evil orc is worth \d+\.\d\d points for a 3rd level character\.", t) is not None, "'A kill of this evil orc is worth N.NN points for a 3rd level character.'")
expect("It is normally found at depths of" in t, "'It is normally found at depths of N feet'")
kill(GOBLIN, spot, ml=0)
expect(mem(GOBLIN)["kills"] == 1, "unseen, the kill isn't counted")

# what it carries (written in: the C's count and carry bits)
set_mem(GOBLIN, struct.pack("<I", 0x01000000 | (1 << 26)) + bytes(12) + struct.pack("<H", 1))
t, _ = recall(GOBLIN)
print("  carry:", re.search(r"It may[^.]*\.", t).group(0) if "It may" in t else None)
expect("It may carry an object." in t or "It may often carry an object." in t or "It may sometimes carry an object." in t, "'It may ... carry an object.'")
set_mem(GOBLIN, struct.pack("<I", 0x03000000 | (3 << 26)) + bytes(12) + struct.pack("<H", 1))
t, _ = recall(GOBLIN)
expect("It may carry up to 3 objects or treasures." in t, "'It may carry up to 3 objects or treasures.'")

# ---- deaths: the character killed by it
forget(GOBLIN)
wr(A["KILLER_RACE"], struct.pack("<H", GOBLIN))
cmd(10, bytes([2, PAGE_RECALL])); call(A["NOTE_DEATH"])
wr(A["KILLER_RACE"], struct.pack("<H", 0))
t, _ = recall(GOBLIN)
expect(mem(GOBLIN)["deaths"] == 1 and "1 of your ancestors has been killed by this creature, and it is not ever known to have been defeated." in t,
       "a death: '1 of your ancestors has been killed by this creature, and it is not ever known to have been defeated.'")

# ---- moves and alertness, learnt by watching
forget(JACKAL)
calm(); place(0, JACKAL, *spot); wr(0xB000 + 7, bytes([0, 0]))
for t_ in range(6):
    set_reg(6, 0xB000); call(A["MON_TURN"])
m = mem(JACKAL)
print("  jackal watched:", hex(m["cmove"]), m["attacks"], m["wake"], m["ignore"])
expect(m["cmove"] & 0x02 and m["attacks"][0] >= 1, "watching it: it moves normally (CM_MOVE_NORMAL), its bite noticed")
t, _ = recall(JACKAL)
print("  ", re.findall(r"It (?:moves|can)[^.]*\.", t))
expect("It moves" in t and "quickly" in t or "at normal speed" in t, "'It moves at normal speed' / quickly")
expect("It can bite" in t, "'It can bite.'")
# alertness from waking
set_mem(JACKAL, bytes(24) + bytes([20, 0]))
t, _ = recall(JACKAL)
print("  ", re.findall(r"It [a-z ]+ intruders[^.]*\.", t))
expect(re.search(r"intruders, which it may notice from \d+ feet\.", t) is not None, "woken often: '... intruders, which it may notice from N feet.'")

# ---- spells seen
R = next(i for i, r in enumerate(RACES) if not r["raw"][13] & 1 and 18 <= r["level"] <= 25 and not r["raw"][15] & 0x7F and not r["raw"][13] & 4)
forget(R)
set_spells(R, [8]); full(); wr(A["P_SAVE"], bytes([0x9C]))
y0, x0 = home
place(0, R, *spot)
for k in range(7): turn(); full()
m = mem(R)
print("  caster:", NAMES[R], m["spells"].hex())
expect(m["spells"][0] & 0x80 and (m["spells"][0] & 15) >= 6, "a spell seen cast: its bit (cause light wounds) and how often")
t, _ = recall(R)
print("  ", re.findall(r"It is magical[^.]*\.", t))
expect("It is magical, casting spells which cause light wounds; 1 time in 1." in t, "'It is magical, casting spells which cause light wounds; 1 time in 1.'")
calm()

# ---- what slays and magic show
EVIL = next(i for i, r in enumerate(RACES) if r["raw"][13] & 8 and not r["raw"][13] & 1 and r["level"] > 3)
forget(EVIL)
place(0, EVIL, *spot); wr(A["W_SLAYS"], struct.pack("<H", 1 << 10))
set_reg(6, 0xB000); call(A["LEARN"], de=5)
wr(A["W_SLAYS"], bytes(2))
expect(mem(EVIL)["cdef"] & 2, "a weapon of Slay Evil striking it: evil is known")
set_reg(6, 0xB000); set_reg(2, (1 << 6) << 8); call(A["LEARN"], de=0)
NOINF = RACES[EVIL]["raw"][13] & 0x40
expect(bool(mem(EVIL)["cdef"] & 0x200) == bool(NOINF), "only what it really is: NO_INFRA learnt only if it's cold-blooded")
# immunities and weaknesses, written in
FIRE = next(i for i, r in enumerate(RACES) if r["raw"][15] & 2 and r["raw"][15] & 1 and not r["raw"][13] & 1)
set_mem(FIRE, bytes(20) + struct.pack("<I", 0x1800 | 0x100 | 0x200))
t, _ = recall(FIRE)
print("  ", NAMES[FIRE], re.findall(r"It (?:resists|is cold|cannot)[^.]*\.", t))
expect("It resists frost and fire." in t, "'It resists frost and fire.'")

# ---- everything known (as the C's wizard sees it): it fits the screen
for name in ("Morgoth, Lord of Darkness", "Ancient multi-hued dragon", "Great Wyrm of Power"):
    rr = next((i for i, n in enumerate(NAMES) if n.startswith(name.split(",")[0])), None)
    if rr is None: continue
    set_mem(rr, struct.pack("<IIIIHHIBB", 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 1000, 3, 0xFFFFFFFF, 255, 255) + bytes([255]*4))
    t, lines = recall(rr)
    used = [i for i, l in enumerate(lines) if l.strip()]
    print("  ", NAMES[rr], "rows", used[-1] + 1, "|", lines[used[-1] - 1][:78])
    expect(used[-1] < 32 and lines[used[-1]] == "--pause--", f"{NAMES[rr]}, all known: fits the screen")
    if rr == next(i for i, n in enumerate(NAMES) if n.startswith("Morgoth")):
        expect("Killing one of these wins the game!" in t and "It can breathe" not in t and "It is magical" in t, "Morgoth: 'Killing one of these wins the game!'")
    forget(rr)

# ---- look: [(r)ecall]
calm(); place(0, JACKAL, *spot); wr(0xB000 + 11, bytes([1])); call(A["UPDATE_VIEW"])
sc = shots(C_LOOK, d + "r  ", 3)
seen = [l.strip() for l in sc[1] if l.strip()]
rec = [l.strip() for l in sc[2] if l.strip()]
print("  look:", seen[0][:70], "| recall:", rec[0])
expect("You see a Jackal (unhurt). [(r)ecall]" in seen[0], "look: 'You see a Jackal (unhurt). [(r)ecall]'")
expect(rec[0] == "The Jackal:" and rec[-1] == "--pause--", "'r': the Jackal recalled")

# ---- /: the races of a symbol
jc = chr(RACES[JACKAL]["raw"][0])
sc = shots(C_SYMBOL, jc + "y  ", 3)
print("  /:", sc[1][0].strip()[:79])
expect("You recall those details? [y/n]" in sc[1][0], "'/' C: 'You recall those details? [y/n]'")
expect(any(l.strip() == "The Jackal:" for l in sc[2]) or any("The " in l and l.strip().endswith(":") for l in sc[2]), "'y': the known 'C's recalled, the deepest first")
cmd(2)
print("ALL OK" if ok else "FAILURES")
