//! echo: Print text to stdout
//! Why: Essential text output utility for userspace programs
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// Maximum output length (Grain Style: explicit size)
const MAX_OUTPUT_LEN: u32 = 4096;

/// Entry point for echo utility
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success
/// Why: Print arguments to stdout
pub fn main() void {
    const args = @import("userspace_args").Args.init_from_registers();
    
    // Check for -n flag (no newline)
    const no_newline = args.has_flag("-n");
    
    // Print all arguments
    var i: u32 = 0;
    var first: bool = true;
    while (i < args.argc) : (i += 1) {
        if (args.get(i)) |arg| {
            // Skip flags
            if (arg[0] == '-') continue;
            
            if (!first) {
                _ = stdlib.print(" ");
            }
            _ = stdlib.print(arg);
            first = false;
        }
    }
    
    // Print newline unless -n flag is set
    if (!no_newline) {
        _ = stdlib.print("\n");
    }
    
    stdlib.exit(0);
}
