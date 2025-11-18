//! ls: List directory contents
//! Why: Essential directory listing utility for userspace programs
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// Maximum path length (Grain Style: explicit size)
const MAX_PATH_LEN: u32 = 256;

/// Entry point for ls utility
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success, non-zero on error
/// Why: List directory contents
pub fn main() void {
    // TODO: Parse argc/argv from RISC-V registers (a0, a1)
    // TODO: Implement directory listing syscall (readdir, opendir)
    // TODO: Support -l flag (long format), -a flag (all files)
    // For now: print placeholder message
    // Future: Use inline assembly to read a0 (argc) and a1 (argv) from registers
    
    const message: [*:0]const u8 = "ls: directory listing not yet implemented\n";
    _ = stdlib.print(message);
    
    stdlib.exit(0);
}

