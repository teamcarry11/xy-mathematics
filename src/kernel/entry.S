.section .text.init
.global _start

_start:
    # Disable interrupts
    csrw sie, zero
    
    # Set up stack pointer
    la sp, _stack_top

    # DEBUG: Write 'G' to UART (0x10000000) to verify life
    li t0, 0x10000000
    li t1, 71 # 'G'
    sb t1, 0(t0)

    # Jump to Zig kernel main
    call kmain

    # Loop if kmain returns
    j .

.section .bss
.align 4
.global _stack_bottom
.global _stack_top
_stack_bottom:
    .skip 4096 * 4 # 16KB stack
_stack_top:
