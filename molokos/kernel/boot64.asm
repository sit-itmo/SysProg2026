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
    ;mov eax, [kernel_bin]
    jmp _start

[bits 64]
boot64_64_start:
    nop
_1:
  jmp _1

kernel_bin:
