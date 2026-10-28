import sys, re
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
FLAV = _os.path.join(_GAME, "data", "flavours.asm")
ft = open(FLAV).read()
COLOURS = [re.search(rf'^pcol_{i}:\s*db "([^"]*)"', ft, re.M).group(1) for i in range(57)]
KIDX = {k: i for i, k in enumerate(KINDS)}
def kind(name): return KIDX["Potion of " + name]
FLV = lambda k: KIND_RECS[k]["raw"][22]
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
wr(A["READ_ASCII"], bytes([0x3A]) + struct.pack("<H", A["ASCII_KEY"]) + bytes([0xC9]))
OI = A["OBJECT_IDENT"] + 5*64
def ident(k): return rd(OI + FLV(k), 1)[0]
def put(slot, k, n=1, store=0, pval=0, hit=0, dam=0, ac=0): wr(A["PACK"] + 14*slot, bytes([k & 255, k >> 8, n, 0, 0, 1, pval, 0, store, hit & 255, dam & 255, ac & 255, 0, 0]))
def clear_pack():
    for i in range(12): wr(A["PACK"] + 14*i, bytes([0, 255] + [0]*12))
def quaff(k, store=0):
    clear_pack(); put(0, k, 1, store); command("q", "a"); return msgline()
def tick(n=1):
    for _ in range(n): act(3)
def stat(i): return rd(A["P_STAT"] + i, 1)[0]
def smax(i): return rd(A["P_STAT_MAX"] + i, 1)[0]
def setstat(i, v, mx=None):
    wr(A["P_STAT"] + i, bytes([v])); wr(A["P_STAT_MAX"] + i, bytes([mx if mx is not None else v])); wr(A["P_UPDATE"], bytes([3]))
def exp(): return struct.unpack("<I", rd(A["P_EXP"], 4))[0]
def setexp(v, mx=None):
    wr(A["P_EXP"], struct.pack("<I", v)); wr(A["P_MAX_EXP"], struct.pack("<I", mx if mx is not None else v))
def heal(): w16("P_MHP", 500); w16("P_CHP", 500)
def status(): return screen()[31]
def calm():								# no monsters to interfere
    for i in range(64):
        b = 0xB000 + 16*i
        if rd(b + 12, 1)[0] != 255:
            y, x = rd(b + 1, 2); wr(0xC000 + y*198 + x, bytes([rd(0xC000 + y*198 + x, 1)[0] & 0x7F])); wr(b + 12, bytes([255]))
wr(A["P_RACE"], bytes([0]))				# a human: no sustains or resists
heal()

# ---- flavours
fm = list(rd(A["FLAVOUR_MAP"], 57))
expect(sorted(fm) == list(range(57)) and fm[:3] == [0, 1, 2] and fm != list(range(57)), "potion colours shuffled, the first three fixed")
clw = kind("Cure Light Wounds")
clear_pack(); put(0, clw)
shot = command("i", capture=True)
col = COLOURS[fm[FLV(clw)]]
art = "an" if col[0] in "AEIOU" else "a"
line = next((l.strip() for l in shot if l.strip().startswith("a)")), "")
print("  unknown CLW lists as", repr(line))
expect(line == f"a) {art} {col} Potion", "an unknown potion goes by its colour")
tm = rd(0x6000, 2)
# ---- identify by use: Healing at level 1 gives 12 exp
calm()
w16("P_CHP", 5); e0 = exp()
hl = kind("Healing")
m = quaff(hl); print("  quaffed unknown Healing ->", repr(m), "chp", r16("P_CHP"), "exp", e0, "->", exp())
expect(r16("P_CHP") > 5 and ident(hl) & 2 and exp() - e0 == 12, "Healing heals, becomes known and gives (12 + 0) / 1 = 12 exp")
clear_pack(); put(0, hl)
shot = command("i", capture=True)
expect(any("a) a Potion of Healing" in l for l in shot), "and is called a Potion of Healing from now on")
# ---- tried: Restore Strength with nothing to restore
rs = kind("Restore Strength")
setstat(0, 15)
quaff(rs)
clear_pack(); put(0, rs, 2)
shot = command("i", capture=True)
line = next((l.strip() for l in shot if l.strip().startswith("a)")), "")
print("  after a useless quaff:", repr(line))
expect(ident(rs) == 1 and line.endswith("Potions {tried}"), "no effect: unknown but {tried}")
# ---- stat loss and restore
m = quaff(kind("Weakness"))
print("  Weakness ->", repr(m), stat(0), "/", smax(0))
expect(stat(0) == 14 and smax(0) == 15 and "You feel very sick." in m, "Weakness: STR 15 -> 14, max stays 15")
m = quaff(rs)
expect(stat(0) == 15 and ident(rs) & 2, "Restore Strength puts it back (and is now known)")
setstat(0, 18 + 50)
quaff(kind("Weakness"))
loss = (((118 - 68) >> 1) + 1) >> 1
expect(68 - 2*loss <= stat(0) <= 68 - loss - 1, f"18/50 drops by randint({loss}) + {loss}: now 18/{stat(0)-18}")
# ---- stat gain
for start in (10, 18 + 20, 18 + 99):
    setstat(0, start)
    quaff(kind("Strength"))
    if start < 18: ok_ = start + 1 <= stat(0) <= start + 2
    elif start < 116:
        g = ((118 - start)//2 + 3) >> 1; ok_ = start + 1 + g//2 <= stat(0) <= min(117, start + g + g//2)
    else: ok_ = stat(0) == start + 1
    expect(ok_ and smax(0) == stat(0), f"Strength from {start} -> {stat(0)} (MISC2.C inc_stat), max follows")
setstat(0, 17)
tick(); tick()
heal()
# ---- speed
ms0 = {(k["y"], k["x"]): k["speed"] for k in mons()}
quaff(kind("Speed")); tick()
print("  speed:", r8("P_SPEED"), "fast", r16("P_FAST"), "status:", status().strip())
expect(r8("P_SPEED") == -1 and "Fast" in status(), "Speed: player speed -1, 'Fast' on the status line")
w16("P_FAST", 1); tick()
expect(r8("P_SPEED") == 0 and "Fast" not in status() and "slow down" in msgline(), "it wears off: 'You feel yourself slow down.'")
# ---- heroism and berserk
th0, mhp0 = r8("P_TOHIT"), r16("P_MHP")
quaff(kind("Heroism")); tick()
print("  hero:", r8("P_TOHIT") - th0, r16("P_MHP") - mhp0, repr(msgline()))
expect(r8("P_TOHIT") - th0 == 12 and r16("P_MHP") - mhp0 == 10, "Heroism: +12 to-hit, +10 hit points")
w16("P_HERO", 1); tick()
expect(r8("P_TOHIT") == th0 and r16("P_MHP") == mhp0 and "heroism wears off" in msgline(), "and back again")
ac0 = rd(A["P_AC"], 1)[0]
quaff(kind("Berserk Strength")); tick()
expect(r8("P_TOHIT") - th0 == 24 and r16("P_MHP") - mhp0 == 30 and ac0 - rd(A["P_AC"], 1)[0] == min(10, ac0), "Berserk: +24 to-hit, -10 AC, +30 hit points")
w16("P_SHERO", 1); tick()
expect(r8("P_TOHIT") == th0 and rd(A["P_AC"], 1)[0] == ac0, "and back again")
heal(); setstat(0, 17)
# ---- what a potion says when it starts something (say_if_zero once
# printed from address 0: garbage)
def logged():								# the message log (page 70, at $E000 here)
    cmd(10, bytes([7, 70])); t = bytes(rd(0xE000, 32*80)).decode("latin-1"); cmd(10, bytes([7, 33])); return t
def log_clear(): cmd(10, bytes([7, 70])); wr(0xE000, bytes(32*80)); cmd(10, bytes([7, 33]))
for name, said, ctr in (("Infra-vision", "Your eyes begin to tingle.", "P_TIM_INFRA"),
                        ("Confusion", "Hey!  This is good stuff!  * Hick! *", "P_CONFUSED"),
                        ("Poison", "You feel very sick.", "P_POISONED")):
    w16(ctr, 0); log_clear(); quaff(kind(name)); m = logged()
    expect(said in m and r16(ctr) > 0, f"{name}: '{said}'")
    w16(ctr, 1); tick(); heal()
# ---- what's said when protection runs out (count_down once printed from
# address 0: garbage)
for ctr, said in (("P_PROTEVIL", "evil"), ("P_RESIST_HEAT", "flame"), ("P_RESIST_COLD", "cold"),
                  ("P_RESIST_ACID", "acid"), ("P_RESIST_LIGHT", "lightning"), ("P_RESIST_POISON", "poison")):
    w16(ctr, 1); log_clear(); tick()
    expect(f"You no longer feel safe from {said}." in logged() and r16(ctr) == 0, f"'You no longer feel safe from {said}.'")
# ---- blindness, cured
log_clear(); quaff(kind("Blindness")); m = logged(); tick()
expect("You are covered by a veil of darkness." in m, "Blindness: 'You are covered by a veil of darkness.'")
sc = screen()
view = "".join(sc[1:31]).replace(" ", "")
print("  blind: status", status().strip(), "| view shows", repr(view))
expect("Blind" in status() and view == "@" and not any(k["ml"] for k in mons()), "Blindness: only the @ is drawn, no monsters seen")
quaff(clw); tick()
expect(r16("P_BLIND") == 0 and "Blind" not in status() and "veil of darkness lifts" in msgline(), "Cure Light Wounds cures it: 'The veil of darkness lifts.'")
# ---- poison
heal()
quaff(kind("Poison")); c0 = r16("P_CHP"); tick(3)
expect(r16("P_POISONED") > 0 and r16("P_CHP") < c0 and "Poisoned" in status(), "Poison hurts each turn")
quaff(kind("Neutralize Poison")); tick()
expect(r16("P_POISONED") == 0 and "You feel better." in msgline(), "Neutralize Poison ends it")
# ---- salt water, sleep
w16("P_FOOD", 5000)
m = quaff(kind("Salt Water"))
print("  salt water:", r16("P_FOOD"), rd(A["P_PARALYSED"], 1)[0], repr(m))
expect(r16("P_FOOD") == 150 - 2 and 4 <= rd(A["P_PARALYSED"], 1)[0] <= 9, "Salt Water: food 150, paralysed 4 turns")
wr(A["P_PARALYSED"], bytes([0])); w16("P_FOOD", 5000)
quaff(kind("Sleep"))
expect(5 <= rd(A["P_PARALYSED"], 1)[0] <= 8, "Sleep: asleep for 1d4+4")
wr(A["P_PARALYSED"], bytes([0]))
# ---- experience
setexp(1000)
quaff(kind("Experience"), store=1)
expect(exp() == 1000 + 510 and struct.unpack("<I", rd(A["P_MAX_EXP"], 4))[0] == 1510, "Experience: +exp/2+10, max follows")
lev0 = rd(A["P_LEV"], 1)[0]
quaff(kind("Lose Memories"), store=1)
e1 = exp(); print("  lose memories:", 1510, "->", e1, "level", lev0, "->", rd(A["P_LEV"], 1)[0])
expect(1510 - 1510//5 - 1510//5 <= e1 <= 1510 - 1510//5, "Lose Memories: loses exp/5 + randint(exp)/5")
expect(rd(A["P_LEV"], 1)[0] <= lev0, "level falls to match")
m = quaff(kind("Restore Life Levels"), store=1)
expect(exp() == 1510 and rd(A["P_LEV"], 1)[0] == lev0, "Restore Life Levels: back to max exp")
# ---- enlightenment
quaff(kind("Enlightenment"))
mm = rd(0xC000, W*H)
openq = [i for i, b in enumerate(mm) if T(b) in (1, 2, 5, 6, 7, 8, 9, 14)]
expect(all(mm[i] & 0x20 for i in openq), f"Enlightenment: all {len(openq)} open squares are mapped")
# ---- self knowledge (stop at the key wait to see the screen)
w16("P_HERO", 30); tick()
clear_pack(); put(0, kind("Self Knowledge"))
wr(A["ASCII_KEY"], b"a"); set_reg(3, 0); set_reg(4, 8 << 8); set_pc(A["DISPATCH"])
seen = None
for _ in range(6):
    cmd(6, bytes([1]) + struct.pack("<H", A["WAIT_FRESH_KEY"]) + bytes([1]) + struct.pack("<H", BP))
    while True:
        rseq, d = recv_msg()
        if rseq == 0: break
    sc = screen()
    if any("Your Attributes:" in l for l in sc): seen = sc; break
    if struct.unpack("<H", cmd(3)[:2])[0] == BP: break
if seen: [print("   |" + l.rstrip()) for l in seen[1:6]]
expect(seen and any("You feel heroic." in l for l in seen), "Self Knowledge lists 'You feel heroic.'")
run_to(BP)
w16("P_HERO", 1); tick()
# ---- detonations: cut and stun
heal(); w16("P_MHP", 2000); w16("P_CHP", 2000)
quaff(kind("Detonations"))
print("  detonations: chp", r16("P_CHP"), "cut", r16("P_CUT"), "stun", r16("P_STUN"), "status:", status().strip())
expect(r16("P_CUT") >= 5000 and r16("P_STUN") == 74, "Detonations: mortal wound, heavy stun")
tick()
expect("Mortal wound" in status() and "Heavy stun" in status(), "status shows Mortal wound and Heavy stun")
th_stun = r8("P_TOHIT")
quaff(kind("*Healing*"))
tick()
expect(r16("P_CUT") == 0 and r16("P_STUN") == 0 and r8("P_TOHIT") == th_stun + 20, "*Healing* closes the wound and clears the stun (+20 to-hit back)")
# ---- death
heal()
quaff(kind("Death"))
expect(rd(A["P_DEAD"], 1)[0] == 1 and r16("KILLER_RACE") == 0xFE02 - 0x10000, "Death kills: 'a potion of Death'")
cmd(2)
print("ALL OK" if ok else "FAILURES")
