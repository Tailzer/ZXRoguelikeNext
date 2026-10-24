import sys, re
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
C_STAY, C_INVEN, C_DISARM, C_OPEN, C_BASH = 3, 4, 24, 29, 31
PAGE_MISC, PAGE_TRAP, PAGE_LEVEL, PAGE_CREATE = 41, 58, 40, 43
TL = A["TRAP_LIST"]
SN = {n: A["SN_" + n] for n in ("EMPTY", "LOCKED", "POISON_NEEDLE", "GAS_TRAP", "EXPLOSION_DEVICE",
                                 "SUMMONING_RUNES", "MULTIPLE_TRAPS", "DISARMED", "UNLOCKED", "MORGOTH", "GROND")}
CHESTS = [i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 24]
NAMED = {KINDS[i]: i for i in CHESTS}
print("  chests:", [(i, KINDS[i], KIND_RECS[i]["raw"][4], KIND_RECS[i]["raw"][21]) for i in CHESTS])
SMALL = next(i for i in CHESTS if "Small wooden" in KINDS[i])
LSTEEL = next(i for i in CHESTS if "Large steel" in KINDS[i])
RUINED = A["KIND_RUINED_CHEST"]
expect(len(CHESTS) == 7 and RUINED in CHESTS, "six chests and the ruined chest, class IC_CHEST")
expect([KIND_RECS[i]["raw"][21] for i in CHESTS if i != RUINED] == [0x0F, 0x15, 0x0F, 0x1F, 0x0F, 0x23],
       "their treasure as TREASURE.C has it (CM_ bits in K_FLAGS+3)")
FL = 0xB400
def kind(name): return next(i for i, k in enumerate(KINDS) if k == name)
def clear_floor():
    for i in range(64): wr(FL + IS*i + 1, bytes([255]))
def put(slot, k, y, x, pval=0, name2=0, ident=0):
    wr(FL + IS*slot, bytes([k & 255, k >> 8, 1, y, x, 0, pval, 0, ident, 0, 0, 0, name2, 0]))
def rec(slot): return rd(FL + IS*slot, IS)
def items(): return [(r["y"], r["x"], kname(r)) for r in floor()]
def keyed(cmdno, keys=" ", dx=0, dy=0):
    install_keys(keys); call(A["MSG_CLEAR"]); wr(A["TURN_TAKEN"], bytes([0]))
    set_reg(3, ((dx & 255) << 8) | (dy & 255)); set_reg(4, cmdno << 8); set_pc(A["DISPATCH"]); run_to(BP)
    return msgline()
def turned(): return rd(A["TURN_TAKEN"], 1)[0]
def exp(): return struct.unpack("<I", rd(A["P_EXP"], 4))[0]
def log_text():
    """the message history (PAGE_LOG at $E000 for a moment)"""
    cmd(10, bytes([7, 70])); t = rd(0xE000, 32*80); cmd(10, bytes([7, 33]))
    return " ".join(bytes(t[i*80:(i+1)*80]).split(b"\0")[0].decode("latin-1") for i in range(32))
def reset_timers():
    for t in ("P_BLIND", "P_CONFUSED", "P_SLOW", "P_POISONED", "P_AFRAID"): w16(t, 0)
    wr(A["P_PARALYSED"], bytes([0]))

# ---- magic_treasure: what a chest is made as
def make(k, level):
    clear_floor(); put(0, 0, 10, 10)
    cmd(10, bytes([2, PAGE_MISC]))
    pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp)
    set_reg(6, FL); set_reg(5, k); set_reg(2, level << 8); set_pc(A["NEW_ITEM"]); run_to(BP)
    r = rec(0); return r[6], r[12]
VALID = {(0, SN["EMPTY"]), (0x81, SN["LOCKED"]), (0x83, SN["POISON_NEEDLE"]), (0x85, SN["POISON_NEEDLE"]),
         (0x89, SN["GAS_TRAP"]), (0x91, SN["EXPLOSION_DEVICE"]), (0xA1, SN["SUMMONING_RUNES"]),
         (0x8F, SN["MULTIPLE_TRAPS"]), (0xB1, SN["MULTIPLE_TRAPS"])}
shallow = [make(SMALL, 1) for _ in range(40)]
deep = [make(SMALL, 40) for _ in range(80)]
print("  level 1:", sorted(set(shallow)), " level 40:", sorted(set(deep)))
expect(all(s in VALID for s in shallow + deep), "magic_treasure: empty, locked, or locked with the C's traps and names")
expect({s[0] for s in shallow} <= {0, 0x81, 0x83, 0x85} and len(set(shallow)) >= 3, "shallow: 1d5 - empty, locked, needles")
expect(len(set(deep)) >= 5 and (0xB1, SN["MULTIPLE_TRAPS"]) in deep, "deep: every kind, mostly the worst")

# ---- the set-up: a chest next to the player
calm(); full(); no_resists(); call(A["LIGHT_REFRESH"])
wr(TL, bytes(128))
home = py(); dy, dx = open_line(3); d = {(1, -1): "1", (1, 0): "2", (1, 1): "3", (0, -1): "4", (0, 1): "6", (-1, -1): "7", (-1, 0): "8", (-1, 1): "9"}[(dy, dx)]
spot = (home[0] + dy, home[1] + dx)
def chest(k=SMALL, pval=0x80, name2=0, ident=0):
    wr(A["PLAYER_Y"], bytes([home[0]])); wr(A["PLAYER_X"], bytes([home[1]]))
    clear_floor(); calm(); reset_timers(); full(); put(0, k, *spot, pval, name2, ident)

# description
chest(SMALL, 0x81, SN["LOCKED"], 0)
call(A["MSG_CLEAR"]); call(A["MSG_BEGIN"]); set_reg(6, FL); call(A["OBJDES_MSG"])
plain = bytes(rd(A["MSG_BUF"], 60)).split(b"\0")[0].decode()
put(0, SMALL, *spot, 0x81, SN["LOCKED"], 4)
call(A["MSG_BEGIN"]); set_reg(6, FL); call(A["OBJDES_MSG"])
known = bytes(rd(A["MSG_BUF"], 60)).split(b"\0")[0].decode()
print("  names:", repr(plain), repr(known))
expect(plain == "a Small wooden chest" and known == "a Small wooden chest (Locked)", "'a Small wooden chest', and once known2 '... (Locked)'")

# ---- o: opening
chest(LSTEEL, 0x80)
m = keyed(C_OPEN, d)
r = rec(0); got = [i for i in items() if i[2] != KINDS[LSTEEL]]
print("  open:", repr(m), hex(r[6]), r[12], r[8], got)
expect(turned() and r[6] == 0 and r[12] == SN["EMPTY"] and r[8] & 4, "'o': it opens, (Empty), known, nothing left in it")
expect(2 <= len(got) <= 4 and all(abs(y - spot[0]) <= 2 and abs(x - spot[1]) <= 2 and (y, x) != spot for y, x, _ in got),
       "a large steel chest (2d2): 2-4 things fall within 2 of it")
n_items = len(items())
m = keyed(C_OPEN, d)
expect(len(items()) == n_items and turned(), "opened again: nothing more")
chest(SMALL, 0)
m = keyed(C_OPEN, d)
expect(len(items()) == 1, "an empty chest: nothing")
clear_floor()
m = keyed(C_OPEN, d)
expect("I do not see anything you can open there." in m and not turned(), "no chest: 'I do not see anything you can open there.'")

# locks
wr(A["P_DIS"], bytes([120])); e0 = exp()
chest(SMALL, 0x81, SN["LOCKED"])
m = keyed(C_OPEN, d); e1 = exp()
print("  pick:", repr(m), e1 - e0, hex(rec(0)[6]))
expect("You have picked the lock." in m and e1 - e0 == KIND_RECS[SMALL]["raw"][4] and rec(0)[6] == 0, "locked: 'You have picked the lock.', its level (7) in experience, and it opens")
wr(A["P_DIS"], bytes([256 - 100]))
chest(SMALL, 0x81, SN["LOCKED"])
m = keyed(C_OPEN, d)
expect("You failed to pick the lock." in m and rec(0)[6] == 0x81 and turned(), "a poor hand: 'You failed to pick the lock.'")
for t in range(40):						# (confused, the direction may stray)
    wr(A["P_DIS"], bytes([120])); chest(SMALL, 0x81, SN["LOCKED"]); w16("P_CONFUSED", 5)
    m = keyed(C_OPEN, d); w16("P_CONFUSED", 0)
    if "too confused" in m: break
expect("You are too confused to pick the lock." in m and rec(0)[6] == 0x81, "confused: 'You are too confused to pick the lock.'")

# ---- the traps, opening an unlocked trapped chest
def spring(pval):
    global h0
    chest(SMALL, pval); h0 = hp(); return keyed(C_OPEN, d)
st = rd(A["P_STAT_USE"], 1)[0]
m = spring(0x82)
print("  needle:", repr(m), st, rd(A["P_STAT_USE"], 1)[0], h0 - hp())
expect("A small needle has pricked you!" in m and "You feel weakened!" in m and rd(A["P_STAT_USE"], 1)[0] < st
       and struct.unpack("<H", rd(A["KILLER_RACE"], 2))[0] == A["KILLER_NEEDLE"], "a needle: 'You feel weakened!', STR down, hurt by 'a poison needle'")
sus = rd(A["P_SUSTAIN"], 1)[0]; wr(A["P_SUSTAIN"], bytes([sus | 1])); st = rd(A["P_STAT_USE"], 1)[0]
m = spring(0x82); wr(A["P_SUSTAIN"], bytes([sus]))
expect("You are unaffected." in m and rd(A["P_STAT_USE"], 1)[0] == st, "sustained: 'You are unaffected.'")
m = spring(0x84)
print("  poison needle:", repr(m), r16("P_POISONED"), h0 - hp())
expect("A small needle has pricked you!" in m and 10 <= r16("P_POISONED") <= 29 and 1 <= h0 - hp() <= 7, "a poison needle: 1d6, poisoned 10 + 1d20 (less the turn's)")
m = spring(0x88)
print("  gas:", repr(m), rd(A["P_PARALYSED"], 1)[0])
expect("A puff of yellow gas surrounds you!" in m and "You choke and pass out." in m and 10 <= rd(A["P_PARALYSED"], 1)[0] <= 30, "gas: 'You choke and pass out.', 10 + 1d20")
fa = rd(A["P_EFLAGS"] + 2, 1)[0]; wr(A["P_EFLAGS"] + 2, bytes([fa | 0x80]))
m = spring(0x88); wr(A["P_EFLAGS"] + 2, bytes([fa]))
expect("You are unaffected." in m and rd(A["P_PARALYSED"], 1)[0] == 0, "free action: 'You are unaffected.'")
n0 = nmons(); m = spring(0xA0)
print("  runes:", repr(m), n0, "->", nmons())
expect(nmons() - n0 >= 3, "summoning runes: three monsters (or their groups)")
calm(); m = spring(0x90)
print("  explosion:", repr(m), h0 - hp(), items())
expect("There is a sudden explosion!" in m and struct.unpack("<H", rd(A["KILLER_RACE"], 2))[0] == A["KILLER_CHEST"] and not items(), "'There is a sudden explosion!': 5d8 ('an exploding chest'), the chest gone, and what was in it")

# ---- D: disarming
def disarm(dis, pval, name2, ident=4):
    chest(SMALL, pval, name2, ident); wr(A["P_DIS"], bytes([dis & 255]))
    return keyed(C_DISARM, d)
m = disarm(120, 0x83, SN["POISON_NEEDLE"], 0)
expect("I don't see a trap." in m and not turned(), "a trap not yet known: 'I don't see a trap.' (no turn)")
m = disarm(120, 0x81, SN["LOCKED"])
expect("The chest was not trapped." in m and not turned(), "'The chest was not trapped.' (no turn)")
e0 = exp(); m = disarm(120, 0x83, SN["POISON_NEEDLE"]); e1 = exp()
print("  disarm:", repr(m), hex(rec(0)[6]), rec(0)[12], e1 - e0)
expect("You have disarmed the chest." in m and rec(0)[6] == 0x81 and rec(0)[12] == SN["LOCKED"] and e1 - e0 == 7,
       "'You have disarmed the chest.', still locked: (Locked), +7")
m = disarm(120, 0x88, SN["GAS_TRAP"])
expect(rec(0)[12] == SN["DISARMED"] and rec(0)[6] == 0x80, "not locked: (Disarmed)")
cmd(10, bytes([7, 70])); wr(0xE000, bytes(32*80)); cmd(10, bytes([7, 33]))
m = disarm(-120, 0x88, SN["GAS_TRAP"]); lg = log_text()
print("  clumsy:", repr(m), rd(A["P_PARALYSED"], 1)[0])
expect("You set a trap off!" in lg and "A puff of yellow gas surrounds you!" in lg and rd(A["P_PARALYSED"], 1)[0] and rec(0)[8] & 4, "hopeless: 'You set a trap off!', and it goes off")
fails = sum("You failed to disarm the chest." in disarm(30, 0x88, SN["GAS_TRAP"]) for _ in range(8))
expect(fails >= 1, f"middling: 'You failed to disarm the chest.' ({fails} of 8)")
reset_timers()

# ---- f: bashing
said = set()
for t in range(60):
    chest(SMALL, 0x81, SN["LOCKED"])
    m = keyed(C_BASH, d); said.add(m)
    r = rec(0)
    if "You have destroyed the chest." in m:
        expect(r[0] | r[1] << 8 == RUINED and r[6] == 0, "'You have destroyed the chest.' 'and its contents!': a ruined chest")
    if "The lock breaks open!" in m:
        expect(r[6] == 0x80, "'The lock breaks open!'")
print("  bash:", said)
expect(any("holds firm" in s for s in said) and any("destroyed" in s for s in said) and any("lock breaks" in s for s in said),
       "'f': 'The chest holds firm.', or 1 in 10 ruined, or 1 in 10 the lock breaks")

# ---- s: searching
chest(SMALL, 0x83, SN["POISON_NEEDLE"]); wr(A["P_SRH"], bytes([100]))
m = keyed(C_STAY)
expect("You have discovered a trap on the chest!" in m and rec(0)[8] & 4, "'s': 'You have discovered a trap on the chest!'")
m = keyed(C_STAY)
expect("The chest is trapped!" in m, "again: 'The chest is trapped!'")

# ---- magic
chest(SMALL, 0x83, SN["POISON_NEEDLE"])
cmd(10, bytes([2, PAGE_TRAP])); call(A["DETECT_TRAPS"])
expect(rec(0)[8] & 4, "trap detection: the chest's trap is known")
chest(SMALL, 0x83, SN["POISON_NEEDLE"])
call(A["MSG_CLEAR"]); cmd(10, bytes([2, PAGE_TRAP])); call(A["TRAPS_AROUND_GONE"])
print("  td_destroy:", repr(msgline()), hex(rec(0)[6]), rec(0)[12])
expect("You have disarmed the chest." in msgline() and rec(0)[6] == 0x80 and rec(0)[12] == SN["DISARMED"], "trap/door destruction: 'You have disarmed the chest.', unlocked, (Disarmed)")
chest(SMALL, 0x83, SN["POISON_NEEDLE"]); call(A["MSG_CLEAR"]); call(A["TRAP_CLICK"], de=spot[0] << 8 | spot[1])
expect("Click!" in msgline() and rec(0)[6] == 0x80 and rec(0)[12] == SN["UNLOCKED"], "disarming: 'Click!', (Unlocked)")
chest(SMALL, 0); call(A["MSG_CLEAR"]); call(A["TRAP_CLICK"], de=spot[0] << 8 | spot[1])
expect("Click!" not in msgline(), "an opened chest: no click")
chest(SMALL, 0x83); call(A["TRAP_FLASH"], de=spot[0] << 8 | spot[1])
expect(not items(), "trap/door destruction's beam: the chest is gone")

# ---- what monsters drop
cmd(10, bytes([1, 67])); ms = rd(0x2000, len(NAMES) * 12)
treas = [ms[i*12 + 11] for i in range(len(NAMES))]; good = [ms[i*12 + 10] for i in range(len(NAMES))]
def kill(race, at):
    calm(); clear_floor(); place(1, race, *at, hp=1)
    set_reg(6, 0xB000 + 16)
    pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp); set_reg(5, 50)
    set_pc(A["MON_TAKE_HIT"]); run_to(BP)
    return floor()
lvl = rd(A["P_LEV"], 1)[0]
none = next(i for i in range(len(NAMES)) if treas[i] == 0 and not good[i] & 12 and i > 5)
carrier = next(i for i in range(len(NAMES)) if treas[i] & 0x10 and treas[i] & 3 == 1 and not good[i] & 12)
rich = next(i for i in range(len(NAMES)) if treas[i] & 0x40 and good[i] & 8 and not RACES[i]["raw"][14] & 1)
print("  races:", NAMES[none], NAMES[carrier], hex(treas[carrier]), NAMES[rich], hex(treas[rich]), good[rich])
at = spot
expect(not kill(none, at), f"{NAMES[none]} carries nothing")
counts = [len(kill(carrier, at)) for _ in range(6)]
print("  ", NAMES[carrier], counts)
expect(all(1 <= c <= 4 for c in counts) and max(counts) >= 1, "an object carrier (1D2, ...) drops what it carries")
drops = kill(rich, at)
cls = [KCLASS[r["kind"]] if r["kind"] != 0xFE else 0 for r in drops]
print("  ", NAMES[rich], len(drops), [kname(r) for r in drops])
arms = sum(1 for c in cls if 7 <= c <= 13 or c in (21, 22))
expect(len(drops) >= 4 and arms >= len(drops) - 3, "a SPECIAL 4d2 race: good weapons and armour (1 in 10 a special object)")
wr(A["P_LEV"], bytes([lvl]))
MORGOTH = next(i for i, n in enumerate(NAMES) if n.startswith("Morgoth"))
wr(A["DUN_LEVEL"], bytes([100]))
drops = kill(MORGOTH, at)
raw = [rec(i) for i in range(64) if rec(i)[1] != 255]
print("  Morgoth:", len(drops), [(kname(r)) for r in drops])
expect(any(r[0] | r[1] << 8 == A["KIND_IRON_CROWN"] and r[12] == SN["MORGOTH"] for r in raw)
       and any(r[0] | r[1] << 8 == A["KIND_LEAD_MACE"] and r[12] == SN["GROND"] for r in raw),
       "Morgoth leaves the Massive Iron Crown of Morgoth and Grond")
wr(A["DUN_LEVEL"], bytes([1])); wr(A["END_EVENT"], bytes([0])); wr(A["P_WINNER"], bytes([0]))
calm(); clear_floor()

# ---- the tombstone
wr(A["KILLER_RACE"], struct.pack("<H", A["KILLER_CHEST"]))
cmd(10, bytes([2, PAGE_CREATE]))
pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp)
set_pc(A["PLAYER_DIED_SCREEN"]); run_to(A["PLAYER_DIED_SCREEN@NOT_KING"])
tomb = [l.strip() for l in screen() if l.strip()]
print("  tomb:", tomb)
expect(any("Killed by an exploding chest" in l for l in tomb), "the tombstone: 'Killed by an exploding chest'")
cmd(2)
print("ALL OK" if ok else "FAILURES")
