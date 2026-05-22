; boot/boot.asm
; MBR: загружает kernel.bin с LBA 1 в 0x10000,
; Enable 64 bit and start kernel oin 64 bit

; ---------------- Protected Mode ----------------

section .text.boot64

; this is 0x10000

extern _start

[bits 32]
; [org 0x10000]
boot64_32_start:
    
    nop
    nop

    lgdt [gdt64_desc]
    
    mov eax, cr4
    or eax, 0x20                        ; CR4.PAE
    mov cr4, eax

    mov eax, pml4_table
    mov cr3, eax

    mov ecx, 0xC0000080                 ; IA32_EFER
    rdmsr
    or eax, 0x100                       ; EFER.LME
    wrmsr

    mov eax, cr0
    or eax, 0x80000001                  ; CR0.PG | CR0.PE
    mov cr0, eax
   
    jmp 0x08:boot64_64_start

[bits 64]
boot64_64_start:

    
    mov ax, 0x10
    mov ss, ax

    ;mov rsp, 0x800000
      
     ; Enable x87/SSE so ms_abi C code can safely use XMM save/restore.
    ;mov rax, cr0
    ;and rax, ~(1 << 2)                  ; CR0.EM = 0
    ;or  rax, (1 << 1)                   ; CR0.MP = 1
    ;mov cr0, rax
    ;mov rax, cr4
    ;or  rax, ((1 << 9) | (1 << 10))     ; CR4.OSFXSR | CR4.OSXMMEXCPT
    ;mov cr4, rax
    ;fninit
    
    jmp _start

_1:
  jmp _1

gdt64_start:
gdt64_null:
    dq 0

gdt64_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b            ; present, ring 0, code, executable, readable
    db 10101111b            ; 4K granularity, 64-bit, limit high
    db 0x00

gdt64_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b            ; present, ring 0, data, writable
    db 10001111b
    db 0x00

gdt64_end:

gdt64_desc:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

CODE64_SEG equ gdt64_code - gdt64_start
DATA64_SEG equ gdt64_data - gdt64_start

align 4096
pml4_table:
    dq pdpt_table + 0x003
    times 511 dq 0

pdpt_table:
    dq pd_table1 + 0x003
    dq pd_table2 + 0x003
    times 510 dq 0

pd_table1:
    %assign pde_idx 0
    %rep 512
    dq (pde_idx * 0x200000) + 0x083    ; present + writable + 2MiB page
    %assign pde_idx pde_idx + 1
    %endrep
    
pd_table2:
    %assign pde_idx1 0x80000000
    %rep 512
    dq (pde_idx1 * 0x200000) + 0x083    ; present + writable + 2MiB page
    %assign pde_idx1 pde_idx1 + 1
    %endrep

kernel_bin:
