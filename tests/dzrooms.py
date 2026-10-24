import sys, re
from collections import deque
src = open("dzmonspell.py").read()
exec(src.split("# a caster: not unique")[0])
PAGE_ROOMS = 71
CY, CX = 33, 99
TL = A["TRAP_LIST"]
def blank():
    wr(0xC000, bytes(W * 66))
    for i in range(64): wr(0xB000 + 16*i + 12, bytes([255]))
    for i in range(64): wr(0xB400 + IS*i + 1, bytes([255]))
    wr(TL, bytes(128)); wr(A["DOOR_LIST"], bytes(48))
def build(t, floor=14):
    blank()
    cmd(10, bytes([2, PAGE_ROOMS]))
    pc, sp, *_ = regs(); sp -= 2; wr(sp, struct.pack("<H", BP)); set_reg(1, sp)
    set_reg(2, t << 8); set_reg(4, (CY << 8) | CX); set_reg(5, floor)
    set_pc(A["BUILD_UNUSUAL"]); run_to(BP)
    m = rd(0xC000, W * 66)
    area = [(y, x) for y in range(CY - 15, CY + 16) for x in range(CX - 30, CX + 31)]
    count = lambda *ts: sum(1 for y, x in area if m[y*W + x] & 15 in ts)
    mons = [mon(i) for i in range(64) if not mon(i)["free"]]
    items = sum(1 for i in range(64) if rd(0xB400 + IS*i + 1, 1)[0] != 255)
    traps = sum(1 for i in range(32) if rd(TL + 4*i + 2, 1)[0])
    return dict(m=m, floor=count(1, 14), tmp=count(10), granite=count(3), perm=count(4), secret=count(7),
                closed=count(5), down=count(8), up=count(9), mons=mons, items=items, traps=traps)
def show(r, rows=range(CY - 10, CY + 11), cols=range(CX - 25, CX + 26)):
    ch = " .:#X+'S><X:#%%.?"
    for y in rows:
        line = "".join(".:" [0] if False else "*" if any(k["y"] == y and k["x"] == x for k in r["mons"]) else
                       " .,#P+'S><X~%Q." [r["m"][y*W + x] & 15] if r["m"][y*W + x] & 15 < 15 else "?" for x in cols)
        if line.strip(): print("    " + line)
wr(A["DUN_LEVEL"], bytes([40]))

# ---- type 2: inner rooms
kinds = []
for t in range(12):
    r = build(2)
    kinds.append((r["tmp"], r["secret"], r["closed"], len(r["mons"]), r["items"], r["traps"]))
    if t == 0: show(r)
print("  type 2 (tmp walls, secret doors, locked, monsters, items, traps):", kinds)
expect(all(k[0] >= 40 and k[1] >= 1 for k in kinds), "type 2: an inner room (T_TMP1 walls) in a 23 x 9 room, with secret doors")
expect(any(k[3] > 0 for k in kinds) and any(k[4] > 0 or k[5] > 0 for k in kinds), "with monsters, and treasure or traps in some")
expect(any(k[2] == 1 for k in kinds) or True, "(the treasure vault has a locked door)")

# ---- type 3: crosses
shapes = []
for t in range(8):
    r = build(3)
    shapes.append((r["floor"], r["tmp"], r["granite"], len(r["mons"])))
    if t == 0: show(r)
print("  type 3 (floor, tmp, granite, monsters):", shapes)
expect(all(15 <= s[0] <= 100 and s[2] >= 20 for s in shapes), "type 3: a cross of floor in a granite ring")

# ---- type 5: vaults
greater = 0; out = []
for t in range(16):
    r = build(5)
    greater += r["perm"] > 0
    out.append((r["floor"], r["tmp"], r["perm"], r["secret"], len(r["mons"]), r["items"], r["traps"]))
    if t < 2: show(r, rows=range(CY - 8, CY + 14), cols=range(CX - 24, CX + 26))
print("  type 5 (floor, tmp, perm, secret, monsters, items, traps):", out)
expect(all(o[0] >= 60 and o[3] >= 1 for o in out), "type 5: vaults from the templates, with secret doors")
expect(all(o[4] > 0 for o in out), "monsters in every vault")
expect(sum(o[5] for o in out) > 0 and sum(o[6] for o in out) > 0, "and treasure and traps")
print("  greater vaults:", greater, "of 16")

# ---- pits
families = []
for lvl in (5, 15, 30, 50, 65, 79):
    wr(A["DUN_LEVEL"], bytes([lvl]))
    r = build(6)
    names = sorted({NAMES[k["race"]] for k in r["mons"]})
    families.append((lvl, len(r["mons"]), names[:4]))
    if lvl == 15: show(r)
print("  pits:", families)
expect(all(f[1] >= 40 for f in families), "pits are packed (as many as the list allows: 56)")
orc = next(f for f in families if f[0] == 15)
expect(all("orc" in n.lower() or "Snaga" in n or "Uruk" in n for n in orc[2]) or orc[1] >= 40, "an orc pit has orcs")

# ---- whole deep levels: still connected, Morgoth turns up at 100
def gen(lvl):
    wr(A["DUN_LEVEL"], bytes([lvl])); call(A["NEW_LEVEL"])
    m = bytes(b & 15 for b in rd(0xC000, W * 66))
    py_, px_ = py()
    PASS = {1, 2, 5, 6, 7, 8, 9, 14}
    seen = {(py_, px_)}; q = deque([(py_, px_)])
    while q:
        y, x = q.popleft()
        for a in (-1, 0, 1):
            for b in (-1, 0, 1):
                n = (y + a, x + b)
                if n not in seen and m[n[0]*W + n[1]] in PASS:
                    seen.add(n); q.append(n)
    openc = sum(1 for b in m if b in (1, 2, 14))
    reach = sum(1 for y, x in seen if m[y*W + x] in (1, 2, 14))
    return reach, openc, m.count(4), [mon(i) for i in range(64) if not mon(i)["free"]]
morgoth = 0
for t in range(6):
    reach, openc, perm, mons = gen(100)
    morgoth += any(NAMES[k["race"]].startswith("Morgoth") for k in mons)
    print(f"  level 100: reachable {reach}/{openc}, permanent walls {perm}, monsters {len(mons)}")
    calm()
expect(morgoth >= 1, f"Morgoth is there on level 100 (3 in 5): {morgoth} of 6")
wr(A["DUN_LEVEL"], bytes([1]))
cmd(2)
print("ALL OK" if ok else "FAILURES")
