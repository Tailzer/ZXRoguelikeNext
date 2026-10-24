import sys, os
src = open("dzitems.py").read()
exec(src.split('set_pc(A["ENTER_DUNGEON"]); run_to(BP)')[0])
SD = os.path.join(os.path.dirname(os.path.abspath("dzsave.py")), "sd", "roguelike.sav")
set_pc(A["ENTER_DUNGEON"]); run_to(BP)
descend()
wr(A["READ_ASCII"], bytes([0x3A]) + struct.pack("<H", A["ASCII_KEY"]) + bytes([0xC9]))
def ov(routine):
    cmd(10, bytes([2, 57])); r = call(A[routine]); return r[2] & 1    # carry from F
def snap():
    return dict(gold=rd(A["P_GOLD"], 4), exp=rd(A["P_EXP"], 4), chp=rd(A["P_CHP"], 2), lev=rd(A["P_LEV"], 1),
                pos=rd(A["DUN_LEVEL"], 5), turn=rd(A["GAME_TURN"], 2), know=rd(0x7C00, 0x2B0),
                high=rd(0xB000, A["HIGH_RAM_END"] - 0xB000), mapb=rd(0xC000, 198*66), name=rd(A["P_NAME"], 24), stat=rd(A["P_STAT"], 6),
                blind=rd(A["P_BLIND"], 2))
def page_bytes(page, addr, n):
    cmd(10, bytes([3, page])); b = rd(addr, n); cmd(10, bytes([3, 11])); return b
if os.path.exists(SD): os.remove(SD)
# something to remember
wr(A["P_GOLD"], struct.pack("<I", 12345)); wr(A["P_EXP"], struct.pack("<I", 777)); w16("P_BLIND", 9)
food = next(i for i, k in enumerate(KIND_RECS) if k["raw"][2] == 1)
wr(A["PACK"], bytes([food & 255, food >> 8, 7, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]))
store0 = page_bytes(51, A["STORE_INV"] + 0x2000, 64)
titles0 = page_bytes(64, A["SCROLL_TITLES"] + 0x4000, 40)
before = snap()
call(A["MSG_CLEAR"])
c = ov("SAVE_GAME")
print("  save: carry", c, repr(msgline()), "file", os.path.getsize(SD) if os.path.exists(SD) else None)
expect(c and os.path.exists(SD) and os.path.getsize(SD) > 16000, "Symbol Shift + X saves the game to roguelike.sav")
expect("Saving game..." in msgline(), "'Saving game...'")
# scramble everything, then restore
wr(A["P_GOLD"], struct.pack("<I", 1)); wr(A["P_EXP"], struct.pack("<I", 1)); w16("P_BLIND", 0)
wr(A["DUN_LEVEL"], bytes([9, 1, 1, 0, 0])); wr(0xB000, bytes(0x100)); wr(0xC000, bytes(2000)); wr(0x7C00, bytes(64))
cmd(10, bytes([3, 51])); wr(A["STORE_INV"] + 0x2000, bytes(64)); cmd(10, bytes([3, 64])); wr(A["SCROLL_TITLES"] + 0x4000, bytes(40)); cmd(10, bytes([3, 11]))
wr(A["P_UPDATE"], bytes([0]))
c = ov("LOAD_GAME")
after = snap()
diff = [k for k in before if before[k] != after[k]]
print("  load: carry", c, "differences", diff)
expect(c and not diff, "restoring brings back the character, monsters, items, pack, map and knowledge")
expect(page_bytes(51, A["STORE_INV"] + 0x2000, 64) == store0 and page_bytes(64, A["SCROLL_TITLES"] + 0x4000, 40) == titles0, "and the stores' stock and this game's scroll titles")
expect(rd(A["P_UPDATE"], 1)[0] & 7 == 7, "bonuses are worked out afresh after restoring")
# from the title: a key restores it and play carries on
wr(A["WAIT_ANY_KEY"], bytes([0xC9]))
wr(A["P_GOLD"], struct.pack("<I", 5)); wr(A["DUN_LEVEL"], bytes([7]))
set_pc(A["START"]); run_to(BP)
print("  from the title:", struct.unpack("<I", rd(A["P_GOLD"], 4))[0], "gold, depth", rd(A["DUN_LEVEL"], 1)[0], repr(screen()[31].strip()))
expect(struct.unpack("<I", rd(A["P_GOLD"], 4))[0] == 12345 and rd(A["DUN_LEVEL"], 1)[0] == before["pos"][0], "starting the game again carries on from the save")
# another build's save is left alone
data = open(SD, "rb").read()
open(SD, "wb").write(data[:5] + bytes([data[5] ^ 1]) + data[6:])
wr(A["P_GOLD"], struct.pack("<I", 5))
c = ov("LOAD_GAME")
print("  tampered:", c, repr(screen()[0].strip()))
expect(not c and struct.unpack("<I", rd(A["P_GOLD"], 4))[0] == 5, "a save whose blocks don't fit this build isn't loaded")
open(SD, "wb").write(data[:3000])
c = ov("LOAD_GAME")
print("  short:", c, repr(screen()[0].strip()))
expect(not c, "a save cut short isn't used")
open(SD, "wb").write(data)
# death deletes it
ov("DELETE_SAVE")
print("  after death:", os.path.getsize(SD) if os.path.exists(SD) else "deleted")
expect(not os.path.exists(SD) or open(SD,"rb").read(5) == b"DEAD!", "dying deletes the save (or marks it dead, where it cannot be deleted)")
call(A["MSG_CLEAR"])
c = ov("LOAD_GAME")
expect(not c and "saved game" not in screen()[0], "with no save, a new game starts (nothing said)")
cmd(2)
print("ALL OK" if ok else "FAILURES")
