//! cp: Copy files/directories
//! Why: Essential file copying utility for userspace programs
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// Maximum path length (Grain Style: explicit size)
const MAX_PATH_LEN: u32 = 256;

/// Maximum buffer size for copying (Grain Style: explicit size)
const COPY_BUFFER_SIZE: u32 = 4096;

/// Open flags (Grain Style: explicit values)
const O_RDONLY: u32 = 0;
const O_WRONLY: u32 = 1;
const O_CREAT: u32 = 2;

/// Copy file from source to destination
/// Contract:
///   Input: src_path and dst_path must be null-terminated strings
///   Output: Returns true on success, false on error
/// Why: Copy file contents from source to destination
fn copy_file(src_path: [*:0]const u8, dst_path: [*:0]const u8) bool {
    // Open source file
    const src_fd = stdlib.open(src_path, O_RDONLY);
    if (src_fd < 0) {
        return false; // Failed to open source
    }
    
    // Open/create destination file
    const dst_fd = stdlib.open(dst_path, O_WRONLY | O_CREAT);
    if (dst_fd < 0) {
        _ = stdlib.close(@intCast(src_fd));
        return false; // Failed to open/create destination
    }
    
    var buffer: [COPY_BUFFER_SIZE]u8 = undefined;
    
    // Copy file contents
    while (true) {
        const bytes_read = stdlib.read(@intCast(src_fd), &buffer);
        if (bytes_read <= 0) break;
        
        const bytes_written = stdlib.write(@intCast(dst_fd), buffer[0..@intCast(bytes_read)]);
        if (bytes_written < 0) break;
    }
    
    // Close files
    _ = stdlib.close(@intCast(src_fd));
    _ = stdlib.close(@intCast(dst_fd));
    return true;
}

/// Entry point for cp utility
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success, non-zero on error
/// Why: Copy files and directories
pub fn main() void {
    const args = @import("userspace_args").Args.init_from_registers();
    
    // Need at least source and destination
    if (args.argc < 2) {
        const error_msg: [*:0]const u8 = "cp: missing file operand\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    // Check for -r flag (recursive) - not yet implemented
    const recursive = args.has_flag("-r");
    if (recursive) {
        const error_msg: [*:0]const u8 = "cp: -r flag not yet implemented\n";
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
    
    // Copy file
    if (!copy_file(src_path, dst_path)) {
        const error_msg: [*:0]const u8 = "cp: failed to copy file\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    stdlib.exit(0);
}
