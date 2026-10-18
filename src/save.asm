/* save.asm - saving and restoring the game (overlay page PAGE_SAVE)
	References: DUNGEON.C's ^X ("Saving game..."), SAVE.C save_char /
	get_char, DEATH.C. The game is saved to roguelike.sav on the SD card
	with the esxDOS calls (RST $08) that NextZXOS provides: the character,
	what it knows, the level it's on, the stores, and this game's flavours.
	A save is checked against the sizes of the blocks it holds, so a later
	build reads it as long as none of them changed shape.
	Pressing a key at the title restores it; dying deletes it (the C keeps
	a dead character's file, and starts a new character from it).
 */

; esxDOS calls (RST $08, then the call number)
F_OPEN				equ $9A
F_CLOSE				equ $9B
F_READ				equ $9D
F_WRITE				equ $9E
F_UNLINK			equ $AD
FA_READ				equ $01
FA_WRITE			equ $02
FA_CREATE_AL		equ $0C				; create, or truncate what's there
ESX_DRIVE			equ "*"				; the current drive
SAVE_VERSION		equ 1

; what is saved: (page shown at $6000 while it's read or written, or 0 for
; none; address; length). Overlay and data pages are seen through slot 3.
	MACRO SV_BLOCK page, addr, len
		db page
		dw addr, len
	ENDM
save_blocks:
	SV_BLOCK 0, p_lev, w_slays+2-p_lev					; the character
	SV_BLOCK 0, p_stat_max, p_stat_use+6-p_stat_max		; stats, flags, speed
	SV_BLOCK 0, p_status, 2
	SV_BLOCK 0, p_timed, p_confuse_mon+2-p_timed		; timed effects
	SV_BLOCK 0, dun_level, 5							; level, place, view
	SV_BLOCK 0, game_turn, 2
	SV_BLOCK 0, town_seed, 3							; the town, and its night
	SV_BLOCK 0, KNOWLEDGE, KNOWLEDGE_END-KNOWLEDGE		; what's known of things
	SV_BLOCK 0, MON_LIST, HIGH_RAM_END-MON_LIST		; monsters, items, pack,
														; spells, uniques...
	SV_BLOCK 0, MAP_BASE, MAP_W*MAP_H					; the level
	SV_BLOCK PAGE_STORE, store_inv+$2000, NUM_STORES*STORE_INVEN_MAX*STORE_ITEM
	SV_BLOCK PAGE_MISC, art_made+$2000, (NUM_ART_BITS+7)/8	; artifacts made
	SV_BLOCK FLAVOUR_PAGE, scroll_titles+$4000, MAX_TITLES*10
SAVE_BLOCKS			equ ($-save_blocks)/5

; the file: "RLSV", the version, each block's length, then the blocks
save_magic:		db "RLSV", SAVE_VERSION
save_name:		db "roguelike.sav",0
dead_magic:		db "DEAD!"

/* save_game - ^X (Symbol Shift + X): "Saving game..." and save it ->
	carry if saved (the caller then quits to the title), else "Save
	failed..." */
save_game:
	ld hl,sv_saving
	call msg_print
	call esx_begin
	ld b,FA_WRITE|FA_CREATE_AL
	call sv_open
	jr c,.failed
	ld (sv_handle),a
	ld hl,save_magic
	ld bc,5
	call sv_write
	jr c,.close_failed
	ld ix,save_blocks					; the lengths
	ld b,SAVE_BLOCKS
.length:
	push bc
	push ix
	pop hl
	inc hl
	inc hl
	inc hl
	ld bc,2
	call sv_write
	pop bc
	jr c,.close_failed
	ld de,5
	add ix,de
	djnz .length
	ld ix,save_blocks					; the blocks
	ld b,SAVE_BLOCKS
.block:
	push bc
	call sv_page
	ld l,(ix+1)
	ld h,(ix+2)
	ld c,(ix+3)
	ld b,(ix+4)
	call sv_write
	nextreg NR_MMU3,PAGE_SCREEN_HI
	pop bc
	jr c,.close_failed
	ld de,5
	add ix,de
	djnz .block
	call sv_close
	jr c,.failed
	call esx_end
	scf
	ret
.close_failed:
	call sv_close
.failed:
	call esx_end
	ld hl,sv_failed
	call msg_print
	or a
	ret

/* load_game - at the title: a saved game is restored if there is one
	(and it fits this build) -> carry if it was */
load_game:
	call esx_begin
	ld b,FA_READ
	call sv_open
	jp c,.none
	ld (sv_handle),a
	ld hl,sv_buf						; "RLSV", the version
	ld bc,5
	call sv_read
	jr nc,.header
	ld a,b								; empty: no save
	or c
	jp nz,.wrong
.dead:
	call sv_close
	jp .none
.header:
	ld hl,sv_buf						; a dead character's: no save
	ld de,dead_magic
	ld b,5
.is_dead:
	ld a,(de)
	cp (hl)
	jr nz,.alive
	inc hl
	inc de
	djnz .is_dead
	jr .dead
.alive:
	ld hl,sv_buf
	ld de,save_magic
	ld b,5
.magic:
	ld a,(de)
	cp (hl)
	jp nz,.wrong
	inc hl
	inc de
	djnz .magic
	ld ix,save_blocks					; every block the size it should be
	ld b,SAVE_BLOCKS
.length:
	push bc
	ld hl,sv_buf
	ld bc,2
	call sv_read
	pop bc
	jp c,.wrong
	ld hl,(sv_buf)
	ld e,(ix+3)
	ld d,(ix+4)
	or a
	sbc hl,de
	jp nz,.wrong
	ld de,5
	add ix,de
	djnz .length
	ld ix,save_blocks					; then the blocks themselves
	ld b,SAVE_BLOCKS
.block:
	push bc
	call sv_page
	ld l,(ix+1)
	ld h,(ix+2)
	ld c,(ix+3)
	ld b,(ix+4)
	call sv_read
	nextreg NR_MMU3,PAGE_SCREEN_HI
	pop bc
	jr c,.broken
	ld de,5
	add ix,de
	djnz .block
	call sv_close
	call esx_end
	ld hl,p_update						; the bonuses, worked out afresh
	ld a,(hl)
	or 1<<PU_BONUS|1<<PU_HP|1<<PU_SPELLS
	ld (hl),a
	scf
	ret
.wrong:									; another build's: left alone
	call sv_close
	call esx_end
	ld hl,sv_other_version
	call show_message
	call wait_any_key
	or a
	ret
.broken:								; cut short: what was read is
	call sv_close						; half a game, so start afresh
	call esx_end
	ld hl,sv_broken
	call show_message
	call wait_any_key
	or a
	ret
.none:
	call esx_end
	or a
	ret

/* delete_save - the character has died: its save goes (and if the file
	is still there after all, it's marked dead, which counts as no save) */
delete_save:
	call esx_begin
	push ix
	ld a,ESX_DRIVE
	ld ix,save_name						; (programs pass addresses in IX,
	ld hl,save_name						;  dot commands in HL)
	rst $08
	db F_UNLINK
	pop ix
	ld b,FA_READ						; gone?
	call sv_open
	jr c,.done
	ld (sv_handle),a
	call sv_close
	ld b,FA_WRITE|FA_CREATE_AL
	call sv_open
	jr c,.done
	ld (sv_handle),a
	ld hl,dead_magic
	ld bc,5
	call sv_write
	call sv_close
.done:
	jp esx_end

/* esx_begin, esx_end - interrupts off and the ROM in both low slots while
	esxDOS is called (its divMMC memory appears at $0000-$3FFF); and back */
esx_begin:
	di
	nextreg NR_MMU1,$FF
	ret
esx_end:
	ei
	ret

/* sv_page - IX = a block: its page shown at $6000, if it has one */
sv_page:
	ld a,(ix+0)
	or a
	ret z
	nextreg NR_MMU3,a
	ret

/* sv_open - B = mode: roguelike.sav -> A = handle, carry on an error.
	(esxDOS takes addresses in IX from a program, in HL from a dot
	command: both are set) */
sv_open:
	push ix
	ld a,ESX_DRIVE
	ld ix,save_name
	ld hl,save_name
	rst $08
	db F_OPEN
	pop ix
	ret

/* sv_write, sv_read - HL = address, BC = length -> carry on an error.
	Preserve IX */
sv_write:
	push ix
	push hl
	pop ix
	ld a,(sv_handle)
	rst $08
	db F_WRITE
	pop ix
	ret
sv_read:
	push ix
	push bc
	push hl
	pop ix
	ld a,(sv_handle)
	rst $08
	db F_READ
	pop hl								; all of it?
	pop ix
	ret c
	or a
	sbc hl,bc
	ret z
	scf
	ret
sv_close:
	push ix
	ld a,(sv_handle)
	rst $08
	db F_CLOSE
	pop ix
	ret

sv_saving:			db "Saving game...",0
sv_failed:			db "Save failed...",0
sv_other_version:	db "Your saved game is from another version. Press any key.",0
sv_broken:			db "Your saved game is damaged. Press any key.",0
sv_handle:			db 0
sv_buf:				ds 8
