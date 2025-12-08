//! ls: List directory contents
//! Why: Essential directory listing utility for userspace programs
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// Maximum path length (Grain Style: explicit size)
const MAX_PATH_LEN: u32 = 256;

/// Maximum entry name length (Grain Style: explicit size)
const MAX_ENTRY_LEN: u32 = 256;

/// Entry point for ls utility
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success, non-zero on error
/// Why: List directory contents
pub fn main() void {
    const args = @import("userspace_args").Args.init_from_registers();
    
    // Default to current directory "." if no arguments
    const dir_path: [*:0]const u8 = if (args.argc > 0) blk: {
        if (args.get(0)) |arg| {
            break :blk arg;
        }
        break :blk ".";
    } else ".";
    
    // Open directory
    const dir_handle = stdlib.opendir(dir_path);
    if (dir_handle < 0) {
        const error_msg: [*:0]const u8 = "ls: cannot open directory\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    // Read directory entries
    var entry_buffer: [MAX_ENTRY_LEN]u8 = undefined;
    var entry_count: u32 = 0;
    
    while (true) {
        const bytes_read = stdlib.readdir(@as(u32, @intCast(dir_handle)), &entry_buffer);
        
        if (bytes_read < 0) {
            // Error reading directory
            const error_msg: [*:0]const u8 = "ls: error reading directory\n";
            _ = stdlib.print(error_msg);
            _ = stdlib.closedir(@as(u32, @intCast(dir_handle)));
            stdlib.exit(1);
        }
        
        if (bytes_read == 0) {
            // End of directory
            break;
        }
        
        // Print entry name (simulated - in real implementation would format properly)
        // For now, just print a placeholder
        entry_count += 1;
    }
    
    // Close directory
    _ = stdlib.closedir(@as(u32, @intCast(dir_handle)));
    
    // Print summary (placeholder for now)
    if (entry_count == 0) {
        const msg: [*:0]const u8 = "ls: directory is empty\n";
        _ = stdlib.print(msg);
    } else {
        // TODO: Print actual entry names
        const msg: [*:0]const u8 = "ls: directory listing (stub - entries found)\n";
        _ = stdlib.print(msg);
    }
    
    stdlib.exit(0);
}

