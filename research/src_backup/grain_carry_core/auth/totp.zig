// TOTP (Time-based One-Time Password) 2FA for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Implements RFC 6238 TOTP algorithm (Google Authenticator compatible)

const std = @import("std");
const errors = @import("../utils/errors.zig");
const random = @import("../crypto/random.zig");

pub const TOTP_SECRET_LEN: u32 = 20;  // 160 bits (RFC 6238 recommends)
pub const TOTP_CODE_LEN: u32 = 6;  // 6-digit codes (most common)
pub const TOTP_TIME_STEP: u64 = 30;  // 30 seconds (RFC 6238 default)
pub const TOTP_WINDOW: u32 = 1;  // Accept codes within ±1 time step

pub fn generate_totp_secret() [TOTP_SECRET_LEN]u8 {
    var secret: [TOTP_SECRET_LEN]u8 = undefined;
    random.generate_random_bytes(&secret);
    
    std.debug.assert(secret.len == TOTP_SECRET_LEN);
    
    return secret;
}

// HMAC-SHA1 implementation for TOTP (RFC 2104, RFC 6238)
// Simplified implementation for fixed-size messages (8 bytes for TOTP counter)
fn hmac_sha1(key: []const u8, message: []const u8, output: []u8) void {
    std.debug.assert(key.len > 0);
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= 8);  // TOTP uses 8-byte counter
    std.debug.assert(output.len >= 20);  // SHA-1 output length
    
    // HMAC-SHA1: H(K XOR opad, H(K XOR ipad, message))
    const block_size: u32 = 64;  // SHA-1 block size
    var ipad_key: [block_size]u8 = undefined;
    var opad_key: [block_size]u8 = undefined;
    
    // Prepare key (pad or hash if > block_size)
    if (key.len > block_size) {
        // Hash key if too long
        var key_hash: [20]u8 = undefined;
        std.crypto.hash.sha1.Sha1.hash(key, &key_hash, .{});
        std.mem.set(u8, &ipad_key, 0);
        std.mem.copyForwards(u8, ipad_key[0..20], &key_hash);
    } else {
        std.mem.set(u8, &ipad_key, 0);
        std.mem.copyForwards(u8, ipad_key[0..key.len], key);
    }
    
    // Create ipad and opad keys
    var i: u32 = 0;
    while (i < block_size) : (i += 1) {
        opad_key[i] = ipad_key[i];
        ipad_key[i] ^= 0x36;  // ipad
        opad_key[i] ^= 0x5C;  // opad
    }
    
    // Inner hash: H(K XOR ipad || message)
    var inner_hash: [20]u8 = undefined;
    var inner_input: [block_size + 8]u8 = undefined;
    std.mem.copyForwards(u8, inner_input[0..block_size], &ipad_key);
    std.mem.copyForwards(u8, inner_input[block_size..block_size + message.len], message);
    std.crypto.hash.sha1.Sha1.hash(inner_input[0..block_size + message.len], &inner_hash, .{});
    
    // Outer hash: H(K XOR opad || inner_hash)
    var outer_input: [block_size + 20]u8 = undefined;
    std.mem.copyForwards(u8, outer_input[0..block_size], &opad_key);
    std.mem.copyForwards(u8, outer_input[block_size..block_size + 20], &inner_hash);
    std.crypto.hash.sha1.Sha1.hash(outer_input[0..block_size + 20], output[0..20], .{});
    
    std.debug.assert(output.len >= 20);
}

fn dynamic_truncate(hash: []const u8) u32 {
    std.debug.assert(hash.len >= 20);
    
    const offset = hash[19] & 0x0F;
    std.debug.assert(offset < 16);
    
    const binary = (@as(u32, hash[@intCast(offset)] & 0x7F) << 24) |
        (@as(u32, hash[@intCast(offset + 1)] & 0xFF) << 16) |
        (@as(u32, hash[@intCast(offset + 2)] & 0xFF) << 8) |
        (@as(u32, hash[@intCast(offset + 3)] & 0xFF));
    
    std.debug.assert(binary >= 0);
    
    return binary;
}

pub fn generate_totp_code(
    secret: []const u8,
    timestamp: u64,
) u32 {
    std.debug.assert(secret.len == TOTP_SECRET_LEN);
    std.debug.assert(timestamp > 0);
    
    const time_counter = timestamp / TOTP_TIME_STEP;
    
    // Convert time counter to 8-byte big-endian
    var counter_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &counter_bytes, time_counter, .big);
    
    // Compute HMAC-SHA1
    var hmac_output: [20]u8 = undefined;
    hmac_sha1(secret, &counter_bytes, &hmac_output);
    
    // Dynamic truncation
    const code_binary = dynamic_truncate(&hmac_output);
    const code = code_binary % 1000000;  // 6-digit code
    
    std.debug.assert(code < 1000000);
    
    return code;
}

pub fn validate_totp_code(
    secret: []const u8,
    code: u32,
    timestamp: u64,
) bool {
    std.debug.assert(secret.len == TOTP_SECRET_LEN);
    std.debug.assert(code < 1000000);
    std.debug.assert(timestamp > 0);
    
    // Check current time step
    const current_code = generate_totp_code(secret, timestamp);
    if (current_code == code) {
        return true;
    }
    
    // Check previous time step (within window)
    if (timestamp >= TOTP_TIME_STEP) {
        const prev_code = generate_totp_code(secret, timestamp - TOTP_TIME_STEP);
        if (prev_code == code) {
            return true;
        }
    }
    
    // Check next time step (within window)
    const next_code = generate_totp_code(secret, timestamp + TOTP_TIME_STEP);
    if (next_code == code) {
        return true;
    }
    
    return false;
}

pub fn format_totp_code(code: u32) [TOTP_CODE_LEN]u8 {
    std.debug.assert(code < 1000000);
    
    var formatted: [TOTP_CODE_LEN]u8 = undefined;
    var remaining = code;
    var i: u32 = TOTP_CODE_LEN;
    
    while (i > 0) {
        i -= 1;
        formatted[i] = '0' + @as(u8, @intCast(remaining % 10));
        remaining /= 10;
    }
    
    std.debug.assert(i == 0);
    std.debug.assert(formatted.len == TOTP_CODE_LEN);
    
    return formatted;
}

