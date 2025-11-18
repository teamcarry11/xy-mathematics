/* Userspace linker script for RISC-V64 */
OUTPUT_ARCH(riscv)
ENTRY(main)
SECTIONS
{
    /* Userspace programs load at 0x10000 (different from kernel at 0x80200000) */
    . = 0x10000;
    .text : {
        *(.text.main)
        *(.text*)
    }

    .rodata : {
        *(.srodata*)
        *(.rodata*)
    }

    .data : {
        *(.sdata*)
        *(.data*)
    }

    .bss : {
        *(.sbss*)
        *(.bss*)
        *(COMMON)
    }
}

