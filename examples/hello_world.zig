//! Hello World Example for Grain Basin Userspace
//! Why: Minimal example program to test VM-kernel integration.
//! Tiger Style: Simple, clear, well-documented.

const stdlib = @import("userspace_stdlib");

/// Entry point for Hello World program.
/// Contract:
///   Input: argc, argv (RISC-V calling convention)
///   Output: Exit code 0 on success
/// Why: Test basic userspace program execution in VM.
pub fn main() void {
    // Print "Hello, World!\n" to stdout.
    const message = "Hello, World!\n";
    _ = stdlib.print(message);
    
    // Exit with code 0.
    stdlib.exit(0);
}

