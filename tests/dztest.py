import socket, struct, time, sys
from collections import deque
A = {}
for line in open(sys.argv[1]):
    p = line.split()
    if len(p) >= 4: A[p[3]] = int(p[0], 16)

import os as _os, re as _re
_GAME = _os.path.dirname(_os.path.dirname(_os.path.abspath(sys.argv[1])))
def _records(fname):
    out, cur = [], None
    for line in open(_os.path.join(_GAME, "data", fname)):
        m = _re.match(r"\t; (\d+): (.*) \(level (\d+)\)", line)
        if m:
            cur = dict(name=m.group(2).replace("& ", "").replace("~", ""), level=int(m.group(3)), raw=[]); out.append(cur)
        elif line.startswith("\tdb ") and cur is not None:
            cur["raw"] += [int(x) for x in line[4:].split(",")]
    return out
RACES = _records("races.asm")
KIND_RECS = _records("kinds.asm")
NAMES = [r["name"] for r in RACES]
ONLY_ATT = {i for i, r in enumerate(RACES) if r["raw"][2] & 1}
s = socket.create_connection(("localhost", 11000), timeout=20)
seq = 0
def recv_msg():
    hdr = b""
    while len(hdr) < 5: hdr += s.recv(5 - len(hdr))
    n, rseq = struct.unpack("<IB", hdr)
    d = b""
    while len(d) < n - 1: d += s.recv(n - 1 - len(d))
    return rseq, d
def cmd(c, payload=b""):
    global seq
    seq = seq % 254 + 1
    s.sendall(struct.pack("<IBB", len(payload), seq, c) + payload)
    while True:
        rseq, d = recv_msg()
        if rseq == seq: return d
def rd(addr, n):
    out = b""
    while n:
        k = min(n, 4096); out += cmd(8, bytes([0]) + struct.pack("<HH", addr, k)); addr += k; n -= k
    return out
def wr(addr, data): cmd(9, bytes([0]) + struct.pack("<H", addr) + data)
def set_pc(v): cmd(4, bytes([0]) + struct.pack("<H", v))
def run_to(bp):
    """run until bp; key waits (-more-, tombstone) are skipped by faking a return"""
    waitk = A.get("WAIT_FRESH_KEY")
    t = time.time()
    while True:
        if waitk: cmd(6, bytes([1]) + struct.pack("<H", bp) + bytes([1]) + struct.pack("<H", waitk))
        else: cmd(6, bytes([1]) + struct.pack("<H", bp) + bytes([0, 0, 0]))
        while True:
            rseq, d = recv_msg()
            if rseq == 0: break
        r = cmd(3); pc, sp = struct.unpack("<HH", r[:4])
        if waitk and pc == waitk:
            ret = struct.unpack("<H", rd(sp, 2))[0]
            cmd(4, bytes([1]) + struct.pack("<H", sp + 2)); set_pc(ret)
            continue
        return time.time() - t

KEYQ, KEYSTUB = 0xBE10, 0xBDC0
def install_keys(keys="ama\rTest\r"):
    """read_ascii -> next key from a queue that wraps round"""
    ptr = KEYSTUB + 0x40
    p16 = lambda v: struct.pack("<H", v)
    wr(KEYQ, keys.encode() + b"\0")
    wr(ptr, p16(KEYQ))
    code = (bytes([0x2A]) + p16(ptr) + bytes([0x7E, 0xB7, 0x20, 0x04, 0x21]) + p16(KEYQ)
            + bytes([0x7E, 0x23, 0x22]) + p16(ptr) + bytes([0xC9]))
    wr(KEYSTUB, code)
    wr(A["READ_ASCII"], bytes([0xC3]) + p16(KEYSTUB))

def give_light():
    """a lit torch in the light slot (the old tests were written with a lamp)"""
    t = next(i for i, k in enumerate(KIND_RECS) if k["name"] == "Wooden Torch")
    wr(A["EQUIP"] + 10*14, bytes([t & 255, t >> 8, 1, 0, 0, 1, 0x30, 0x75, 4, 0, 0, 0, 0, 0]))
    wr(A["P_LIGHT"], bytes([1]))
def descend():
    """games start in town: take its down staircase to 50 ft"""
    give_light()
    mm = rd(0xC000, 198 * 66)
    i = next(j for j, b in enumerate(mm) if b & 15 == 8)
    wr(A["PLAYER_Y"], bytes([i // 198])); wr(A["PLAYER_X"], bytes([i % 198]))
    cmd(4, bytes([4]) + struct.pack("<H", 1 << 8)); set_pc(A["DISPATCH"]); run_to(A["MAIN_LOOP"] + 6)
    if not globals().get("KEEP_TRAPS") and "TRAP_LIST" in A: wr(A["TRAP_LIST"], bytes(128))	# (no surprises in other tests)
cmd(1, bytes([2, 0, 0]) + b"test\0")
install_keys()
W, H = 198, 66
CH = "#..##+'#><##%%."
PASS = {1, 2, 5, 6, 7, 8, 9, 14}   # floors, corridor, doors (incl. secret), stairs
def report(tag):
    m = bytes(b & 15 for b in rd(0xC000, W * H))
    px, py, lvl = rd(A["PLAYER_X"], 1)[0], rd(A["PLAYER_Y"], 1)[0], rd(A["DUN_LEVEL"], 1)[0]
    counts = {}
    for b in m: counts[b] = counts.get(b, 0) + 1
    names = ["null","floor","corr","granite","perm","closed","open","secret","down","up","tmp1","tmp2","magma","quartz","litfloor"]
    print(f"== {tag}: level {lvl}, player ({px},{py}) on {names[m[py*W+px]]}")
    print("   ", ", ".join(f"{names[k] if k < len(names) else k}={v}" for k, v in sorted(counts.items())))
    seen = {(py, px)}; q = deque([(py, px)])
    while q:
        y, x = q.popleft()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                ny, nx = y + dy, x + dx
                if (ny, nx) not in seen and m[ny*W+nx] in PASS:
                    seen.add((ny, nx)); q.append((ny, nx))
    openc = sum(1 for i, b in enumerate(m) if b in (1, 2, 8, 9, 14))
    reach = sum(1 for (y, x) in seen if m[y*W+x] in (1, 2, 8, 9, 14))
    print(f"    reachable floor {reach}/{openc}; border ok: {all(m[x]==4 and m[(H-1)*W+x]==4 for x in range(W)) and all(m[y*W]==4 and m[y*W+W-1]==4 for y in range(H))}")
    return m
def dump_map(m, path):
    with open(path, "w") as f:
        for y in range(H):
            f.write("".join(CH[b] if b < len(CH) else "?" for b in m[y*W:(y+1)*W]) + "\n")
def screen():
    tm = rd(0x6000, 80*32*2)
    return ["".join(chr(tm[(r*80+c)*2]) if 32 <= tm[(r*80+c)*2] < 127 else "?" for c in range(80)) for r in range(32)]
bp = A["MAIN_LOOP"] + 6
fc0 = struct.unpack("<H", rd(A["FRAME_COUNTER"], 2))[0]
set_pc(A["ENTER_DUNGEON"])
run_to(bp)
descend()
fc1 = struct.unpack("<H", rd(A["FRAME_COUNTER"], 2))[0]
print(f"generation + first draw took {fc1-fc0} frames")
m = report("first level"); dump_map(m, "level1.txt")
sc = screen()
for r in (0, 1, 2, 15, 16, 30, 31): print(f"{r:2}|{sc[r]}|")
open("screen1.txt", "w").write("\n".join(sc))
for n in range(2, 5):
    i = bytes(b & 15 for b in m).index(8)
    wr(A["PLAYER_X"], bytes([i % W])); wr(A["PLAYER_Y"], bytes([i // W]))
    fc0 = struct.unpack("<H", rd(A["FRAME_COUNTER"], 2))[0]
    cmd(4, bytes([4]) + struct.pack("<H", 1 << 8)); set_pc(A["DISPATCH"]); run_to(bp)
    fc1 = struct.unpack("<H", rd(A["FRAME_COUNTER"], 2))[0]
    print(f"descent took {fc1-fc0} frames; message: {screen()[0].strip()!r}; status: {screen()[31][:30].strip()!r}")
    m = report(f"after > #{n-1}"); dump_map(m, f"level{n}.txt")
cmd(2)
