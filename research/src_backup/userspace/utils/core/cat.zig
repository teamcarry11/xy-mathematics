//! cat: Concatenate and print files
//! Why: Essential file viewing utility for userspace programs
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// Maximum line length for reading (Grain Style: explicit size)
const MAX_LINE_LEN: u32 = 4096;

/// Maximum number of files to process
const MAX_FILES: u32 = 64;

/// Open flags (Grain Style: explicit values)
const O_RDONLY: u32 = 0;

/// Copy file contents to stdout
/// Contract:
///   Input: file_path must be null-terminated string
///   Output: Returns true on success, false on error
/// Why: Read file and print to stdout
fn cat_file(file_path: [*:0]const u8) bool {
    // Open file
    const fd = stdlib.open(file_path, O_RDONLY);
    if (fd < 0) {
        return false; // Failed to open file
    }
    
    var buffer: [MAX_LINE_LEN]u8 = undefined;
    
    // Read and print file contents
    while (true) {
        const bytes_read = stdlib.read(@intCast(fd), &buffer);
        if (bytes_read <= 0) break;
        
        const bytes_written = stdlib.write(stdlib.io.stdout_handle, buffer[0..@intCast(bytes_read)]);
        if (bytes_written < 0) break;
    }
    
    // Close file
    _ = stdlib.close(@intCast(fd));
    return true;
}

/// Entry point for cat utility
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success, non-zero on error
/// Why: Print file contents to stdout
pub fn main() void {
    const args = @import("userspace_args").Args.init_from_registers();
    
    // If no arguments, read from stdin
    if (args.argc == 0) {
        var buffer: [MAX_LINE_LEN]u8 = undefined;
        while (true) {
            const bytes_read = stdlib.read(stdlib.io.stdin_handle, &buffer);
            if (bytes_read <= 0) break;
            
            const bytes_written = stdlib.write(stdlib.io.stdout_handle, buffer[0..@intCast(bytes_read)]);
            if (bytes_written < 0) break;
        }
    } else {
        // Process each file argument
        var i: u32 = 0;
        while (i < args.argc) : (i += 1) {
            if (args.get(i)) |file_path| {
                _ = cat_file(file_path);
            }
        }
    }
    
    stdlib.exit(0);
}

