.section .multiboot,"a"
.align 4
.global multiboot_header
multiboot_header:
    .long 0x1BADB002                      # Multiboot v1 magic
    .long 0x00010003                      # align modules + meminfo + address fields
    .long -(0x1BADB002 + 0x00010003)      # checksum
    .long multiboot_header                # header_addr
    .long _kernel_start                   # load_addr
    .long _kernel_end                     # load_end_addr
    .long _bss_end                        # bss_end_addr
    .long _mb_start32                     # entry_addr (32-bit)

.section .text.boot.mb
.code32
.global _mb_start32
.extern kernel_entry_x64

_mb_start32:
    cli
    cld
    xor %ebp, %ebp

    # multiboot: EAX=magic, EBX=mbi pointer
    mov %eax, mb_magic
    mov %ebx, mb_info

    mov $mb_stack_top, %esp
    and $-16, %esp

    lgdt gdt64_ptr

    mov %cr4, %eax
    or $0x20, %eax                        # CR4.PAE
    mov %eax, %cr4

    mov $pml4_table, %eax
    mov %eax, %cr3

    mov $0xC0000080, %ecx                 # IA32_EFER
    rdmsr
    or $0x100, %eax                       # EFER.LME
    wrmsr

    mov %cr0, %eax
    or $0x80000001, %eax                  # CR0.PG | CR0.PE
    mov %eax, %cr0

    ljmp $0x08, $long_mode_entry

.code64
long_mode_entry:
    mov $0x10, %ax
    mov %ax, %ss

    # Enable x87/SSE so ms_abi C code can safely use XMM save/restore.
    mov %cr0, %rax
    and $~(1 << 2), %rax                  # CR0.EM = 0
    or  $(1 << 1), %rax                   # CR0.MP = 1
    mov %rax, %cr0
    mov %cr4, %rax
    or  $((1 << 9) | (1 << 10)), %rax     # CR4.OSFXSR | CR4.OSXMMEXCPT
    mov %rax, %cr4
    fninit

    lea mb_stack64_top(%rip), %rsp
    and $-16, %rsp

    mov $2, %rdi                          # boot mode: Multiboot/MBR
    mov mb_magic(%rip), %esi
    mov mb_info(%rip), %edx
    call kernel_entry_x64

1:
    hlt
    jmp 1b

.section .rodata
.align 8
gdt64:
    .quad 0x0000000000000000
    .quad 0x00AF9A000000FFFF              # 0x08: 64-bit code
    .quad 0x008F92000000FFFF              # 0x10: data/stack for long mode
gdt64_end:
gdt64_ptr:
    .word gdt64_end - gdt64 - 1
    .long gdt64

.section .data
.align 4096
pml4_table:
    .quad pdpt_table + 0x003
    .fill 511, 8, 0

.align 4096
pdpt_table:
    .quad pd_table + 0x003
    .fill 511, 8, 0

.align 4096
pd_table:
    .set pde_idx, 0
    .rept 512
    .quad (pde_idx * 0x200000) + 0x083    # present + writable + 2MiB page
    .set pde_idx, pde_idx + 1
    .endr

.section .bss
.align 16
mb_magic:
    .long 0
mb_info:
    .long 0

.align 16
mb_stack_bottom:
    .skip 16384
mb_stack_top:

.align 16
mb_stack64_bottom:
    .skip 16384
mb_stack64_top:

.section .note.GNU-stack,"",@progbits
