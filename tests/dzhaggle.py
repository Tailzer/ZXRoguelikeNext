import sys, re
src = open("dztown.py").read()
exec(src.split("# ---- walk into the general store")[0])
PAGE_HAGGLE, PAGE_MAGIC = 84, 52
HG = A["HG_STATE"]
chr_ = chr_adj(p["stats"][5]); prace = p["race"]
p16 = lambda v: struct.pack("<H", v)
def gold(): return player_state()["gold"]
def set_gold(g): wr(A["P_GOLD"], struct.pack("<I", g))
def turn(): return struct.unpack("<H", rd(A["GAME_TURN"], 2))[0]
def in_page(page, fn):
    old = cmd(11, bytes([0x52]))[0]; cmd(10, bytes([2, page])); r = fn(); cmd(10, bytes([2, old])); return r
def hg(store):
    b = in_page(PAGE_HAGGLE, lambda: rd(HG + 7*store, 7))
    return dict(insults=b[0], good=b[1] | b[2] << 8, bad=b[3] | b[4] << 8, open=b[5] | b[6] << 8)
def set_hg(store, insults=0, good=0, bad=0, open_=0):
    in_page(PAGE_HAGGLE, lambda: wr(HG + 7*store, bytes([insults]) + p16(good) + p16(bad) + p16(open_)))
def fixed(store, i):
    return in_page(PAGE_STORE, lambda: struct.unpack("<H", rd(STORE_INV + store*312 + i*13 + 11, 2))[0])
OWNERS = []
_l = open(_os.path.join(G, "stores.asm")).read().split("\n"); _i = _l.index("owner_table:") + 1
while _l[_i].startswith("\tdw own_"):
    OWNERS.append([int(x) for x in _l[_i+2].split()[1].split(",")]); _i += 3
def owner(store): return OWNERS[rd(STORE_OWNER + store, 1)[0]]		# max, min, per, race, insults
# every message on the store's message row, as each key is read: a
# breakpoint on a stub in front of the key queue
LOGSTUB = 0xBD00
def run2(a, b):
    cmd(6, bytes([1]) + p16(a) + bytes([1]) + p16(b))
    while True:
        rseq, d = recv_msg()
        if rseq == 0: break
    return struct.unpack("<H", cmd(3)[:2])[0]
LOGGED = []
DEBUG = 0
def said(): return LOGGED
def visit(store, keys):
    """walk in with these keys -> the first screen; messages in said()"""
    y, x = doors[store]
    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)):
        if T(m[(y+dy)*W + x+dx]) == 1:
            wr(A["PLAYER_Y"], bytes([y+dy])); wr(A["PLAYER_X"], bytes([x+dx])); break
    install_keys(keys)
    wr(LOGSTUB, bytes([0, 0xC3]) + p16(KEYSTUB)); wr(A["READ_ASCII"], bytes([0xC3]) + p16(LOGSTUB))
    set_reg(3, ((-dx & 255) << 8) | (-dy & 255)); set_reg(4, 0); set_pc(A["DISPATCH"])
    LOGGED.clear(); first = None
    for _ in range(200):
        if run2(LOGSTUB, BP) == BP: break
        sc = screen(); first = first or sc
        if DEBUG: print("    rows:", [sc[r].rstrip() for r in (26, 27, 28, 29, 30)])
        t = sc[28].replace("-more-", "").strip()
        if t and (not LOGGED or LOGGED[-1] != t): LOGGED.append(t)
        run2(LOGSTUB + 1, BP)
    return first or screen()
COMMENT1 = ["Done!", "Accepted!", "Fine.", "Agreed!", "Ok.", "Taken!", "You drive a hard bargain, but taken.",
            "You'll force me bankrupt, but it's a deal.", "Sigh.  I'll take it.", "My poor sick children may starve, but done!",
            "Finally!  I accept.", "Robbed again.", "A pleasure to do business with you!", "My spouse will skin me, but accepted."]
def accepted(ms): return any(t in COMMENT1 for t in ms)
def prices(store, e):
    """the C's asking and final prices for one of stock entry e"""
    return (buy_price(store, e["kind"], e["disc"], prace, chr_, e["pval"], e),
            buy_price(store, e["kind"], e["disc"], prace, chr_, e["pval"], e, inf="min_inf"))
set_gold(30000)
print(f"  race {prace}, charisma adjustment {chr_}%")

# ---- buying at the asking price: Enter accepts, and the price is fixed after
SN = 1 if any(e["num"] > 1 for e in stock(1)) else 0
i, e = next((i, e) for i, e in enumerate(stock(SN)) if e["num"] > 1)
ask = buy_price(SN, e["kind"], e["disc"], prace, chr_, e["pval"], e)
final = buy_price(SN, e["kind"], e["disc"], prace, chr_, e["pval"], e, inf="min_inf")
shot = visit(SN, "p" + chr(97 + i) + "\rxxxxxxxx ")
print(f"  {STORES[SN]}: {KINDS[e['kind']]} asking {ask}, final {final}:", shot[3 + i].rstrip())
expect(shot[3 + i][64:].strip() == str(ask), f"the list shows the asking price ({ask})")
g0 = 30000; g1 = gold(); ms = said()
print("   said:", ms)
expect(g0 - g1 == ask and accepted(ms), f"Enter accepts it: paid {g0 - g1}, and '{[t for t in ms if t in COMMENT1]}'")
expect(fixed(SN, i) == ask, "the rest are now at that price")
shot = visit(SN, " ")
expect("[Fixed]" in shot[3 + i] and shot[3 + i][64:].split()[0] == str(ask), f"listed as '{shot[3 + i][64:].strip()}'")
g1 = gold(); visit(SN, "p" + chr(97 + i) + "xxxxxxxx ")
expect(g1 - gold() == ask and accepted(said()), "bought again at the fixed price, no haggling")
expect(hg(SN)["good"] + hg(SN)["bad"] == (1 if 10 <= final < 1000 else 0), f"the bargain remembered: {hg(SN)}")

DEBUG = 0
# ---- haggling down: offer halfway, the shopkeeper comes down, Enter takes it
SN2 = 2
i2, e2 = next((i, e) for i, e in enumerate(stock(SN2)) if buy_price(SN2, e["kind"], e["disc"], prace, chr_, e["pval"], e) >= 40)
ask2 = buy_price(SN2, e2["kind"], e2["disc"], prace, chr_, e2["pval"], e2)
final2 = buy_price(SN2, e2["kind"], e2["disc"], prace, chr_, e2["pval"], e2, inf="min_inf")
mid = (ask2 + final2) // 2
set_hg(SN2); g1 = gold()
visit(SN2, "p" + chr(97 + i2) + str(mid) + "\r\rxxxxxxxx ")
paid = g1 - gold(); ms = said()
print(f"  {STORES[SN2]}: {KINDS[e2['kind']]} asking {ask2}, final {final2}, offered {mid}, paid {paid}:", ms)
expect(final2 <= paid < ask2 and paid >= mid and accepted(ms), "offered less: they come down, and Enter takes their new price")
expect(any(str(mid) in t or str(paid) in t for t in ms), "with a comment naming the prices")

# ---- an insult too many: thrown out, and the doors are locked
o2 = owner(SN2)
set_hg(SN2, insults=o2[4]); t0 = turn()
i3 = next(i for i, e in enumerate(stock(SN2)))
visit(SN2, "p" + chr(97 + i3) + "1\rxxxxxxxx ")
ms = said(); h = hg(SN2)
print(f"  insults {o2[4]} then an offer of 1:", ms, h)
expect(h["open"] and 2500 <= (h["open"] - t0) & 0xFFFF <= 5000, f"thrown out: open again in {(h['open'] - t0) & 0xFFFF} turns")
expect(any("!" in t for t in ms) and h["good"] == 0 and h["bad"] == 0, "'ENOUGH!...': good and bad bargains forgotten")
call(A["MSG_CLEAR"])
shot = visit(SN2, " ")
def msgline(): return screen()[0]
print("  again:", repr(msgline()))
expect("The doors are locked." in msgline() and not any("Purchase" in r for r in screen()), "'The doors are locked.'")
wr(A["GAME_TURN"], p16(h["open"]))
shot = visit(SN2, " ")
expect(any("Purchase" in r for r in shot) and hg(SN2)["open"] == 0, "and open once the time is up")
wr(A["GAME_TURN"], p16(t0))

# ---- a small insult: an offer below the last
set_hg(SN2)
g1 = gold(); visit(SN2, "p" + chr(97 + i3) + "1\rx \rxxxxxxxx ")		# (insulted, a counter-offer, then quit)
print("  an offer of 1:", said(), hg(SN2))
expect(hg(SN2)["insults"] == 1 and gold() == g1, "an offer of 1: one insult ('That's an insult!'...), and space quits")

# ---- the liar
set_hg(SN); set_gold(1)
in_page(PAGE_STORE, lambda: wr(STORE_INV + SN*312 + 11, p16(50)))			# (a fixed price of 50)
visit(SN, "paxxxxxxxx ")
ms = said()
print("  with 1 gold:", ms, hg(SN))
expect("Liar!  You have not the gold!" in ms and hg(SN)["insults"] == 1 and gold() == 1, "'Liar!  You have not the gold!' (an insult)")
set_gold(30000)

# ---- no need to bargain: good at it here before
i4, e4 = next((i, e) for i, e in enumerate(stock(0)) if fixed(0, i) == 0)
ask4, final4 = prices(0, e4)[:2]
set_hg(0, good=40, bad=1); g1 = gold()
visit(0, "p" + chr(97 + i4) + "\rxxxxxxxx ")
ms = said()
print(f"  a good customer: asking {ask4}, final {final4}, paid {g1 - gold()}", ms)
expect("After a long bargaining session, you agree upon the price." in ms and g1 - gold() == final4, "'After a long bargaining session...': straight to the final price")

# ---- selling: their first offer, then what they make of it
def sale_price(store, value):
    o = OWN[rd(STORE_OWNER + store, 1)[0]]
    c = value * (200 - chr_) // 100
    c = max(1, c * (200 - RG[o["race"]][prace]) // 100)
    return min(max(1, c * (200 - o["max_inf"]) // 100), o["purse"])
CSW = next(i for i, k in enumerate(KIND_RECS) if k["name"] == "Potion of Cure Serious Wounds")
oi = A["OBJECT_IDENT"] + 5*64 + KIND_RECS[CSW]["raw"][22]
wr(A["PACK"], bytes([CSW & 255, CSW >> 8, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0])); wr(oi, bytes([0]))
SELL = 4 if not hg(4)["open"] else 3
set_hg(SELL); want = sale_price(SELL, 20); g1 = gold()
visit(SELL, "sa\rxxxxxxxx ")
ms = said()
print(f"  sold an unknown potion (worth {KCOST[CSW]}): {gold() - g1} gold (offer on 20: {want})", ms)
expect(gold() - g1 == want and any(t.startswith("Selling ") for t in ms) and accepted(ms), "'Selling...', Enter takes their offer")
GLAD = ["You hear someone giggling", "You've made my day!", "What a fool!", "The shopkeeper laughs loudly!",
        "You hear someone jumping for joy!", "Yipee!", "I think I'll retire!", "The shopkeeper smiles gleefully!"]
expect(KCOST[CSW] <= 20 or any(t in GLAD for t in ms), "worth more than they paid: the shopkeeper's glee")
# something worthless
JUNK = next((i for i, k in enumerate(KIND_RECS) if k["raw"][15] in (70, 71, 75, 76) and KCOST[i] == 0 and k["raw"][2] == KIND_RECS[CSW]["raw"][2]), None)
if JUNK is not None:
    wr(A["PACK"], bytes([JUNK & 255, JUNK >> 8, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]))
    wr(A["OBJECT_IDENT"] + 5*64 + KIND_RECS[JUNK]["raw"][22], bytes([2]))
    set_hg(SELL); g1 = gold()
    visit(SELL, "sa\rxxxxxxxx ")
    ms = said()
    print(f"  selling a known {KINDS[JUNK]}:", ms, hg(SELL))
    expect("How dare you!" in ms and "I will not buy that!" in ms and hg(SELL)["insults"] == 1 and gold() == g1, "worthless: 'How dare you!' 'I will not buy that!' (an insult)")

# ---- every 1000 turns in the dungeon the stores turn over and calm down
s0 = [stock(sn) for sn in range(7)]
for sn in range(8): set_hg(sn, insults=3)
wr(A["DUN_LEVEL"], bytes([1])); wr(A["GAME_TURN"], p16(2001))
cmd(10, bytes([2, PAGE_MAGIC])); call(A["STORE_TURNOVER"])
expect([stock(sn) for sn in range(7)] == s0 and hg(0)["insults"] == 3, "not at turn 2001")
wr(A["GAME_TURN"], p16(2000))
cmd(10, bytes([2, PAGE_MAGIC])); call(A["STORE_TURNOVER"])
changed = sum(stock(sn) != s0[sn] for sn in range(7))
print(f"  turn 2000 on level 1: {changed} of 7 stores changed, insults {[hg(sn)['insults'] for sn in range(8)]}")
expect(changed >= 5 and all(hg(sn)["insults"] == 0 for sn in range(8)), "at turn 2000: new stock, insults forgotten")
s1 = [stock(sn) for sn in range(7)]
wr(A["DUN_LEVEL"], bytes([0])); cmd(10, bytes([2, PAGE_MAGIC])); call(A["STORE_TURNOVER"])
expect([stock(sn) for sn in range(7)] == s1, "but not in the town")
cmd(2)
print("ALL OK" if ok else "FAILURES")
