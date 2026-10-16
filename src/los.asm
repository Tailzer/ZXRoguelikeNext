/* los.asm - line of sight
	Port of los() from MISC1.C (Joseph Hall's integer algorithm): walks
	the line from the player to the target along its longer axis, keeping
	the fractional position on the other axis scaled by 2*|dx*dy|, and
	fails if any square on the way (not the ends) blocks sight.
	Only called for targets within MAX_SIGHT, so all deltas fit a byte.
 */

/* los - D = target y, E = target x -> carry set if the player can see it.
	Clobbers everything except IX, IY */
los:
	ld a,d
	ld (los_ty),a
	ld a,e
	ld (los_tx),a
	ld a,(player_y)
	ld b,a
	ld a,d
	sub b
	ld (los_dy),a
	ld a,(player_x)
	ld b,a
	ld a,e
	sub b
	ld (los_dx),a

	inc a								; adjacent (or same square)?
	cp 3
	jr nc,.far
	ld a,(los_dy)
	inc a
	cp 3
	jr nc,.far
	scf
	ret
.far:
	ld a,(los_dx)
	or a
	jp z,.vertical
	ld a,(los_dy)
	or a
	jp z,.horizontal

	ld a,(los_dx)
	call sign_abs
	ld (los_adx),a
	ld a,b
	ld (los_xs),a
	ld a,(los_dy)
	call sign_abs
	ld (los_ady),a
	ld a,b
	ld (los_ys),a

	ld a,(los_adx)						; scale2 = |dx*dy|, scale = 2*scale2
	ld d,a
	ld a,(los_ady)
	ld e,a
	mul d,e
	ld (los_scale2),de
	ex de,hl
	add hl,hl
	ld (los_scale),hl

	ld a,(los_adx)
	ld b,a
	ld a,(los_ady)
	cp b
	jr z,.x_major
	jr c,.x_major						; |dx| >= |dy|
.y_major:
	ld a,1
	ld (los_ymajor),a
	ld a,(los_ys)
	ld (los_as),a
	ld b,a
	ld a,(player_y)
	add a,b
	ld (los_a),a
	ld a,(los_ty)
	ld (los_at),a
	ld a,(player_x)
	ld (los_b),a
	ld a,(los_xs)
	ld (los_bs),a
	ld a,(los_adx)
	jr .fraction
.x_major:
	xor a
	ld (los_ymajor),a
	ld a,(los_xs)
	ld (los_as),a
	ld b,a
	ld a,(player_x)
	add a,b
	ld (los_a),a
	ld a,(los_tx)
	ld (los_at),a
	ld a,(player_y)
	ld (los_b),a
	ld a,(los_ys)
	ld (los_bs),a
	ld a,(los_ady)
.fraction:								; frac = minor^2, m = 2*frac
	ld d,a
	ld e,a
	mul d,e
	ld (los_frac),de
	ex de,hl
	add hl,hl
	ld (los_m),hl
	ld hl,(los_frac)					; slope exactly 1: start on the diagonal
	ld de,(los_scale2)
	or a
	sbc hl,de
	jr nz,.loop
	call .step_b
	call .sub_scale
.loop:
	ld a,(los_at)
	ld b,a
	ld a,(los_a)
	cp b
	jr z,.clear
	call .blocked
	jr c,.no
	ld hl,(los_frac)
	ld de,(los_m)
	add hl,de
	ld (los_frac),hl
	ld de,(los_scale2)
	or a
	sbc hl,de
	jr z,.corner
	jp m,.less
	call .step_b						; crossed into the next minor row
	call .blocked
	jr c,.no
	call .step_a
	call .sub_scale
	jr .loop
.less:
	call .step_a
	jr .loop
.corner:								; line passes exactly through a corner
	call .step_a
	call .step_b
	call .sub_scale
	jr .loop
.clear:
	scf
	ret
.no:
	or a
	ret

.step_a:
	ld a,(los_as)
	ld hl,los_a
	add a,(hl)
	ld (hl),a
	ret
.step_b:
	ld a,(los_bs)
	ld hl,los_b
	add a,(hl)
	ld (hl),a
	ret
.sub_scale:
	ld hl,(los_frac)
	ld de,(los_scale)
	or a
	sbc hl,de
	ld (los_frac),hl
	ret
.blocked:								; square (a, b) in y/x order
	ld a,(los_ymajor)
	or a
	ld a,(los_a)
	jr nz,.a_is_y
	ld e,a
	ld a,(los_b)
	ld d,a
	jp los_blocked
.a_is_y:
	ld d,a
	ld a,(los_b)
	ld e,a
	jp los_blocked

.vertical:								; same column
	ld a,(player_x)
	ld e,a
	ld a,(player_y)
	ld b,a
	ld a,(los_ty)
	ld c,a
	cp b
	jr nc,.v_next
	ld c,b
	ld b,a								; B = top, C = bottom
.v_next:
	inc b
	ld a,b
	cp c
	jr z,.clear
	ld d,b
	call los_blocked
	jr c,.no
	jr .v_next

.horizontal:							; same row
	ld a,(player_y)
	ld d,a
	ld a,(player_x)
	ld b,a
	ld a,(los_tx)
	ld c,a
	cp b
	jr nc,.h_next
	ld c,b
	ld b,a								; B = left, C = right
.h_next:
	inc b
	ld a,b
	cp c
	jr z,.clear
	ld e,b
	call los_blocked
	jr c,.no
	jr .h_next

/* los_blocked - D = y, E = x -> carry if the square blocks sight
	(walls, closed and secret doors). Preserves BC, DE */
los_blocked:
	push de
	push hl
	call map_addr
	ld a,(hl)
	and TERRAIN_MASK
	call terrain_flags
	pop hl
	pop de
	bit TF_PASSABLE,a
	scf
	ret z
	or a
	ret

/* sign_abs - A = signed non-zero value -> A = |value|, B = +1 or -1 */
sign_abs:
	ld b,1
	or a
	ret p
	ld b,-1
	neg
	ret

los_ty:			db 0
los_tx:			db 0
los_dy:			db 0
los_dx:			db 0
los_ady:		db 0
los_adx:		db 0
los_ys:			db 0
los_xs:			db 0
los_ymajor:		db 0
los_a:			db 0				; position along the longer axis
los_as:			db 0
los_at:			db 0
los_b:			db 0				; position along the shorter axis
los_bs:			db 0
los_scale2:		dw 0
los_scale:		dw 0
los_frac:		dw 0
los_m:			dw 0
