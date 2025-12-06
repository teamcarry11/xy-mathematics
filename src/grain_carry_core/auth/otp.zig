// Magic email OTP (One-Time Password) for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Generates time-limited, single-use OTP tokens for email authentication

const std = @import("std");
const errors = @import("../utils/errors.zig");
const random = @import("../crypto/random.zig");

pub const OTP_LEN: u32 = 6;
pub const OTP_VALIDITY_SECONDS: u64 = 300;  // 5 minutes
pub const MAX_OTP_ATTEMPTS: u32 = 3;

pub const OtpToken = struct {
    code: [OTP_LEN]u8,
    expires_at: u64,  // Unix timestamp
    attempts: u32,
    used: bool,
};

pub fn generate_otp_code() [OTP_LEN]u8 {
    var code: [OTP_LEN]u8 = undefined;
    var i: u32 = 0;
    while (i < OTP_LEN) : (i += 1) {
        const digit = random.generate_random_u32() % 10;
        code[i] = '0' + @as(u8, @intCast(digit));
    }
    
    std.debug.assert(i == OTP_LEN);
    
    return code;
}

pub fn create_otp_token(timestamp: u64) OtpToken {
    std.debug.assert(timestamp > 0);
    
    const code = generate_otp_code();
    const expires_at = timestamp + OTP_VALIDITY_SECONDS;
    
    std.debug.assert(expires_at > timestamp);
    
    return OtpToken{
        .code = code,
        .expires_at = expires_at,
        .attempts = 0,
        .used = false,
    };
}

pub fn validate_otp(
    token: *OtpToken,
    code: []const u8,
    current_time: u64,
) bool {
    std.debug.assert(code.len == OTP_LEN);
    std.debug.assert(current_time > 0);
    std.debug.assert(token.expires_at > 0);
    
    if (token.used) {
        return false;
    }
    
    if (current_time > token.expires_at) {
        return false;
    }
    
    if (token.attempts >= MAX_OTP_ATTEMPTS) {
        return false;
    }
    
    token.attempts += 1;
    
    const matches = std.mem.eql(u8, &token.code, code[0..OTP_LEN]);
    
    if (matches) {
        token.used = true;
    }
    
    std.debug.assert(token.attempts <= MAX_OTP_ATTEMPTS);
    
    return matches;
}

pub fn is_otp_expired(token: *const OtpToken, current_time: u64) bool {
    std.debug.assert(current_time > 0);
    std.debug.assert(token.expires_at > 0);
    
    return current_time > token.expires_at;
}

