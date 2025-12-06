// Email/password authentication for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Handles email/password registration and login flows

const std = @import("std");
const errors = @import("../utils/errors.zig");
const email_validation = @import("../validation/email.zig");
const password_validation = @import("../validation/password.zig");
const hash = @import("../crypto/hash.zig");
const random = @import("../crypto/random.zig");

pub const MAX_USER_ID_LEN: u32 = 64;
pub const SESSION_TOKEN_LEN: u32 = 32;

pub const UserAccount = struct {
    user_id: [MAX_USER_ID_LEN]u8,
    user_id_len: u32,
    email: [email_validation.MAX_EMAIL_LEN]u8,
    email_len: u32,
    password_hash: [hash.HASH_OUTPUT_LEN]u8,
    created_at: u64,
};

pub fn create_user_account(
    email: []const u8,
    password: []const u8,
    timestamp: u64,
    account_out: *UserAccount,
) bool {
    std.debug.assert(email.len > 0);
    std.debug.assert(email.len <= email_validation.MAX_EMAIL_LEN);
    std.debug.assert(password.len >= password_validation.MIN_PASSWORD_LEN);
    std.debug.assert(password.len <= password_validation.MAX_PASSWORD_LEN);
    std.debug.assert(timestamp > 0);
    std.debug.assert(account_out != null);
    
    // Validate email
    if (!email_validation.validate_email(email)) {
        return false;
    }
    
    // Validate password
    if (!password_validation.validate_password(password)) {
        return false;
    }
    
    // Hash password
    hash.hash_password(password, &account_out.password_hash);
    
    // Store email
    std.mem.copyForwards(u8, &account_out.email, email);
    account_out.email_len = @intCast(email.len);
    
    // Generate user ID (simple: use email hash for now)
    var user_id_bytes: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(email, &user_id_bytes, .{});
    const user_id_hex_len: u32 = 32 * 2;
    var i: u32 = 0;
    while (i < user_id_hex_len and i < MAX_USER_ID_LEN) : (i += 2) {
        const byte_idx = i / 2;
        std.debug.assert(byte_idx < 32);
        const byte = user_id_bytes[byte_idx];
        const high_nibble = (byte >> 4) & 0x0F;
        const low_nibble = byte & 0x0F;
        account_out.user_id[i] = if (high_nibble < 10) '0' + @as(u8, @intCast(high_nibble)) else 'a' + @as(u8, @intCast(high_nibble - 10));
        if (i + 1 < MAX_USER_ID_LEN) {
            account_out.user_id[i + 1] = if (low_nibble < 10) '0' + @as(u8, @intCast(low_nibble)) else 'a' + @as(u8, @intCast(low_nibble - 10));
        }
    }
    account_out.user_id_len = if (user_id_hex_len > MAX_USER_ID_LEN) MAX_USER_ID_LEN else user_id_hex_len;
    
    account_out.created_at = timestamp;
    
    std.debug.assert(account_out.email_len > 0);
    std.debug.assert(account_out.user_id_len > 0);
    std.debug.assert(account_out.created_at > 0);
    
    return true;
}

pub fn authenticate_user(
    account: *const UserAccount,
    email: []const u8,
    password: []const u8,
) bool {
    std.debug.assert(email.len > 0);
    std.debug.assert(email.len <= email_validation.MAX_EMAIL_LEN);
    std.debug.assert(password.len >= password_validation.MIN_PASSWORD_LEN);
    std.debug.assert(password.len <= password_validation.MAX_PASSWORD_LEN);
    
    // Verify email matches
    const account_email = account.email[0..account.email_len];
    if (!std.mem.eql(u8, account_email, email)) {
        return false;
    }
    
    // Verify password
    const is_valid = hash.verify_password(password, &account.password_hash);
    
    std.debug.assert(!is_valid or account.email_len > 0);
    
    return is_valid;
}

pub fn generate_session_token() [SESSION_TOKEN_LEN]u8 {
    var token: [SESSION_TOKEN_LEN]u8 = undefined;
    random.generate_random_bytes(&token);
    
    std.debug.assert(token.len == SESSION_TOKEN_LEN);
    
    return token;
}

