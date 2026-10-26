/* haggle.asm - haggling with shopkeepers (overlay page PAGE_HAGGLE)
	References: STORE2.C purchase_haggle/sell_haggle/receive_offer/
	get_haggle/the insults and comments, STORE1.C noneedtobargain/
	updatebargain. store.asm works out the prices and puts them in hg_in
	(through the data window: HGSET), then calls in; each store's
	bargaining record (insults, good and bad buys, when it opens again)
	lives here, and is saved with the stores.
	Offers are typed as numbers; +n or -n (Symbol Shift + K, J) changes
	the last one by n, Enter alone accepts (or repeats the last change),
	and space quits haggling (the C's ESC).
 */

HG_INSULTS		equ 0					; per store: insults so far
HG_GOOD			equ 1					; word: deals at the final price
HG_BAD			equ 3					; word: deals above it
HG_OPEN			equ 5					; word: the turn it opens again (0: open)
HG_SIZE			equ 7
ASK_ROW			equ STORE_PROMPT_ROW+1	; "Asking :  250", "Your last offer"

; ---------------------------------------------------------------- the record

/* hg_rec - (hg_store) -> IX = its bargaining record */
hg_rec:
	ld a,(hg_store)
hg_rec_a:
	ld e,a
	ld d,HG_SIZE
	mul d,e
	ld ix,hg_state
	add ix,de
	ret

/* store_closed - A = store -> carry if it has thrown you out and isn't
	open again yet ("The doors are locked."). Preserves nothing */
store_closed:
	call hg_rec_a
	ld l,(ix+HG_OPEN)
	ld h,(ix+HG_OPEN+1)
	ld a,h
	or l
	ret z								; (open)
	ex de,hl
	ld hl,(game_turn)					; turn - open, as a signed number
	or a
	sbc hl,de
	bit 7,h
	scf
	ret nz								; not yet
	xor a								; open again
	ld (ix+HG_OPEN),a
	ld (ix+HG_OPEN+1),a
	ret

/* store_init - every store gets one of its three possible owners,
	nothing in stock and no grudges (store_init in STORE1.C; kept here, the
	store page being full) */
store_init:
	ld hl,hg_state
	ld b,NUM_STORES*HG_SIZE
.clear:
	ld (hl),0
	inc hl
	djnz .clear
	ld b,0
.each:
	push bc
	ld a,3
	call randint
	dec a
	add a,a
	add a,a
	add a,a								; 8 * (1d3 - 1) + store
	pop bc
	push bc
	add a,b
	ld hl,STORE_OWNER
	ld e,b
	ld d,0
	add hl,de
	ld (hl),a
	ld hl,STORE_COUNT
	add hl,de
	ld (hl),0
	pop bc
	inc b
	ld a,b
	cp NUM_STORES
	jr c,.each
	ret

/* hg_door - A = store you're going into -> carry if it's locked ("The
	doors are locked."), else A = your charisma's price adjustment
	(chr_adj in MISC2.C) */
hg_door:
	cp STORE_HOME
	jr z,.open
	call store_closed
	jr nc,.open
	ld hl,txt_locked
	call msg_print
	scf
	ret
.open:
	ld a,(p_stat_use+A_CHR)
	ld hl,chr_table
.chr:
	cp (hl)
	jr c,.found
	inc hl
	inc hl
	jr .chr
.found:
	inc hl
	ld a,(hl)
	or a
	ret

/* hg_calm - every store forgets its insults (store_maint) */
hg_calm:
	ld ix,hg_state
	ld b,NUM_STORES
	ld de,HG_SIZE
.each:
	ld (ix+HG_INSULTS),0
	add ix,de
	djnz .each
	ret

/* increase_insults - A = store: one more; past the owner's patience (A on
	entry to haggle: hg_insult_max) it throws you out, closed for 2500 +
	1d2500 turns -> carry if so */
increase_insults:
	ld (hg_store),a
	call hg_rec
	inc (ix+HG_INSULTS)
	ld a,(hg_insult_max)
	cp (ix+HG_INSULTS)
	ret nc								; (no carry: still talking)
	ld a,5								; "ENOUGH!..." "Out of my place!"
	call randint
	dec a
	push af
	ld hl,comment4a
	call hg_pick
	call hg_say
	pop af
	ld hl,comment4b
	call hg_pick
	call hg_say
	call hg_rec
	xor a
	ld (ix+HG_INSULTS),a
	ld (ix+HG_GOOD),a
	ld (ix+HG_GOOD+1),a
	ld (ix+HG_BAD),a
	ld (ix+HG_BAD+1),a
	ld hl,2500
	call randint16
	ld de,2500
	add hl,de
	ld de,(game_turn)
	add hl,de
	ld a,h
	or l
	jr nz,$+3
	inc hl								; (0 would mean open)
	ld (ix+HG_OPEN),l
	ld (ix+HG_OPEN+1),h
	scf
	ret

/* decrease_insults - A = store: one fewer, after a deal */
decrease_insults:
	call hg_rec_a
	ld a,(ix+HG_INSULTS)
	or a
	ret z
	dec (ix+HG_INSULTS)
	ret

/* haggle_insults - an offer that insults: carry if it got you thrown out,
	else "That's an insult!" (comment5) */
haggle_insults:
	ld a,(hg_store)
	call increase_insults
	ret c
	ld a,10
	call randint
	dec a
	ld hl,comment5
	call hg_pick
	call hg_say
	or a
	ret

/* noneed - DE = the final price: carry if you've bargained well enough
	with this store before to go straight to it (noneedtobargain) */
noneed:
	push de
	call hg_rec
	pop de
	ld l,(ix+HG_GOOD)
	ld h,(ix+HG_GOOD+1)
	ld a,h								; good == MAX_SHORT
	and l
	inc a
	scf
	ret z
	push hl								; or the price under 5000 and
	ld hl,4999							; good > 2 * bad + 3
	or a
	sbc hl,de
	pop hl
	ccf
	ret nc
	ld e,(ix+HG_BAD)
	ld d,(ix+HG_BAD+1)
	ex de,hl
	add hl,hl
	inc hl
	inc hl
	inc hl
	ex de,hl
	or a
	sbc hl,de
	ret z
	ccf
	ret

/* update_bargain - (hg_price) agreed, (hg_final) the final price: between
	10 and 999, a deal at the final price is a good buy, else a bad one */
update_bargain:
	ld hl,(hg_final)
	ld de,10
	or a
	sbc hl,de
	ret c
	ld hl,(hg_final)
	ld de,1000
	or a
	sbc hl,de
	ret nc
	call hg_rec
	ld hl,(hg_price)
	ld de,(hg_final)
	or a
	sbc hl,de
	ld de,HG_GOOD
	jr z,$+5
	ld de,HG_BAD
	push ix
	pop hl
	add hl,de
	inc (hl)							; (at most 65535)
	ret nz
	inc hl
	inc (hl)
	ret nz
	dec (hl)
	dec hl
	dec (hl)
	ret

; ---------------------------------------------------------------- buying

/* purchase_haggle - hg_in set: haggle over buying (purchase_haggle) ->
	A = 0 and HL = the price agreed, 1 you gave up, 2 thrown out */
purchase_haggle:
	ld a,1
	ld (hg_factor),a					; (1 buying, $FF selling)
	call hg_begin
	ld hl,txt_offer_cmd
	call hg_commands
	ld hl,(hg_least)					; last_offer = the least offer
	ld (hg_last),hl
	ld hl,(hg_ask)
	ld (hg_cur),hl
	ld hl,txt_asking
	ld (hg_comment),hl
	ld de,(hg_final)
	call noneed
	jr nc,.loop
	ld hl,txt_long_session
	call hg_say
	ld hl,(hg_final)
	ld (hg_cur),hl
.loop:
	ld hl,txt_what_offer
	call receive_offer
	or a
	ret nz
	ld hl,(hg_new)						; more than asked: "What was that?"
	ld de,(hg_cur)
	or a
	sbc hl,de
	jp z,.agreed
	jr c,.below
	call hg_pardon
	jr .loop
.below:
	ld hl,(hg_new)						; x1 = (new - last) * 100 / (cur - last)
	ld de,(hg_last)
	or a
	sbc hl,de
	push hl
	ld hl,(hg_cur)
	or a
	sbc hl,de
	ld b,h
	ld c,l
	pop hl
	call hg_step						; -> HL = how far the price comes
	ret c								; (thrown out)
	ex de,hl							; cur -= x3
	ld hl,(hg_cur)
	or a
	sbc hl,de
	jr c,.final
	ld (hg_cur),hl
	ld de,(hg_final)
	or a
	sbc hl,de
	jr c,.final
	ld hl,(hg_new)						; their price is down to yours
	ld de,(hg_cur)
	or a
	sbc hl,de
	jr nc,.agreed_new
	jr .again
.final:
	ld hl,(hg_final)
	ld (hg_cur),hl
	call hg_final_offer
	ret nz								; (enough of that: out, or done)
.again:
	ld hl,(hg_new)
	ld (hg_last),hl
	ld hl,hg_num
	inc (hl)
	ld hl,txt_last_offer
	call hg_show_last
	ld hl,(hg_last)						; comment2: A1 offer, A2 asking
	ld (hg_a1),hl
	ld hl,(hg_cur)
	ld (hg_a2),hl
	ld a,(hg_final_flag)
	or a
	ld hl,comment2b
	ld a,16
	jr z,$+7
	ld hl,comment2a
	ld a,3
	call hg_comment_n
	jp .loop
.agreed_new:
	ld hl,(hg_new)
	jr .deal
.agreed:
	ld hl,(hg_new)
.deal:
	ld (hg_price),hl
	call update_bargain
	ld hl,(hg_price)
	xor a
	ret

; ---------------------------------------------------------------- selling

/* sell_haggle - hg_in set (hg_ask their first offer, hg_final their last,
	hg_least the most you'd want, hg_purse what they have): haggle over
	selling (sell_haggle) -> A = 0 and HL = the price, 1, or 2 as buying */
sell_haggle:
	ld a,$FF
	ld (hg_factor),a
	call hg_begin
	ld hl,txt_ask_cmd
	call hg_commands
	ld hl,txt_offer_word
	ld (hg_comment),hl
	ld hl,(hg_ask)						; more than they can afford?
	ld de,(hg_purse)
	or a
	sbc hl,de
	jr z,.affords
	jr c,.affords
	ld a,1
	ld (hg_final_flag),a
	ld (hg_final_on),a
	ld hl,txt_final_offer
	ld (hg_comment),hl
	ld hl,(hg_purse)
	ld (hg_cur),hl
	ld (hg_final),hl
	ld hl,txt_cant_afford
	call hg_say
	jr .start
.affords:
	ld hl,(hg_ask)
	ld (hg_cur),hl
	ld hl,(hg_final)					; (no more than the purse)
	ld de,(hg_purse)
	or a
	sbc hl,de
	jr c,.within
	ld (hg_final),de
.within:
	ld de,(hg_final)
	call noneed
	jr nc,.start
	ld hl,txt_long_session
	call hg_say
	ld hl,(hg_final)
	ld (hg_cur),hl
.start:
	ld hl,(hg_least)
	ld (hg_last),hl
	ld hl,(hg_cur)						; (at least 1)
	ld a,h
	or l
	jr nz,.loop
	inc hl
	ld (hg_cur),hl
.loop:
	ld hl,txt_what_price
	call receive_offer
	or a
	ret nz
	ld hl,(hg_new)						; less than offered: "What was that?"
	ld de,(hg_cur)
	or a
	sbc hl,de
	jp z,purchase_haggle.agreed
	jr nc,.above
	call hg_pardon
	jr .loop
.above:
	ld hl,(hg_last)						; x1 = (last - new) * 100 / (last - cur)
	ld de,(hg_cur)
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ld hl,(hg_last)
	ld de,(hg_new)
	or a
	sbc hl,de
	call hg_step
	ret c
	ld de,(hg_cur)						; cur += x3
	add hl,de
	jr c,.final
	ld (hg_cur),hl
	ex de,hl
	ld hl,(hg_final)
	or a
	sbc hl,de
	jr c,.final
	ld hl,(hg_cur)						; up to what you asked
	ld de,(hg_new)
	or a
	sbc hl,de
	jp nc,purchase_haggle.agreed_new
	jr .again
.final:
	ld hl,(hg_final)
	ld (hg_cur),hl
	call hg_final_offer
	ret nz
.again:
	ld hl,(hg_new)
	ld (hg_last),hl
	ld hl,hg_num
	inc (hl)
	ld hl,txt_last_bid
	call hg_show_last
	ld hl,(hg_cur)						; comment3: A1 offer, A2 asking
	ld (hg_a1),hl
	ld hl,(hg_last)
	ld (hg_a2),hl
	ld a,(hg_final_flag)
	or a
	ld hl,comment3b
	ld a,15
	jr z,$+7
	ld hl,comment3a
	ld a,3
	call hg_comment_n
	jp .loop

; ---------------------------------------------------------------- shared

/* hg_begin - a new haggle: nothing offered yet */
hg_begin:
	xor a
	ld (hg_num),a
	ld (hg_final_flag),a
	ld (hg_final_on),a
	ld hl,0
	ld (hg_new),hl
	ld a,(hg_said)
	ld (hg_shown),a
	ret

/* hg_flush - a message still not seen: "-more-" and a key, before the
	store's screen is drawn again */
hg_flush:
	ld a,(hg_shown)
	or a
	ret z
	xor a
	ld (hg_shown),a
	ld hl,txt_more
	ld d,STORE_MSG_ROW
	ld e,70
	ld c,ATTR_GREY
	call print_at
	jp read_ascii

/* hg_step - HL = how far you came, BC = how far apart you were: the
	shopkeeper's answer (x1 = HL * 100 / BC; too small an offer insults;
	x2 = x1 + 1d5 - 3, at most 3 x haggle_per; x3 = gap * x2 / 100 + 1)
	-> HL = x3, how far they come; carry if you were thrown out */
hg_step:
	push hl
	ld a,100
	call mul16_8						; E:HL = HL * 100
	call div24_16						; HL = x1
	ld (hg_x),hl
	pop hl
	ld a,(hg_per)						; x1 < haggle_per: an insult
	ld e,a
	ld d,0
	ld hl,(hg_x)
	or a
	sbc hl,de
	jr nc,.enough
	call haggle_insults
	jr nc,.x2
	ld a,2								; (thrown out)
	ret
.enough:
	ld a,(hg_per)						; x1 > 3 x haggle_per: 3/4 of it,
	ld e,a								; not below 3 x haggle_per
	ld d,3
	mul d,e
	ld (hg_max_per),de
	ld hl,(hg_x)
	or a
	sbc hl,de
	jr z,.x2
	jr c,.x2
	ld hl,(hg_x)
	ld a,75
	call mul16_8
	ld c,100
	call div24_8
	ld (hg_x),hl
	ld de,(hg_max_per)
	or a
	sbc hl,de
	jr nc,.x2
	ld (hg_x),de
.x2:
	ld a,5								; x2 = x1 + 1d5 - 3
	call randint
	ld hl,(hg_x)
	add hl,a
	ld de,3
	or a
	sbc hl,de
	ld (hg_x),hl
	ld hl,(hg_cur)						; the gap: |cur - new|
	ld de,(hg_new)
	or a
	sbc hl,de
	jr nc,.gap
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
.gap:
	ld a,(hg_x+1)						; x2 < 0: x3 = 1 - gap*|x2|/100
	bit 7,a
	jr nz,.less
	ld a,(hg_x)
	call mul16_8
	ld c,100
	call div24_8
	inc hl
	or a
	ret
.less:
	ld a,(hg_x)
	neg
	call mul16_8
	ld c,100
	call div24_8
	ex de,hl
	ld hl,1
	or a
	sbc hl,de
	jr nc,$+5
	ld hl,0								; (never the wrong way)
	or a
	ret

/* hg_final_offer - the price has reached their final word: "Final Offer",
	and after a fourth time an insult, or giving up -> NZ (A = 1 or 2) if
	that's the end, Z to carry on */
hg_final_offer:
	ld a,1
	ld (hg_final_on),a
	ld hl,txt_final_offer
	ld (hg_comment),hl
	ld hl,hg_final_flag
	inc (hl)
	ld a,(hl)
	cp 4
	jr nc,.enough
	xor a
	ret
.enough:
	ld a,(hg_store)
	call increase_insults
	ld a,2
	jr c,.out
	dec a
.out:
	or a
	ret

/* receive_offer - HL = the question: offers until one moves the right
	way (receive_offer) -> A = 0 with (hg_new), 1 quit, 2 thrown out */
receive_offer:
	ld (hg_question),hl
.ask:
	call hg_show_asking
	call get_haggle
	ld a,1
	ret nc								; (space: no more haggling)
	ld hl,(hg_new)						; new >= last buying, <= selling
	ld de,(hg_last)
	or a
	sbc hl,de
	jr z,.ok
	ld a,(hg_factor)
	jr c,.less
	dec a
	jr z,.ok							; (buying: more is the right way)
	jr .wrong
.less:
	inc a
	jr z,.ok							; (selling: less is)
.wrong:
	call haggle_insults
	ld a,2
	ret c
	ld hl,(hg_last)						; (as if not said)
	ld (hg_new),hl
	jr .ask
.ok:
	xor a
	ret

/* hg_pardon - "What was that?" (comment6), and the offer forgotten */
hg_pardon:
	ld a,5
	call randint
	dec a
	ld hl,comment6
	call hg_pick
	call hg_say
	ld hl,(hg_last)
	ld (hg_new),hl
	ret

/* get_haggle - (hg_question): an offer typed (get_haggle) -> carry and
	(hg_new), or no carry if space quit */
get_haggle:
	xor a
	ld (hg_inc),a
.again:
	call msg_begin						; "What do you offer? [accept] "
	ld hl,(hg_question)
	call msg_add
	ld hl,(hg_last_inc)
	ld a,h
	or l
	jr z,.accept
	ld a,(hg_final_on)
	or a
	jr nz,.accept
	ld a,'['
	call hg_char
	ld hl,(hg_last_inc)
	ld a,'+'
	bit 7,h
	jr z,.sign
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
	ld a,'-'
.sign:
	ld (hg_t),hl
	call hg_char
	ld hl,hg_t
	call msg_add_u16
	ld hl,txt_close_sp
	call msg_add
	jr .shown
.accept:
	ld hl,txt_accept
	call msg_add
.shown:
	ld hl,(msg_ptr)
	ld (hg_field),hl
	call hg_input						; -> carry if space, else hg_buf
	jr nc,.typed
	ld hl,0
	ld (hg_last_inc),hl
	or a
	ret
.typed:
	ld a,(hg_buf)						; i, and whether +/- leads
	ld (hg_sign),a
	call hg_number						; HL = |i|, signed by the lead
	ld a,(hg_sign)
	cp '+'
	jr z,.signed
	cp '-'
	jr nz,.plain
.signed:
	ld a,(hg_num)
	or a
	jr nz,.plain
	push hl
	ld hl,txt_first_offer
	call hg_say
	pop hl
	ld hl,0
.plain:
	ld a,h								; i = 0: the last change again, or
	or l								; accept
	jr nz,.got
	ld hl,(hg_last_inc)
	ld a,h
	or l
	jr z,.price
	ld a,(hg_final_on)
	or a
	jr nz,.price
	ld a,1
	ld (hg_inc),a
	jr .got
.price:
	ld hl,(hg_cur)
	ld a,h
	or l
	jp z,.again
.got:
	ld (hg_i),hl
	ld a,(hg_sign)						; +n, -n, or the change again
	cp '+'
	jr z,.add
	cp '-'
	jr z,.add
	ld a,(hg_inc)
	or a
	jr nz,.add
	ld (hg_new),hl						; a price
	ld hl,0
	ld (hg_last_inc),hl
	scf
	ret
.add:
	ld (hg_last_inc),hl
	ld de,(hg_new)
	bit 7,h
	jr nz,.minus
	add hl,de
	jr nc,.set
	ld hl,$FFFF
	jr .set
.minus:
	add hl,de
	jr c,.set
	ld hl,0
.set:
	ld (hg_new),hl
	scf
	ret

/* hg_number - hg_buf -> HL = its number (to 65535), negative if it begins
	with '-' */
hg_number:
	ld hl,0
	ld de,hg_buf
.skip:
	ld a,(de)
	cp '+'
	jr z,.next
	cp '-'
	jr nz,.digits
.next:
	inc de
.digits:
	ld a,(de)
	inc de
	sub '0'
	jr c,.done
	cp 10
	jr nc,.done
	push de
	ld d,h
	ld e,l
	add hl,hl
	jr c,.big
	add hl,hl
	jr c,.big
	add hl,de
	jr c,.big
	add hl,hl
	jr c,.big
	add hl,a
	jr c,.big
	pop de
	jr .digits
.big:
	pop de
	ld hl,$FFFF
.done:
	ld a,(hg_buf)
	cp '-'
	ret nz
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
	ret

/* hg_input - the question in msg_buf: typed after it on the prompt row
	(digits, a leading + or -, delete; Enter ends) -> hg_buf, or carry if
	space */
hg_input:
	xor a
	ld (hg_len),a
	ld (hg_shown),a						; (messages seen by now)
.show:
	ld hl,hg_buf
	ld a,(hg_len)
	add hl,a
	ld (hl),0
	ld hl,(hg_field)					; the question, then what's typed
	ld de,hg_buf
.copy:
	ld a,(de)
	ld (hl),a
	inc hl
	inc de
	or a
	jr nz,.copy
	dec hl
	ld (hl),'_'
	inc hl
	ld (hl),0
	ld d,STORE_PROMPT_ROW
	call clear_row
	ld hl,msg_buf
	ld d,STORE_PROMPT_ROW
	ld e,2
	ld c,ATTR_YELLOW
	call print_at
	call read_ascii
	cp ' '
	scf
	ret z
	cp 13
	jr z,.enter
	cp 8
	jr z,.delete
	ld e,a
	ld a,(ascii_sym)					; Symbol Shift + K, J: + and -
	and %00000010
	ld a,e
	jr z,.digit
	cp 'k'
	ld a,'+'
	jr z,.sign
	ld a,e
	cp 'j'
	ld a,'-'
	jr nz,.show
.sign:
	ld e,a
	ld a,(hg_len)						; (first only)
	or a
	jr nz,.show
	jr .put
.digit:
	cp '0'
	jr c,.show
	cp '9'+1
	jr nc,.show
.put:
	ld a,(hg_len)
	cp 6
	jr nc,.show
	ld hl,hg_buf
	add hl,a
	ld (hl),e
	inc a
	ld (hg_len),a
	jr .show
.delete:
	ld a,(hg_len)
	or a
	jr z,.show
	dec a
	ld (hg_len),a
	jp .show
.enter:
	ld hl,hg_buf
	ld a,(hg_len)
	add hl,a
	ld (hl),0
	or a
	ret

; ---------------------------------------------------------------- the screen

/* hg_commands - HL = "Specify an offer in gold pieces.": on the command
	row, with how to quit (haggle_commands) */
hg_commands:
	push hl
	ld d,STORE_CMD_ROW
	call clear_row
	pop hl
	ld d,STORE_CMD_ROW
	ld e,2
	ld c,ATTR_GREY
	call print_at
	ld hl,txt_quit_haggling
	ld c,ATTR_GREY
	jp print_str

/* hg_show_asking - "Asking :  250" (or "Offer", "Final Offer") on the left
	of the asking row */
hg_show_asking:
	call msg_begin
	ld hl,(hg_comment)
	call msg_add
	ld hl,txt_colon
	call msg_add
	ld hl,hg_cur
	call msg_add_u16
.pad:									; (out to column 40)
	ld hl,(msg_ptr)
	ld de,msg_buf+38
	or a
	sbc hl,de
	jr nc,.padded
	ld a,' '
	call hg_char
	jr .pad
.padded:
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld d,ASK_ROW
	ld e,2
	ld c,ATTR_WHITE
	jp print_at

/* hg_show_last - HL = "Your last offer : ": with (hg_last), on the right
	of the asking row */
hg_show_last:
	push hl
	ld d,ASK_ROW
	call clear_row
	call msg_begin
	pop hl
	call msg_add
	ld hl,hg_last
	call msg_add_u16
	ld hl,(msg_ptr)
	ld (hl),0
	ld hl,msg_buf
	ld d,ASK_ROW
	ld e,41
	ld c,ATTR_GREY
	jp print_at

/* hg_comment_n - HL = a list of A comments: one at random, its \1 the
	offer (hg_a1), \2 the asking price (hg_a2) */
hg_comment_n:
	push hl
	call randint
	dec a
	pop hl
	call hg_pick
/* hg_say - HL = a message (\1, \2 filled in): on the store's message row;
	if one's there not yet seen, "-more-" and a key first */
hg_say:
	push hl
	ld a,(hg_shown)
	or a
	jr z,.fresh
	ld hl,txt_more
	ld d,STORE_MSG_ROW
	ld e,70
	ld c,ATTR_GREY
	call print_at
	call read_ascii
.fresh:
	call msg_begin
	pop hl
.char:
	ld a,(hl)
	inc hl
	or a
	jr z,.said
	cp 3
	jr nc,.plain
	push hl
	ld hl,hg_a1
	dec a
	jr z,$+5
	ld hl,hg_a2
	call msg_add_u16
	pop hl
	jr .char
.plain:
	call hg_char
	jr .char
.said:
	ld hl,(msg_ptr)
	ld (hl),0
	ld d,STORE_MSG_ROW
	call clear_row
	ld hl,msg_buf
	ld d,STORE_MSG_ROW
	ld e,2
	ld c,ATTR_YELLOW
	call print_at
	ld a,1
	ld (hg_shown),a
	ret

/* hg_char - A added to the message. Preserves HL */
hg_char:
	push hl
	ld hl,(msg_ptr)
	ld (hl),a
	inc hl
	ld (msg_ptr),hl
	pop hl
	ret

/* hg_pick - HL = a list of messages, A = which -> HL = it */
hg_pick:
	or a
	ret z
	ld b,a
.skip:
	push bc
	xor a
	ld bc,0
	cpir
	pop bc
	djnz .skip
	ret

/* hg_accepted - "Done!", "Accepted!"... (comment1), after a deal */
hg_accepted:
	ld a,14
	call randint
	dec a
	ld hl,comment1
	call hg_pick
	jp hg_say

/* hg_liar - "Liar!  You have not the gold!", or thrown out -> carry if out */
hg_liar:
	call increase_insults
	ret c
	call hg_accepted
	ld hl,txt_liar
	call hg_say
	or a
	ret

/* hg_worthless - "How dare you!" "I will not buy that!" -> carry if that
	was one insult too many */
hg_worthless:
	push af
	ld hl,txt_how_dare
	call hg_say
	ld hl,txt_wont_buy
	call hg_say
	pop af
	jp increase_insults

/* hg_reaction - HL = what the item sold is worth now it's known, DE =
	what it seemed worth: the shopkeeper's reaction (store_sell) */
hg_reaction:
	ld (hg_real),hl
	ld a,h
	or l
	ld b,4
	ld hl,react_fool					; worth nothing
	jr z,.say
	ld a,h								; (HL again)
	ld (hg_t),de
	ld hl,(hg_real)
	or a
	sbc hl,de
	ret z								; the same: nothing said
	ld b,3
	ld hl,react_cheated					; worth less
	jr c,.say
	ld hl,(hg_t)						; more than 4 x: joy
	ld a,h
	cp $40
	jr nc,.glad							; (4 x would be too big to beat)
	add hl,hl
	add hl,hl
	ex de,hl
	ld hl,(hg_real)
	or a
	sbc hl,de
	ld b,4
	ld hl,react_joy
	jr z,.glad
	jr nc,.say
.glad:
	ld b,4
	ld hl,react_glad					; more
.say:
	ld a,b
	push hl
	call randint
	dec a
	pop hl
	call hg_pick
	jp hg_say

/* mul16_8 - HL * A -> E:HL */
mul16_8:
	ld e,l
	ld d,a
	mul d,e
	push de
	ld e,h
	ld d,a
	mul d,e								; DE = H * A
	pop hl
	ld a,h
	add a,e
	ld h,a
	ld a,d
	adc a,0
	ld e,a
	ret

/* div24_16 - E:HL / BC -> HL = quotient (to 65535) */
div24_16:
	ld a,b
	or c
	jr nz,.go
	ld hl,$FFFF
	ret
.go:
	ld (hg_d),bc
	ld a,e								; A:HL the dividend, DE the remainder
	ld de,0
	ld b,24
.bit:
	add hl,hl
	rla
	ex de,hl
	adc hl,hl
	push bc
	ld bc,(hg_d)
	and a
	sbc hl,bc
	jr nc,.fits
	add hl,bc
	pop bc
	ex de,hl
	jr .next
.fits:
	pop bc
	ex de,hl
	inc l
.next:
	djnz .bit
	or a
	ret z
	ld hl,$FFFF
	ret

; ---------------------------------------------------------------- words

txt_locked:		db "The doors are locked.",0
txt_offer_cmd:	db "Specify an offer in gold pieces.  ",0
txt_ask_cmd:	db "Specify an asking-price in gold pieces.  ",0
txt_quit_haggling: db "Space) Quit Haggling.",0
txt_asking:		db "Asking",0
txt_offer_word:	db "Offer",0
txt_final_offer: db "Final Offer",0
txt_colon:		db " :  ",0
txt_last_offer:	db "Your last offer : ",0
txt_last_bid:	db "Your last bid ",0
txt_what_offer:	db "What do you offer? ",0
txt_what_price:	db "What price do you ask? ",0
txt_accept:		db "[accept] ",0
txt_close_sp:	db "] ",0
txt_first_offer: db "You haven't even made your first offer yet!",0
txt_long_session: db "After a long bargaining session, you agree upon the price.",0
txt_cant_afford: db "I am sorry, but I have not the money to afford such a fine item.",0
txt_liar:		db "Liar!  You have not the gold!",0
txt_how_dare:	db "How dare you!",0
txt_wont_buy:	db "I will not buy that!",0

; chr_adj() in MISC2.C as (charisma below this, percent) pairs
chr_table:
	db 4,130, 5,125, 6,122, 7,120, 8,118, 9,116, 10,114, 11,112, 12,110
	db 13,108, 14,106, 15,104, 16,103, 17,102, 18,101, 19,100, 68,98
	db 88,96, 108,94, 118,92, 148,90, 188,88, 218,86, 255,80

comment1:
	db "Done!",0, "Accepted!",0, "Fine.",0, "Agreed!",0, "Ok.",0, "Taken!",0
	db "You drive a hard bargain, but taken.",0
	db "You'll force me bankrupt, but it's a deal.",0, "Sigh.  I'll take it.",0
	db "My poor sick children may starve, but done!",0, "Finally!  I accept.",0
	db "Robbed again.",0, "A pleasure to do business with you!",0
	db "My spouse will skin me, but accepted.",0
comment2a:
	db 2," is my final offer; take it or leave it.",0
	db "I'll give you no more than ",2,".",0
	db "My patience grows thin.  ",2," is final.",0
comment2b:
	db 1," for such a fine item?  HA!  No less than ",2,".",0
	db 1," is an insult!  Try ",2," gold pieces.",0
	db 1,"?!?  Go try Londis instead!",0
	db "Why, I'll take no less than ",2," gold pieces.",0
	db "Ha!  No less than ",2," gold pieces.",0
	db "Thou knave!  No less than ",2," gold pieces.",0
	db 1," is far too little, how about ",2,"?",0
	db "I paid more than ",1," for it myself, try ",2,".",0
	db 1," my arse!  How about ",2," gold pieces?",0
	db "As scrap this would bring ",1,".  Try ",2," in gold.",0
	db "May the fleas of 1000 orcs molest you.  I want ",2,".",0
	db "My mother you can get for ",1,", this costs ",2,".",0
	db "May your most favourite parts go mouldy!  I want ",2," in gold!",0
	db "Sell this for such a pittance?  Give me ",2," gold.",0
	db "May Morgoth find you tasty!  ",2," gold pieces?",0
	db "Your mother was a Troll/Orc/Elf!  ",2," or I'll tell.",0
comment3a:
	db "I'll pay no more than ",1,"; take it or leave it.",0
	db "You'll get no more than ",1," from me.",0
	db 1," and that's final.",0
comment3b:
	db 2," for that piece of junk?  No more than ",1,".",0
	db "For ",2," I could own ten of those.  Try ",1,".",0
	db 2,"?  NEVER!  ",1," is more like it.",0
	db "Let's be reasonable..NOT! How about ",1," gold pieces?",0
	db 1," gold for that! That's you, that is!.",0
	db 1," gold pieces and be thankful for it!",0
	db 1," gold pieces and not a copper more.",0
	db 2," gold?  HA!  ",1," is more like it.",0, "Try about ",1," gold.",0
	db "I wouldn't pay ",2," for your bottom, try ",1,".",0
	db "*CHOKE* For that!?  Let's say ",1,".",0, "How about ",1,"?",0
	db "That looks war surplus!  Say ",1," gold.",0
	db "I'll buy it as scrap for ",1,".",0
	db 2," is too much, let us say ",1," gold.",0
comment4a:
	db "ENOUGH!  You have abused me once too often!",0
	db "THAT DOES IT!  You shall waste my time no more!",0
	db "This is getting nowhere.  I'm going to Londis!",0
	db "BAHAHAHAHAHA!  No more shall you insult me!",0
	db "Begone!  I have had enough abuse for one day.",0
comment4b:
	db "Out of my place!",0, "out... Out... OUT!!!",0, "Come back tomorrow.",0
	db "Leave my place.  Begone!",0, "Come back when thou art richer.",0
comment5:
	db "You will have to do better than that!",0, "That's an insult!",0
	db "Do you wish to do business or not?",0, "Hah!  Try again.",0
	db "Ridiculous!",0, "You've got to be kidding!",0, "You'd better be kidding!",0
	db "You try my patience.",0, "I don't hear you.",0
	db "Hmmm, nice weather we're having.",0
comment6:
	db "I must have heard you wrong.",0, "What was that?",0
	db "I'm sorry, say that again.",0, "What did you say?",0
	db "Sorry, what was that again?",0
react_fool:								; sold for nothing
	db "You hear a shriek!",0, "You bastard!",0
	db "You hear sobs coming from the back of the store...",0, "Arrgghh!!!!",0
react_cheated:							; worth less than it seemed
	db "You hear someone swearing...",0, "You hear mumbled curses...",0
	db "The shopkeeper glares at you.",0
react_joy:								; worth over 4 x
	db "You hear someone jumping for joy!",0, "Yipee!",0, "I think I'll retire!",0
	db "The shopkeeper smiles gleefully!",0
react_glad:								; worth more
	db "You hear someone giggling",0, "You've made my day!",0, "What a fool!",0
	db "The shopkeeper laughs loudly!",0

; ---------------------------------------------------------------- workspace

; what store.asm sets (HGSET)
hg_store:		db 0
hg_per:			db 0				; the owner's haggle step
hg_insult_max:	db 0				; and patience
hg_ask:			dw 0				; their first price
hg_final:		dw 0				; their last
hg_least:		dw 0				; the far end of yours
hg_purse:		dw 0				; (selling: what they can pay)
hg_said:		db 0				; a message already on the message row
; and the haggling
hg_cur:			dw 0
hg_new:			dw 0
hg_last:		dw 0
hg_price:		dw 0
hg_last_inc:	dw 0				; (kept between haggles, as the C's)
hg_comment:		dw 0
hg_question:	dw 0
hg_field:		dw 0
hg_a1:			dw 0
hg_a2:			dw 0
hg_x:			dw 0
hg_max_per:		dw 0
hg_i:			dw 0
hg_t:			dw 0
hg_d:			dw 0
hg_real:		dw 0
hg_num:			db 0
hg_factor:		db 0
hg_final_flag:	db 0
hg_final_on:	db 0
hg_inc:			db 0
hg_sign:		db 0
hg_shown:		db 0
hg_len:			db 0
hg_buf:			ds 8
; each store's bargaining (saved)
hg_state:		ds NUM_STORES*HG_SIZE
hg_state_end:
