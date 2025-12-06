// Secure random generation for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Uses Zig's std.crypto for cryptographically secure random number generation

const std = @import("std");
const errors = @import("../utils/errors.zig");

pub const MAX_RANDOM_BYTES: u32 = 256;

pub fn generate_random_bytes(output: []u8) void {
    std.debug.assert(output.len > 0);
    std.debug.assert(output.len <= MAX_RANDOM_BYTES);
    
    std.crypto.random.bytes(output);
    
    std.debug.assert(output.len > 0);
    std.debug.assert(output.len <= MAX_RANDOM_BYTES);
}

pub fn generate_random_u32() u32 {
    var bytes: [4]u8 = undefined;
    generate_random_bytes(&bytes);
    
    const value = std.mem.readInt(u32, &bytes, .little);
    
    std.debug.assert(value >= 0);
    
    return value;
}

pub fn generate_random_u64() u64 {
    var bytes: [8]u8 = undefined;
    generate_random_bytes(&bytes);
    
    const value = std.mem.readInt(u64, &bytes, .little);
    
    std.debug.assert(value >= 0);
    
    return value;
}

// Generate random token of specified length (for OTP, session tokens, etc.)
pub fn generate_token(output: []u8) void {
    std.debug.assert(output.len > 0);
    std.debug.assert(output.len <= MAX_RANDOM_BYTES);
    
    generate_random_bytes(output);
    
    std.debug.assert(output.len > 0);
    std.debug.assert(output.len <= MAX_RANDOM_BYTES);
}

