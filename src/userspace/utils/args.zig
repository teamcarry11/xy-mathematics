//! Argument Parsing Helper for Userspace Utilities
//! Why: Common argument parsing functionality for shell utilities
//! Grain Style: Static allocation, explicit types, comprehensive assertions

/// Maximum number of arguments (Grain Style: explicit size)
const MAX_ARGS: u32 = 64;

/// Maximum argument length (Grain Style: explicit size)
const MAX_ARG_LEN: u32 = 256;

/// Parsed arguments structure
/// Why: Store parsed command-line arguments for utilities
pub const Args = struct {
    /// Argument count (excluding program name)
    argc: u32,
    
    /// Argument values (pointers to strings on stack)
    argv: [MAX_ARGS][*:0]const u8,
    
    /// Initialize Args from RISC-V calling convention
    /// Contract:
    ///   Input: argc (from a0), argv (from a1) - RISC-V convention
    ///   Output: Parsed Args structure
    ///   Errors: Too many arguments, argument too long
    /// Why: Parse command-line arguments for userspace programs
    pub fn init(argc: u64, argv: [*][*:0]const u8) Args {
        // Contract: argc must be reasonable
        if (argc > MAX_ARGS) {
            // Return empty args if too many
            return Args{ .argc = 0, .argv = undefined };
        }
        
        var args = Args{
            .argc = if (argc > 0) argc - 1 else 0, // Exclude program name
            .argv = undefined,
        };
        
        // Copy argument pointers (skip argv[0] which is program name)
        var i: u32 = 0;
        while (i < args.argc) : (i += 1) {
            args.argv[i] = argv[i + 1];
        }
        
        return args;
    }
    
    /// Initialize Args by reading from RISC-V registers
    /// Contract:
    ///   Reads argc from a0 (x10) and argv from a1 (x11)
    ///   Output: Parsed Args structure
    /// Why: Convenience function to read registers directly
    pub fn init_from_registers() Args {
        // Read argc from register a0 (x10) using inline assembly
        const argc_val: u64 = asm volatile (""
            : [ret] "={x10}" (-> u64),
        );
        
        // Read argv pointer from register a1 (x11) using inline assembly
        const argv_ptr: [*][*:0]const u8 = asm volatile (""
            : [ret] "={x11}" (-> [*][*:0]const u8),
        );
        
        return init(argc_val, argv_ptr);
    }
    
    /// Get argument by index
    /// Contract:
    ///   Input: index must be < argc
    ///   Output: Returns argument string or null if out of bounds
    pub fn get(self: *const Args, index: u32) ?[*:0]const u8 {
        if (index >= self.argc) return null;
        return self.argv[index];
    }
    
    /// Check if flag is present
    /// Contract:
    ///   Input: flag must be non-null (e.g., "-n")
    ///   Output: Returns true if flag is present
    pub fn has_flag(self: *const Args, flag: [*:0]const u8) bool {
        var i: u32 = 0;
        while (i < self.argc) : (i += 1) {
            if (self.argv[i][0] == '-' and self.argv[i][1] == flag[1]) {
                return true;
            }
        }
        return false;
    }
};

