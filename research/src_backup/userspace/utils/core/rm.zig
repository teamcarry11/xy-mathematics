//! rm: Remove files/directories
//! Why: Essential file removal utility for userspace programs
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// Maximum path length (Grain Style: explicit size)
const MAX_PATH_LEN: u32 = 256;

/// Entry point for rm utility
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success, non-zero on error
/// Why: Remove files and directories
pub fn main() void {
    const args = @import("userspace_args").Args.init_from_registers();
    
    // Need at least one file to remove
    if (args.argc == 0) {
        const error_msg: [*:0]const u8 = "rm: missing operand\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    // Check for flags
    const recursive = args.has_flag("-r");
    _ = args.has_flag("-f"); // force flag (not yet used)
    
    if (recursive) {
        const error_msg: [*:0]const u8 = "rm: -r flag not yet implemented\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    // Remove each file argument
    var i: u32 = 0;
    var success: bool = true;
    while (i < args.argc) : (i += 1) {
        if (args.get(i)) |file_path| {
            // Skip flags
            if (file_path[0] == '-') continue;
            
            const result = stdlib.unlink(file_path);
            if (result < 0) {
                success = false;
            }
        }
    }
    
    stdlib.exit(if (success) 0 else 1);
}

