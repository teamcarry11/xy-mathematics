//! RISC-V Logo Display Program
//! Why: Display RISC-V logo from userspace through kernel syscalls
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// RISC-V logo as ASCII art (simple text representation).
/// Why: Display logo using write syscall to stdout.
const RISCV_LOGO: [*:0]const u8 =
    \\    ____  ____   ____  __  __   ____
    \\   |  _ \|  _ \ / ___||  \/  | / ___|
    \\   | |_) | |_) | |    | |\/| || |
    \\   |  _ <|  _ <| |___ | |  | || |___
    \\   |_| \_\_| \_\\____||_|  |_| \____|
    \\
    \\   RISC-V: Open Standard Instruction Set Architecture
    \\
;

/// Entry point for RISC-V logo display program.
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success, non-zero on error
/// Why: Display RISC-V logo from userspace
pub fn main() void {
    // Write logo to stdout (handle 1).
    const stdout_handle: u32 = 1;
    
    // Calculate logo length (null-terminated string).
    var len: u64 = 0;
    while (RISCV_LOGO[len] != 0) : (len += 1) {
        // Bounds check (prevent infinite loop).
        if (len >= 4096) {
            stdlib.exit(1);
        }
    }
    
    // Write logo to stdout.
    const bytes_written = stdlib.write(stdout_handle, RISCV_LOGO[0..len]);
    
    if (bytes_written < 0) {
        stdlib.exit(1);
    }
    
    // Exit successfully.
    stdlib.exit(0);
}

