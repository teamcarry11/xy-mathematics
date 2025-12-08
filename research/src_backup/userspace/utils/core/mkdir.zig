//! mkdir: Create directories
//! Why: Essential directory creation utility for userspace programs
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// Maximum path length (Grain Style: explicit size)
const MAX_PATH_LEN: u32 = 256;

/// Entry point for mkdir utility
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success, non-zero on error
/// Why: Create directories
pub fn main() void {
    const args = @import("userspace_args").Args.init_from_registers();
    
    // Need at least one directory to create
    if (args.argc == 0) {
        const error_msg: [*:0]const u8 = "mkdir: missing operand\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    // Check for -p flag (create parent directories) - not yet implemented
    const create_parents = args.has_flag("-p");
    if (create_parents) {
        const error_msg: [*:0]const u8 = "mkdir: -p flag not yet implemented\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    // Create each directory argument
    var i: u32 = 0;
    var success: bool = true;
    while (i < args.argc) : (i += 1) {
        if (args.get(i)) |dir_path| {
            // Skip flags
            if (dir_path[0] == '-') continue;
            
            const result = stdlib.mkdir(dir_path);
            if (result < 0) {
                success = false;
            }
        }
    }
    
    stdlib.exit(if (success) 0 else 1);
}

