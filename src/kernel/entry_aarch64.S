// AArch64 Kernel Entry Point
// Why: AArch64-specific boot code for kernel initialization.
// Grain Style: Minimal, explicit, deterministic.

.section .text.init
.global _start

_start:
    // Disable interrupts (DAIF = 0xF sets all interrupt flags).
    msr daifset, #0xF
    
    // Set up stack pointer (AArch64 uses SP register).
    // Note: Use adrp + add to load far address (stack is in .bss section).
    adrp x0, _stack_top
    add x0, x0, :lo12:_stack_top
    mov sp, x0
    
    // DEBUG: Write 'G' to UART (0x9000000) to verify life.
    // Note: AArch64 UART address may differ from RISC-V.
    mov x0, #0x9000000
    mov w1, #71  // 'G'
    strb w1, [x0]
    
    // Jump to Zig kernel main.
    bl kmain
    
    // Loop if kmain returns.
    b .

.section .bss
.align 16
.global _stack_bottom
.global _stack_top
_stack_bottom:
    .skip 16384  // 16KB stack
_stack_top:

