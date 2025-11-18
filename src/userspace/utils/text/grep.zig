//! grep: Search text patterns in files
//! Why: Essential text pattern matching utility for userspace programs
//! Grain Style: Static allocation, explicit types, comprehensive assertions

const stdlib = @import("userspace_stdlib");

/// Maximum line length (Grain Style: explicit size)
const MAX_LINE_LEN: u32 = 4096;

/// Maximum pattern length (Grain Style: explicit size)
const MAX_PATTERN_LEN: u32 = 256;

/// Simple string matching (substring search)
/// Contract:
///   Input: text and pattern must be null-terminated strings
///   Output: Returns true if pattern found as substring in text
/// Why: Basic pattern matching for grep (substring search)
fn match_pattern(text: [*:0]const u8, pattern: [*:0]const u8) bool {
    // Empty pattern matches everything
    if (pattern[0] == 0) {
        return true;
    }
    
    var text_idx: u32 = 0;
    
    // Try matching pattern at each position in text
    while (text[text_idx] != 0) {
        var pattern_idx: u32 = 0;
        var match_start: u32 = text_idx;
        
        // Try to match pattern starting at current text position
        while (text[match_start] != 0 and pattern[pattern_idx] != 0) {
            if (text[match_start] != pattern[pattern_idx]) {
                break; // Mismatch, try next position
            }
            match_start += 1;
            pattern_idx += 1;
        }
        
        // If we matched the entire pattern, return true
        if (pattern[pattern_idx] == 0) {
            return true;
        }
        
        text_idx += 1;
    }
    
    return false; // Pattern not found
}

/// Entry point for grep utility
/// Contract:
///   Input: argc, argv (RISC-V calling convention: a0=argc, a1=argv)
///   Output: Exit code 0 on success, non-zero on error
/// Why: Search for patterns in files
pub fn main() void {
    const args = @import("userspace_args").Args.init_from_registers();
    
    // Need at least pattern and optionally files
    if (args.argc == 0) {
        const error_msg: [*:0]const u8 = "grep: missing pattern\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    // Check for flags
    const case_insensitive = args.has_flag("-i");
    const line_numbers = args.has_flag("-n");
    
    if (case_insensitive or line_numbers) {
        const error_msg: [*:0]const u8 = "grep: -i and -n flags not yet implemented\n";
        _ = stdlib.print(error_msg);
        stdlib.exit(1);
    }
    
    // Get pattern (first argument)
    const pattern = args.get(0) orelse {
        stdlib.exit(1);
    };
    
    // If no files specified, read from stdin
    if (args.argc == 1) {
        var buffer: [MAX_LINE_LEN]u8 = undefined;
        while (true) {
            const bytes_read = stdlib.read(stdlib.io.stdin_handle, &buffer);
            if (bytes_read <= 0) break;
            
            // Null-terminate the buffer
            const bytes_read_u32: u32 = @intCast(bytes_read);
            if (bytes_read_u32 < buffer.len) {
                buffer[bytes_read_u32] = 0;
            }
            
            // Check if pattern matches
            if (match_pattern(&buffer, pattern)) {
                _ = stdlib.write(stdlib.io.stdout_handle, buffer[0..bytes_read_u32]);
            }
        }
    } else {
        // Process files (skip pattern argument, process remaining files)
        var i: u32 = 1; // Skip pattern (index 0)
        var found_match: bool = false;
        
        while (i < args.argc) : (i += 1) {
            if (args.get(i)) |file_path| {
                // Skip flags
                if (file_path[0] == '-') continue;
                
                // Open file
                const O_RDONLY: u32 = 0;
                const fd = stdlib.open(file_path, O_RDONLY);
                if (fd < 0) continue; // Skip files that can't be opened
                
                var buffer: [MAX_LINE_LEN]u8 = undefined;
                
                // Read and search file
                while (true) {
                    const bytes_read = stdlib.read(@intCast(fd), &buffer);
                    if (bytes_read <= 0) break;
                    
                    const bytes_read_u32: u32 = @intCast(bytes_read);
                    if (bytes_read_u32 < buffer.len) {
                        buffer[bytes_read_u32] = 0;
                    }
                    
                    // Check if pattern matches
                    if (match_pattern(&buffer, pattern)) {
                        found_match = true;
                        _ = stdlib.write(stdlib.io.stdout_handle, buffer[0..bytes_read_u32]);
                    }
                }
                
                _ = stdlib.close(@intCast(fd));
            }
        }
        
        stdlib.exit(if (found_match) 0 else 1);
    }
}

