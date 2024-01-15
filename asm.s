global _start

section .data
    ; bf code
    input_buffer:  times 0x1000 db 0x0
    cells:         times 0x1000 db 0x0
    file:           db "test.bf", 0x0

section .text

_start:
    ; save the pointer to the allocated memory
    push rbp
    mov rbp, rsp

    ; allocate 0x1000 bytes of memory
    ; mmap(NULL, 0x1000, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    mov rax, 0x9
    mov rdi, 0x0
    mov rsi, 0x10000
    mov rdx, 0x7
    mov r10, 0x22
    mov r8, 0xffffffff
    mov r9, 0x0
    syscall
    mov r10, rax
    
    ; open file 
    mov rax, 0x2
    mov rdi, file
    mov rsi, 0x0
    mov rdx, 0x0
    syscall

    ; input bf code
    mov rdi, rax
    mov rsi, input_buffer
    mov rdx, 0x1000
    mov rax, 0x0
    syscall

    ; compile the bf code
    mov rdx, r10
    mov r10, input_buffer
    call compile


    mov rbx, cells
    ; execute the compiled code
    call rdx
    
    ; exit 0
    mov rax, 0x3c
    mov rdi, 0x0
    syscall
    

compile:
    ; input buffer
    ; r10 = input_buffer
    ; rdx = location of the output buffer
    push rbp
    mov rbp, rsp

    mov rcx, 0x0 ; rcx = location of the output buffer
    mov r9, 0x0 ; rdx = location of the input buffer

    .loop:
        cmp byte [r10+r9], '>'
        je .emit_inc_ptr
        cmp byte [r10+r9], '<'
        je .emit_dec_ptr
        cmp byte [r10+r9], '+'
        je .emit_inc_val
        cmp byte [r10+r9], '-'
        je .emit_dec_val
        cmp byte [r10+r9], '.'
        je .emit_print
        cmp byte [r10+r9], ','
        je .emit_read
        cmp byte [r10+r9], '['
        je .emit_loop_start
        cmp byte [r10+r9], ']'
        je .emit_loop_end
        cmp byte [r10+r9], 0x0
        je .end
        jmp .incloop
    .incloop:
        inc r9
        jmp .loop
    .end:
        ; write a ret
        mov byte [rdx+rcx], 0xc3
        leave
        ret
    ; assemble the instruction
    .emit_inc_ptr:
        ; emit inc rbx
        mov rax, 0x1
        mov rsi, 0x3
        call emit_inc_reg
        add rcx, rax
        jmp .incloop
    .emit_dec_ptr:
        ; emit dec rbx
        mov rax, 0x1
        mov rsi, 0x3
        call emit_dec_reg
        add rcx, rax
        jmp .incloop
    .emit_inc_val:
        ; emit inc byte [rbx]
        mov rax, 0x1
        mov rsi, 0x3
        call emit_inc_val
        add rcx, rax
        jmp .incloop
    .emit_dec_val:
        ; emit dec byte [rbx]
        mov rax, 0x1
        mov rsi, 0x3
        call emit_dec_val
        add rcx, rax
        jmp .incloop
    .emit_print:
        ; emit mov rdi, 1
        mov rsi, 0x7
        mov rdi, 0x1
        call emit_mov_reg_int
        add rcx, rax
        ; emit mov rsi, [rbx]
        mov rsi, 0x6
        mov rdi, 0x3
        call emit_mov_reg_reg
        add rcx, rax
        ; emit mov rdx, 1
        mov rdi, 0x1
        mov rsi, 0x2
        call emit_mov_reg_int
        add rcx, rax
        ; emit mov rax, 1
        mov rdi, 0x1
        mov rsi, 0x0
        call emit_mov_reg_int
        add rcx, rax
        ; emit syscall
        call emit_syscall
        add rcx, rax
        jmp .incloop
    .emit_read:
        ; emit mov rdi, 0
        mov rsi, 0x7
        mov rdi, 0x0
        call emit_mov_reg_int
        add rcx, rax
        ; emit mov rsi, [rbx]
        mov rsi, 0x6
        mov rdi, 0x3
        call emit_mov_reg_reg
        add rcx, rax
        ; emit mov rdx, 1
        mov rdi, 0x1
        mov rsi, 0x2
        call emit_mov_reg_int
        add rcx, rax
        ; emit mov rax, 0
        mov rdi, 0x0
        mov rsi, 0x0
        call emit_mov_reg_int
        add rcx, rax
        ; emit syscall
        call emit_syscall
        add rcx, rax
        jmp .incloop
    .emit_loop_start:
        ; save the location of the output buffer
        ; loop_start:
        ; emit cmp byte [rbx], 0
        mov rsi, 0x3
        mov rdi, 0x0
        call emit_cmp_mem_int
        add rcx, rax
        ; emit je <offset>
        mov rdi, 0x0
        mov rsi, 0x3
        call emit_je
        ; save the location of the jne
        push rcx
        ; the offset will be filled in later
        add rcx, rax
        push rcx
        jmp .incloop
    .emit_loop_end:
        ; emit cmp byte [rbx], 0
        mov rsi, 0x3
        mov rdi, 0x0
        call emit_cmp_mem_int
        add rcx, rax
        ; emit jne <offset>
        mov rdi, 0x0
        mov rsi, 0x3
        pop r13 ; r13 = location of the loop start
        pop r12 ; r12 = location of the jne
        ; we have to jump to the location of the loop start
        ; loop_start - loop_end - sizeof(jmp)
        mov r14, rcx
        sub r14, r13
        add r14, 0x6 ; sizeof(jmp)
        ; two's complement
        not r14
        add r14, 0x1
        mov rdi, r14
        call emit_jne
        add rcx, rax
        ; fill in the offset for the jne which is at r12
        add r12, 2
        mov r14, rcx
        mov r13, r12
        add r13, 4
        sub r14, r13
        mov [rdx+r12], dword r14d
        jmp .incloop

emit_inc_reg:
; rdi = reg
; rsi = buffer
; rdx = location
; rax = returned length of the encoded instruction
; will assemble inc <reg>
    mov [rdx + rcx], byte 0xfe
    mov al, 0xc0
    or al, sil
    mov [rdx + rcx + 1], byte al
    mov rax, 2
    ret


emit_dec_reg:
; rdi = reg
; rsi = buffer
; rdx = location
; rax = returned length of the encoded instruction
; will assemble dec <reg>
; FE /1	DEC r/m8	M	Valid	Valid	Decrement r/m8 by 1.
    mov [rdx + rcx], byte 0xfe
    mov al, 0xc8
    or al, sil
    mov [rdx + rcx + 1], byte al
    mov rax, 2
    ret

emit_xor_reg:
    mov al, 0x48
    mov [rdx + rcx], byte al
    mov al, 0x33
    mov [rdx + rcx + 1], byte al
    ; modrm = 0xc0 | dst << 3 | src
    mov al, 0xc0
    or al, sil
    shl sil, 3
    or al, sil
    mov [rdx + rcx + 2], byte al
    mov rax, 3
    ret

emit_inc_val:
; rdi = reg
; rsi = buffer
; rdx = location
; rax = returned length of the encoded instruction
; will assemble inc byte [reg]
; REX + FE /0	INC r/m81	M	Valid	N.E.	Increment r/m byte by 1.
    mov [rdx + rcx], byte 0b01000000
    mov al, 0xfe
    mov [rdx + rcx + 1], byte al
    ; modrm = 0x00 | dst << 3 | src
    mov al, 0x00
    or al, sil
    mov [rdx + rcx + 2], byte al
    mov rax, 3
    ret


emit_dec_val:
; rdi = reg
; rsi = buffer
; rdx = location
; rax = returned length of the encoded instruction
; will assemble dec byte [reg]
; REX + FE /1	DEC r/m8*	M	Valid	N.E.	Decrement r/m8 by 1.
    mov [rdx + rcx], byte 0b01000000
    mov al, 0xfe
    mov [rdx + rcx + 1], byte al
    ; modrm = 0x08 | dst << 3 | src
    mov al, 0x08
    or al, sil
    mov [rdx + rcx + 2], byte al
    mov rax, 3
    ret

emit_mov_reg_int:
; rdi = int
; rsi = reg
; rdx = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble mov <reg>, <int>
    mov [rdx + rcx], byte 0xc7
    ; mod rm = 0xc0 | dst << 3 | src
    mov al, 0xc0
    or al, sil
    mov [rdx + rcx + 1], byte al
    mov [rdx + rcx + 2], dword edi      ; imm32
    mov rax, 6
    ret

emit_mov_reg_reg:
; rdi = reg (dst)
; rsi = reg (src)
; rdx = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble mov <reg>, <reg>
    mov [rdx + rcx], byte 0x48
    mov al, 0x89
    mov [rdx + rcx + 1], byte al
    ; mod rm = 0xc0 | dst << 3 | src
    mov al, 0b11000000
    or al, sil
    shl dil, 3
    or al, dil
    mov [rdx + rcx + 2], byte al
    mov rax, 3
    ret


emit_mov_reg_mem:
; rdi = reg
; rsi = reg
; rdx = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble mov <reg>, [<reg>]
    mov [rdx + rcx], byte 0x48
    mov al, 0x8b
    mov [rdx + rcx + 1], byte al
    ; mod rm = 0xc0 | dst << 3 | src
    shl dil, 3
    or sil, dil
    mov [rdx + rcx + 2], byte sil
    mov rax, 3
    ret


emit_cmp_reg_int:
; rdi = int
; rsi = reg
; rdx = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble cmp <reg>, <int>
    mov al, 0x48         ; 48 for rex.w, 81 for cmp r/m64, imm32
    mov [rdx + rcx], byte al
    mov al, 0x81
    mov [rdx + rcx + 1], byte al
    ; mod rm = 0xc0 | dst << 3 | src
    mov al, 0x7
    shl al, 3
    or al, 0xc0
    or al, sil
    mov [rdx + rcx + 2], byte al
    mov [rdx + rcx + 3], dword edi      ; imm32
    mov rax, 7
    ret

emit_cmp_mem_int:
; rdi = int
; rsi = reg
; rdx = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble cmp <reg>, <int>
    ; cmp byte [rbx], 0
    mov [rdx + rcx], byte 0x80
    mov al, 0x38
    or al, sil
    mov [rdx + rcx + 1], byte al
    mov [rdx + rcx + 2], byte dil      ; imm8
    mov rax, 3
    ret

emit_jmp:
; rdi = offset
; rsi = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble jmp <offset>
    mov al, 0xe9
    mov [rdx + rcx], byte al
    mov [rdx + rcx + 1], dword edi           ; offset
    mov rax, 5
    ret

emit_jne:
; rdi = offset
; rsi = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble jne <offset>
    mov ax, 0x850f         ; 0f85 for jne
    mov [rdx + rcx], word ax
    mov [rdx + rcx + 2], dword edi           ; offset
    mov rax,  6
    ret

emit_je:
; rdi = offset
; rsi = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble je <offset>
    mov ax, 0x840f         ; 0f84 for je
    mov [rdx + rcx], word ax
    mov [rdx + rcx + 2], dword edi           ; offset
    mov rax,  6
    ret

emit_add_reg_int:
; rdi = int
; rsi = reg
; rdx = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble add <reg>, <int>
    mov al, 0x48         ; 48 for rex.w, 81 for add r/m64, imm32
    mov [rdx + rcx], byte al
    mov al, 0x81
    mov [rdx + rcx + 1], byte al
    ; mod rm = 0xc0 | dst << 3 | src
    mov al, 0xc0
    or al, sil
    mov [rdx + rcx + 2], byte al
    mov [rdx + rcx + 3], dword edi      ; imm32
    mov rax, 7
    ret

emit_syscall:
; rdx = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble syscall
    mov ax, 0x050f         ; 0f05 for syscall
    mov [rdx + rcx], word ax
    mov rax,  2
    ret
 