; boot/boot.asm
; MBR: загружает kernel.bin с LBA 1 в 0x10000,
; включает Protected Mode и прыгает в 32-bit C kernel.

[bits 16]
[org 0x7C00]

%ifndef KERNEL_SECTORS
    %error "KERNEL_SECTORS is not defined"
%endif

KERNEL_LOAD_ADDR equ 0x10000
KERNEL_LOAD_SEG  equ 0x1000
KERNEL_LOAD_OFF  equ 0x0000

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    mov si, msg_loading
    call print16

    ; BIOS Extended Read, int 13h ah=42h
    ; Читаем kernel.bin с LBA 1, т.е. сразу после MBR.
    mov dl, [boot_drive]
    mov si, dap
    mov ah, 0x42
    int 0x13
    jc disk_error

    ; Enable A20 через Fast A20 Gate
    in al, 0x92
    or al, 00000010b
    out 0x92, al

    cli

    lgdt [gdt_desc]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Дальний прыжок очищает pipeline и загружает CS.
    jmp CODE_SEG:pm_start

disk_error:
    mov si, msg_disk_error
    call print16
.hang:
    hlt
    jmp .hang

print16:
    lodsb
    test al, al
    jz .done

    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    jmp print16

.done:
    ret

boot_drive db 0

msg_loading    db "Loading kernel...", 13, 10, 0
msg_disk_error db "Disk read error!", 13, 10, 0

; Disk Address Packet для int 13h ah=42h
dap:
    db 0x10                 ; packet size
    db 0x00                 ; reserved
    dw KERNEL_SECTORS       ; сколько секторов читать
    dw KERNEL_LOAD_OFF      ; offset
    dw KERNEL_LOAD_SEG      ; segment
    dq 1                    ; start LBA = 1, сразу после MBR

; ---------------- GDT ----------------

gdt_start:
gdt_null:
    dq 0

gdt_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b            ; present, ring 0, code, executable, readable
    db 11001111b            ; 4K granularity, 32-bit, limit high
    db 0x00

gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b            ; present, ring 0, data, writable
    db 11001111b
    db 0x00

gdt_end:

gdt_desc:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; ---------------- Protected Mode ----------------

[bits 32]

pm_start:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0x90000

    ; Прыгаем в kernel.bin, загруженный по физическому адресу 0x10000.
    mov eax, KERNEL_LOAD_ADDR
    jmp eax

times 510 - ($ - $$) db 0
dw 0xAA55