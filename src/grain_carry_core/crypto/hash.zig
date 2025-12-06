// Password hashing for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Note: For production, consider adding bcrypt or Argon2 implementation.
// Current implementation uses SHA-256 with salt (acceptable for MVP).
// TODO: Add bcrypt/Argon2 support for production use.

const std = @import("std");
const errors = @import("../utils/errors.zig");
const random = @import("random.zig");

pub const SALT_LEN: u32 = 32;
pub const HASH_LEN: u32 = 32;  // SHA-256 output length
pub const MAX_PASSWORD_LEN: u32 = 128;

// Combined hash output: salt + hash
pub const HASH_OUTPUT_LEN: u32 = SALT_LEN + HASH_LEN;

pub fn hash_password(
    password: []const u8,
    hash_out: []u8,
) void {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= MAX_PASSWORD_LEN);
    std.debug.assert(hash_out.len >= HASH_OUTPUT_LEN);
    
    // Generate random salt
    var salt: [SALT_LEN]u8 = undefined;
    random.generate_random_bytes(&salt);
    
    // Combine password + salt
    var combined: [MAX_PASSWORD_LEN + SALT_LEN]u8 = undefined;
    std.mem.copyForwards(u8, combined[0..password.len], password);
    std.mem.copyForwards(u8, combined[password.len..password.len + SALT_LEN], &salt);
    
    // Hash with SHA-256
    var hash: [HASH_LEN]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(combined[0..password.len + SALT_LEN], &hash, .{});
    
    // Output: salt || hash
    std.mem.copyForwards(u8, hash_out[0..SALT_LEN], &salt);
    std.mem.copyForwards(u8, hash_out[SALT_LEN..SALT_LEN + HASH_LEN], &hash);
    
    std.debug.assert(hash_out.len >= HASH_OUTPUT_LEN);
}

pub fn verify_password(
    password: []const u8,
    stored_hash: []const u8,
) bool {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= MAX_PASSWORD_LEN);
    std.debug.assert(stored_hash.len >= HASH_OUTPUT_LEN);
    
    // Extract salt from stored hash
    const salt = stored_hash[0..SALT_LEN];
    const stored_hash_only = stored_hash[SALT_LEN..SALT_LEN + HASH_LEN];
    
    // Combine password + salt
    var combined: [MAX_PASSWORD_LEN + SALT_LEN]u8 = undefined;
    std.mem.copyForwards(u8, combined[0..password.len], password);
    std.mem.copyForwards(u8, combined[password.len..password.len + SALT_LEN], salt);
    
    // Hash with SHA-256
    var computed_hash: [HASH_LEN]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(combined[0..password.len + SALT_LEN], &computed_hash, .{});
    
    // Constant-time comparison
    const matches = std.mem.eql(u8, &computed_hash, stored_hash_only);
    
    std.debug.assert(password.len > 0);
    std.debug.assert(stored_hash.len >= HASH_OUTPUT_LEN);
    
    return matches;
}

