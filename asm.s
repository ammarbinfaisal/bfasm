global main

section .text

main:
    ; save the pointer to the allocated memory
    push rbp
    mov rbp, rsp

    ; allocate 0x1000 bytes of memory
    ; mmap(NULL, 0x1000, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    mov rax, 0x9
    mov rdi, 0x0
    mov rsi, 0x1000
    mov rdx, 0x7
    mov r10, 0x22
    mov r8, 0xffffffff
    mov r9, 0x0
    syscall

    ; save the pointer to the allocated memory
    mov r9, rax

    ; xor rax rax
    mov rdx, r9
    mov rcx, 0x0
    mov rsi, 0x0
    call emit_xor_reg
    add rcx, rax 

    ; add rax, 0x1
    mov rdx, r9
    mov r11, rcx ; save the location of the add instruction so we can jump back to it
    mov rsi, 0x0
    mov rdi, 0x1
    call emit_add_reg_int
    add rcx, rax

    ; cmp rax, 0xdeadbeff
    mov rdx, r9
    mov rsi, 0x0 ; 0 = rax
    mov rdi, 0x11
    call emit_cmp_reg_int
    add rcx, rax

    ; jne 0x0 
    mov r12, rcx ; backup rcx
    sub r12, r11
    add r12, 0x6 ; size of the jne instruction
    not r12      
    add r12, 0x1 ; two's complement
    mov edi, r12d 
    mov rsi, r9  ; buffer
    call emit_jne
    add rcx, rax

    ; fill with nops then ret
    mov rax, 0x909090c3
    mov [r9 + rcx], dword eax

    ; jump back to the start
    call r9
    leave
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


emit_mov_reg_int:
; rdi = int
; rsi = reg
; rdx = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble mov <reg>, <int>
    mov al, 0x48         ; 48 for rex.w, b8 for mov r64, imm64
    mov [rdx + rcx], byte al
    or sil, 0xb8                        ; (sil is the lower 8 bits of rsi)
    mov [rdx + rcx + 1], byte sil       ; reg64
    mov [rdx + rcx + 2], dword edi      ; imm32
    mov rax, 6
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

emit_jne:
; rdi = offset
; rsi = buffer
; rcx = location
; rax = returned length of the encoded instruction
; will assemble jne <offset>
    mov ax, 0x850f         ; 0f85 for jne
    mov [rsi + rcx], word ax
    mov [rsi + rcx + 2], dword edi           ; offset
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
