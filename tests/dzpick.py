import sys, re
src = open("dzrest.py").read()
exec(src.split("# ---- R 5")[0])
MEM_PAGE = 74
cmd(10, bytes([2, 57])); call(A["MEM_FORGET"])
def status(): call(A["DRAW_STATUS"]); return screen()[31]

# ---- resting on the status line
w16("P_MHP", 300); w16("P_CHP", 20)
patch_get(CMD_REST); install_keys("5\r")
d, b, c = next_cmd()
patch_get()
st = status()
print("  resting:", st.strip())
expect("Rest 4" in st, "'R' 5: 'Rest 4' on the status line, counting down")
while d == CMD_REST_TURN:
    do(d, b, c); calm(); d, b, c = next_cmd()
expect("Rest" not in status(), "and gone when it's over")
w16("P_CHP", 20)
patch_get(CMD_REST); install_keys("\r")
d, b, c = next_cmd(); patch_get()
st = status()
print("  till better:", st.strip())
expect("Rest *****" in st, "resting till better: 'Rest *****'")
while d == CMD_REST_TURN:
    do(d, b, c); calm(); d, b, c = next_cmd()
expect("Rest" not in status(), "gone again")

# ---- monsters that pick things up
def steady(r): return r["raw"][2] & 2 and not r["raw"][2] & 0x1D and not r["raw"][13] & 1 and not r["raw"][14] & 6
cmd(10, bytes([1, 77])); RI = rd(A["RINFO_TABLE"], len(NAMES) * 11)
PICKER = next(i for i in range(len(NAMES)) if RI[i*11 + 2] & 0x10 and steady(RACES[i]) and RACES[i]["level"] > 0)
PLAIN = next(i for i in range(len(NAMES)) if not RI[i*11 + 2] & 0x18 and steady(RACES[i]) and RACES[i]["level"] > 0)
print("  picker:", NAMES[PICKER], " plain:", NAMES[PLAIN])
calm(); full(); call(A["LIGHT_REFRESH"])
walk_to_room(); call(A["UPDATE_VIEW"])
y0, x0 = py()
DIRS = {(1, -1), (1, 0), (1, 1), (0, -1), (0, 1), (-1, -1), (-1, 0), (-1, 1)}
mm = rd(0xC000, W*66)
dy, dx = next((a, b) for a, b in DIRS if all(mm[(y0 + a*k)*W + x0 + b*k] & 15 in (1, 2, 14) for k in (1, 2, 3)))
near, far = (y0 + dy, x0 + dx), (y0 + 2*dy, x0 + 2*dx)
wr(A["P_EFLAGS2"], bytes([0x20]))
IS = 14
DAGGER = next(i for i, k in enumerate(KIND_RECS) if k["name"] == "Dagger")
def put_floor(kind, name2=0):
    for i in range(64): wr(0xB400 + IS*i + 1, bytes([255]))
    if kind == "gold":
        wr(0xB400, bytes([0, 0xFE, 1, near[0], near[1], 0, 50, 0, 0, 0, 0, 0, 0, 0]))
    else:
        wr(0xB400, bytes([kind & 255, kind >> 8, 1, near[0], near[1], 0, 0, 0, 0, 0, 0, 0, name2, 0]))
def walk(race):
    calm(); place(0, race, *far); wr(0xB000 + 9, bytes([1])); wr(0xB000 + 11, bytes([1]))
    set_reg(6, 0xB000); call(A["MON_TURN"])
    return (mon(0)["y"], mon(0)["x"]), rd(0xB400 + 1, 1)[0] != 255
put_floor(DAGGER); at, there = walk(PICKER)
print("  picker:", at, near, there)
expect(at == near and not there, f"{NAMES[PICKER]} steps onto a Dagger: it's gone (picked up)")
cmd(10, bytes([1, MEM_PAGE + (PICKER >> 8)])); cm = struct.unpack("<I", rd(0x2000 + (PICKER & 255)*32, 4))[0]
expect(cm & 0x100000, "seen: 'pick up objects' remembered")
put_floor("gold"); at, there = walk(PICKER)
expect(at == near and there, "but not gold")
ART = A["SN_RINGIL"]
put_floor(DAGGER, ART); at, there = walk(PICKER)
expect(at == near and there, "nor an artifact")
put_floor(DAGGER); at, there = walk(PLAIN)
expect(at == near and there, f"{NAMES[PLAIN]} walks over it")
cmd(2)
print("ALL OK" if ok else "FAILURES")
