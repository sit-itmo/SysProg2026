ENTRY(_start)

SECTIONS
{
    . = 0x10000;

    .text : ALIGN(4)
    {
        *(.text.start)
        *(.text*)
    }

    .rodata : ALIGN(4)
    {
        *(.rodata*)
    }

    .data : ALIGN(4)
    {
        *(.data*)
    }

    .bss : ALIGN(4)
    {
        *(COMMON)
        *(.bss*)
    }
}