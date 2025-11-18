//! mv: Move/rename files
//! Why: Essential file moving/renaming utility for userspace programs
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// Maximum path length (Grain Style: explicit size)
const MAX_PATH_LEN: u32 = 256;

/// Entry point for mv utility
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success, non-zero on error
/// Why: Move or rename files
pub fn main() void {
    const args = @import("userspace_args").Args.init_from_registers();
    
    // Need at least source and destination
    if (args.argc < 2) {
        const error_msg: [*:0]const u8 = "mv: missing file operand\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    // Get source and destination paths
    const src_path = args.get(0) orelse {
        stdlib.exit(1);
    };
    const dst_path = args.get(args.argc - 1) orelse {
        stdlib.exit(1);
    };
    
    // Rename file
    const result = stdlib.rename(src_path, dst_path);
    if (result < 0) {
        const error_msg: [*:0]const u8 = "mv: failed to rename file\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    stdlib.exit(0);
}
