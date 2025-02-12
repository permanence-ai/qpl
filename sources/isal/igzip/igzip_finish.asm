;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copyright (C) 2022 Intel Corporation
;
; SPDX-License-Identifier: MIT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "options.asm"
%include "lz0a_const.asm"
%include "data_struct2.asm"
%include "bitbuf2.asm"
%include "huffman.asm"
%include "igzip_compare_types.asm"

%include "stdmac.asm"
%include "reg_sizes.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%define curr_data	rax
%define tmp1		rax

%define f_index		rbx
%define code		rbx
%define tmp4		rbx
%define tmp5		rbx
%define tmp6		rbx

%define tmp2		rcx
%define hash		rcx

%define tmp3		rdx

%define stream		rsi

%define f_i		rdi

%define code_len2	rbp
%define hmask1		rbp

%define m_out_buf	r8

%define m_bits		r9

%define dist		r10
%define hmask2		r10

%define m_bit_count	r11

%define code2		r12
%define f_end_i		r12

%define file_start	r13

%define len		r14

%define hufftables	r15

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
f_end_i_mem_offset	equ 0    ; local variable (8 bytes)
stack_size		equ 8

[bits 64]
default rel
section .text

; void qpl_isal_deflate_finish ( isal_zstream *stream )
; arg 1: rcx: addr of stream
%ifdef QPL_HIDE_ASM_SYMBOLS
global qpl_isal_deflate_finish_01:function hidden
%else
global qpl_isal_deflate_finish_01
%endif ; %ifdef QPL_HIDE_ASM_SYMBOLS
qpl_isal_deflate_finish_01:
	endbranch
	PUSH_ALL	rbx, rsi, rdi, rbp, r12, r13, r14, r15
	sub	rsp, stack_size

%ifidn __OUTPUT_FORMAT__, elf64
	mov	rcx, rdi
%endif

	mov	stream, rcx

	; state->bitbuf.set_buf(stream->next_out, stream->avail_out);
	mov	m_out_buf, [stream + _next_out]
	mov	[stream + _internal_state_bitbuf_m_out_start], m_out_buf
	mov	tmp1 %+ d, [stream + _avail_out]
	add	tmp1, m_out_buf
	sub	tmp1, SLOP
skip_SLOP:
	mov	[stream + _internal_state_bitbuf_m_out_end], tmp1

	mov	m_bits,           [stream + _internal_state_bitbuf_m_bits]
	mov	m_bit_count %+ d, [stream + _internal_state_bitbuf_m_bit_count]

	mov	hufftables, [stream + _hufftables]

	mov	file_start, [stream + _next_in]

	mov	f_i %+ d, dword [stream + _total_in]
	sub	file_start, f_i

	mov	f_end_i %+ d, dword [stream + _avail_in]
	add	f_end_i, f_i

	sub	f_end_i, LAST_BYTES_COUNT
	mov	[rsp + f_end_i_mem_offset], f_end_i
	; for (f_i = f_start_i; f_i < f_end_i; f_i++) {
	cmp	f_i, f_end_i
	jge	end_loop_2

	mov	curr_data %+ d, [file_start + f_i]

	cmp	byte [stream + _internal_state_has_hist], IGZIP_NO_HIST
	jne	skip_write_first_byte

	cmp	m_out_buf, [stream + _internal_state_bitbuf_m_out_end]
	ja	end_loop_2
	mov	hmask1 %+ d, dword [stream + _internal_state_hash_mask]
	compute_hash	hash, curr_data
	and	hash %+ d, hmask1 %+ d
	mov	[stream + _internal_state_head + 2 * hash], f_i %+ w
	mov	byte [stream + _internal_state_has_hist], IGZIP_HIST
	jmp	encode_literal

skip_write_first_byte:

loop2:
	mov     tmp3 %+ d, dword [stream + _internal_state_dist_mask]
	mov	hmask1 %+ d,  dword [stream + _internal_state_hash_mask]
	; if (state->bitbuf.is_full()) {
	cmp	m_out_buf, [stream + _internal_state_bitbuf_m_out_end]
	ja	end_loop_2

	; hash = compute_hash(state->file_start + f_i) & hash_mask;
	mov	curr_data %+ d, [file_start + f_i]
	compute_hash	hash, curr_data
	and	hash %+ d, hmask1 %+ d

	; f_index = state->head[hash];
	movzx	f_index %+ d, word [stream + _internal_state_head + 2 * hash]

	; state->head[hash] = (uint16_t) f_i;
	mov	[stream + _internal_state_head + 2 * hash], f_i %+ w

	; dist = f_i - f_index; // mod 64k
	mov	dist %+ d, f_i %+ d
	sub	dist %+ d, f_index %+ d
	and	dist %+ d, 0xFFFF

%ifdef QPL_LIB
	; Compare dist with max_dist
	cmp	dist %+ d, [stream + _internal_state_max_dist]
	jae	encode_literal
%endif

	; if ((dist-1) <= (D-1)) {
	mov	tmp1 %+ d, dist %+ d
	sub	tmp1 %+ d, 1
	cmp	tmp1 %+ d, tmp3 %+ d
	jae	encode_literal

	; len = f_end_i - f_i;
	mov	tmp4, [rsp + f_end_i_mem_offset]
	sub	tmp4, f_i
	add	tmp4, LAST_BYTES_COUNT

	; if (len > 258) len = 258;
	cmp	tmp4, 258
	cmovg	tmp4, [c258]

	; len = compare(state->file_start + f_i,
	;               state->file_start + f_i - dist, len);
	lea	tmp1, [file_start + f_i]
	mov	tmp2, tmp1
	sub	tmp2, dist
	compare	tmp4, tmp1, tmp2, len, tmp3

%ifdef QPL_LIB
len_computed:
	; Limit len to the end of current mini-block
	mov	tmp4 %+ d, [stream + _internal_state_mb_mask]
	sub	tmp4 %+ d, [stream + _internal_state_max_dist]
	cmp	len, tmp4
	cmovg	len, tmp4
%endif

	; if (len >= SHORTEST_MATCH) {
	cmp	len, SHORTEST_MATCH
	jb	encode_literal

	;; encode as dist/len

	; get_dist_code(dist, &code2, &code_len2);
	dec	dist
	get_dist_code	dist, code2, code_len2, hufftables ;; clobbers dist, rcx

	; get_len_code(len, &code, &code_len);
	get_len_code	len, code, rcx, hufftables	;; rcx is code_len

	mov	hmask2 %+ d,  dword [stream + _internal_state_hash_mask]
	; code2 <<= code_len
	; code2 |= code
	; code_len2 += code_len
	SHLX	code2, code2, rcx
	or	code2, code
	add	code_len2, rcx

	; for (k = f_i+1, f_i += len-1; k <= f_i; k++) {
	lea	tmp3, [f_i + 1]	; tmp3 <= k
	add	f_i, len

%ifdef QPL_LIB
        mov     tmp6 %+ d, [stream + _internal_state_max_dist]
        add     tmp6, len
        and     tmp6 %+ d, [stream + _internal_state_mb_mask]
        mov     [stream + _internal_state_max_dist], tmp6 %+ d
%endif

	cmp	f_i, [rsp + f_end_i_mem_offset]
	jae	skip_hash_update

	; only update hash twice

	; hash = compute_hash(state->file_start + k) & hash_mask;
	mov	tmp6 %+ d, dword [file_start + tmp3]
	compute_hash	hash, tmp6
	and	hash %+ d, hmask2 %+ d
	; state->head[hash] = k;
	mov	[stream + _internal_state_head + 2 * hash], tmp3 %+ w

	add	tmp3, 1

	; hash = compute_hash(state->file_start + k) & hash_mask;
	mov	tmp6 %+ d, dword [file_start + tmp3]
	compute_hash	hash, tmp6
	and	hash %+ d, hmask2 %+ d
	; state->head[hash] = k;
	mov	[stream + _internal_state_head + 2 * hash], tmp3 %+ w

skip_hash_update:
	write_bits	m_bits, m_bit_count, code2, code_len2, m_out_buf

	; continue
	cmp	f_i, [rsp + f_end_i_mem_offset]
	jl	loop2
	jmp	end_loop_2

encode_literal:
	; get_lit_code(state->file_start[f_i], &code2, &code_len2);
	movzx	tmp5, byte [file_start + f_i]
	get_lit_code	tmp5, code2, code_len2, hufftables

	write_bits	m_bits, m_bit_count, code2, code_len2, m_out_buf

	; continue
	add	f_i, 1
%ifdef QPL_LIB
        mov     tmp3 %+ d, [stream + _internal_state_max_dist]
        add     tmp3, 1
        and     tmp3 %+ d, [stream + _internal_state_mb_mask]
        mov     [stream + _internal_state_max_dist], tmp3 %+ d
%endif
	cmp	f_i, [rsp + f_end_i_mem_offset]
	jl	loop2

end_loop_2:
	mov	f_end_i, [rsp + f_end_i_mem_offset]
	add	f_end_i, LAST_BYTES_COUNT
	mov	[rsp + f_end_i_mem_offset], f_end_i
	; if ((f_i >= f_end_i) && ! state->bitbuf.is_full()) {
	cmp	f_i, f_end_i
	jge	write_eob

	xor	tmp5, tmp5
final_bytes:
	cmp	m_out_buf, [stream + _internal_state_bitbuf_m_out_end]
	ja	not_end
	movzx	tmp5, byte [file_start + f_i]
	get_lit_code	tmp5, code2, code_len2, hufftables
	write_bits	m_bits, m_bit_count, code2, code_len2, m_out_buf

	inc	f_i
	cmp	f_i, [rsp + f_end_i_mem_offset]
	jl	final_bytes

write_eob:
	cmp	m_out_buf, [stream + _internal_state_bitbuf_m_out_end]
	ja	not_end

%ifdef QPL_LIB
	cmp word [stream + _flush], _QPL_PARTIAL_FLUSH
	jne write_eob_1
	mov	dword [stream + _internal_state_state], ZSTATE_BODY
	jmp not_end
write_eob_1:
%endif

	;	get_lit_code(256, &code2, &code_len2);
	get_lit_code	256, code2, code_len2, hufftables

	write_bits	m_bits, m_bit_count, code2, code_len2, m_out_buf

	mov	byte [stream + _internal_state_has_eob], 1
	cmp	word [stream + _end_of_stream], 1
	jne	sync_flush
	;	   state->state = ZSTATE_TRL;
	mov	dword [stream + _internal_state_state], ZSTATE_TRL
	jmp	not_end

sync_flush:
	;	   state->state = ZSTATE_SYNC_FLUSH;
	mov	dword [stream + _internal_state_state], ZSTATE_SYNC_FLUSH
	;    }
not_end:


	;; Update input buffer
	mov	f_end_i, [rsp + f_end_i_mem_offset]
	mov	[stream + _total_in], f_i %+ d
	add	file_start, f_i
	mov	[stream + _next_in], file_start
	sub	f_end_i, f_i
	mov	[stream + _avail_in], f_end_i %+ d

	;; Update output buffer
	mov	[stream + _next_out], m_out_buf
	;    len = state->bitbuf.buffer_used();
	sub	m_out_buf, [stream + _internal_state_bitbuf_m_out_start]

	;    stream->avail_out -= len;
	sub	[stream + _avail_out], m_out_buf %+ d
	;    stream->total_out += len;
	add	[stream + _total_out], m_out_buf %+ d

	mov	[stream + _internal_state_bitbuf_m_bits], m_bits
	mov	[stream + _internal_state_bitbuf_m_bit_count], m_bit_count %+ d
	add	rsp, stack_size
	POP_ALL
	ret

section .data
	align 4
c258:	dq	258
