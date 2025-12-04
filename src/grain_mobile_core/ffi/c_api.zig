// C-compatible FFI exports for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Password Requirements:
// - Minimum 32 characters (security best practice)
// - Recommended: Use 1Password "Memorable Password" generator
// - Format: Words separated by numbers/symbols (e.g., "word1!word2@word3#word4")

const std = @import("std");
const email_validation = @import("../validation/email.zig");
const password_validation = @import("../validation/password.zig");
const hash = @import("../crypto/hash.zig");
const otp = @import("../auth/otp.zig");
const totp = @import("../auth/totp.zig");
const email_auth = @import("../auth/email.zig");
const jwt = @import("../auth/jwt.zig");
const errors = @import("../utils/errors.zig");

// C-compatible return codes
pub const RESULT_OK: c_int = 0;
pub const RESULT_ERROR: c_int = 1;

// Export C-compatible email validation function
export fn grain_mobile_validate_email(
    email_ptr: [*c]const u8,
    email_len: u32,
) c_int {
    std.debug.assert(email_ptr != null);
    std.debug.assert(email_len > 0);
    std.debug.assert(email_len <= email_validation.MAX_EMAIL_LEN);
    
    const email = email_ptr[0..email_len];
    const is_valid = email_validation.validate_email(email);
    
    std.debug.assert(email.len == email_len);
    
    return if (is_valid) RESULT_OK else RESULT_ERROR;
}

// Export C-compatible password validation function
export fn grain_mobile_validate_password(
    password_ptr: [*c]const u8,
    password_len: u32,
) c_int {
    std.debug.assert(password_ptr != null);
    std.debug.assert(password_len > 0);
    std.debug.assert(password_len <= password_validation.MAX_PASSWORD_LEN);
    
    const password = password_ptr[0..password_len];
    const is_valid = password_validation.validate_password(password);
    
    std.debug.assert(password.len == password_len);
    
    return if (is_valid) RESULT_OK else RESULT_ERROR;
}

// Export C-compatible password strength function
export fn grain_mobile_get_password_strength(
    password_ptr: [*c]const u8,
    password_len: u32,
) c_int {
    std.debug.assert(password_ptr != null);
    std.debug.assert(password_len > 0);
    std.debug.assert(password_len <= password_validation.MAX_PASSWORD_LEN);
    
    const password = password_ptr[0..password_len];
    const strength = password_validation.get_password_strength(password);
    
    std.debug.assert(password.len == password_len);
    
    return switch (strength) {
        .weak => 0,
        .medium => 1,
        .strong => 2,
    };
}

// Export C-compatible password hashing function
export fn grain_mobile_hash_password(
    password_ptr: [*c]const u8,
    password_len: u32,
    hash_out: [*c]u8,
) c_int {
    std.debug.assert(password_ptr != null);
    std.debug.assert(password_len > 0);
    std.debug.assert(password_len <= password_validation.MAX_PASSWORD_LEN);
    std.debug.assert(hash_out != null);
    
    const password = password_ptr[0..password_len];
    hash.hash_password(password, hash_out[0..hash.HASH_OUTPUT_LEN]);
    
    std.debug.assert(password.len == password_len);
    
    return RESULT_OK;
}

// Export C-compatible password verification function
export fn grain_mobile_verify_password(
    password_ptr: [*c]const u8,
    password_len: u32,
    stored_hash_ptr: [*c]const u8,
) c_int {
    std.debug.assert(password_ptr != null);
    std.debug.assert(password_len > 0);
    std.debug.assert(password_len <= password_validation.MAX_PASSWORD_LEN);
    std.debug.assert(stored_hash_ptr != null);
    
    const password = password_ptr[0..password_len];
    const stored_hash = stored_hash_ptr[0..hash.HASH_OUTPUT_LEN];
    const is_valid = hash.verify_password(password, stored_hash);
    
    std.debug.assert(password.len == password_len);
    
    return if (is_valid) RESULT_OK else RESULT_ERROR;
}

// Export C-compatible OTP generation function
export fn grain_mobile_generate_otp(
    timestamp: u64,
    code_out: [*c]u8,
) c_int {
    std.debug.assert(timestamp > 0);
    std.debug.assert(code_out != null);
    
    const token = otp.create_otp_token(timestamp);
    std.mem.copyForwards(u8, code_out[0..otp.OTP_LEN], &token.code);
    
    std.debug.assert(token.expires_at > timestamp);
    
    return RESULT_OK;
}

// Export C-compatible TOTP secret generation function
export fn grain_mobile_generate_totp_secret(
    secret_out: [*c]u8,
) c_int {
    std.debug.assert(secret_out != null);
    
    const secret = totp.generate_totp_secret();
    std.mem.copyForwards(u8, secret_out[0..totp.TOTP_SECRET_LEN], &secret);
    
    std.debug.assert(secret.len == totp.TOTP_SECRET_LEN);
    
    return RESULT_OK;
}

// Export C-compatible TOTP code generation function
export fn grain_mobile_generate_totp_code(
    secret_ptr: [*c]const u8,
    timestamp: u64,
) u32 {
    std.debug.assert(secret_ptr != null);
    std.debug.assert(timestamp > 0);
    
    const secret = secret_ptr[0..totp.TOTP_SECRET_LEN];
    const code = totp.generate_totp_code(secret, timestamp);
    
    std.debug.assert(code < 1000000);
    
    return code;
}

// Export C-compatible TOTP code validation function
export fn grain_mobile_validate_totp_code(
    secret_ptr: [*c]const u8,
    code: u32,
    timestamp: u64,
) c_int {
    std.debug.assert(secret_ptr != null);
    std.debug.assert(code < 1000000);
    std.debug.assert(timestamp > 0);
    
    const secret = secret_ptr[0..totp.TOTP_SECRET_LEN];
    const is_valid = totp.validate_totp_code(secret, code, timestamp);
    
    return if (is_valid) RESULT_OK else RESULT_ERROR;
}

// Export C-compatible user account creation function
export fn grain_mobile_create_user_account(
    email_ptr: [*c]const u8,
    email_len: u32,
    password_ptr: [*c]const u8,
    password_len: u32,
    timestamp: u64,
    account_out: *email_auth.UserAccount,
) c_int {
    std.debug.assert(email_ptr != null);
    std.debug.assert(email_len > 0);
    std.debug.assert(email_len <= email_validation.MAX_EMAIL_LEN);
    std.debug.assert(password_ptr != null);
    std.debug.assert(password_len >= password_validation.MIN_PASSWORD_LEN);
    std.debug.assert(password_len <= password_validation.MAX_PASSWORD_LEN);
    std.debug.assert(timestamp > 0);
    std.debug.assert(account_out != null);
    
    const email = email_ptr[0..email_len];
    const password = password_ptr[0..password_len];
    const success = email_auth.create_user_account(email, password, timestamp, account_out);
    
    std.debug.assert(email.len == email_len);
    std.debug.assert(password.len == password_len);
    
    return if (success) RESULT_OK else RESULT_ERROR;
}

// Export C-compatible user authentication function
export fn grain_mobile_authenticate_user(
    account: *const email_auth.UserAccount,
    email_ptr: [*c]const u8,
    email_len: u32,
    password_ptr: [*c]const u8,
    password_len: u32,
) c_int {
    std.debug.assert(account != null);
    std.debug.assert(email_ptr != null);
    std.debug.assert(email_len > 0);
    std.debug.assert(password_ptr != null);
    std.debug.assert(password_len > 0);
    
    const email = email_ptr[0..email_len];
    const password = password_ptr[0..password_len];
    const is_valid = email_auth.authenticate_user(account, email, password);
    
    std.debug.assert(email.len == email_len);
    std.debug.assert(password.len == password_len);
    
    return if (is_valid) RESULT_OK else RESULT_ERROR;
}

// Export C-compatible session token generation function
export fn grain_mobile_generate_session_token(
    token_out: [*c]u8,
) c_int {
    std.debug.assert(token_out != null);
    
    const token = email_auth.generate_session_token();
    std.mem.copyForwards(u8, token_out[0..email_auth.SESSION_TOKEN_LEN], &token);
    
    std.debug.assert(token.len == email_auth.SESSION_TOKEN_LEN);
    
    return RESULT_OK;
}

// Export C-compatible JWT creation function
export fn grain_mobile_create_jwt(
    user_id_ptr: [*c]const u8,
    user_id_len: u32,
    exp: u64,
    iat: u64,
    secret_ptr: [*c]const u8,
    secret_len: u32,
    token_out: [*c]u8,
    token_out_len: *u32,
) c_int {
    std.debug.assert(user_id_ptr != null);
    std.debug.assert(user_id_len > 0);
    std.debug.assert(user_id_len <= 64);
    std.debug.assert(exp > 0);
    std.debug.assert(secret_ptr != null);
    std.debug.assert(secret_len > 0);
    std.debug.assert(token_out != null);
    std.debug.assert(token_out_len != null);
    
    var claims: jwt.JwtClaims = undefined;
    std.mem.copyForwards(u8, &claims.user_id, user_id_ptr[0..user_id_len]);
    claims.user_id_len = user_id_len;
    claims.exp = exp;
    claims.iat = iat;
    
    const secret = secret_ptr[0..secret_len];
    var token_buffer: [jwt.MAX_JWT_LEN]u8 = undefined;
    const token_len = jwt.create_jwt(&claims, secret, &token_buffer);
    
    std.mem.copyForwards(u8, token_out[0..token_len], token_buffer[0..token_len]);
    token_out_len.* = token_len;
    
    std.debug.assert(token_len > 0);
    std.debug.assert(token_len <= jwt.MAX_JWT_LEN);
    
    return RESULT_OK;
}

// Export C-compatible JWT validation function
export fn grain_mobile_validate_jwt(
    token_ptr: [*c]const u8,
    token_len: u32,
    secret_ptr: [*c]const u8,
    secret_len: u32,
    current_time: u64,
    claims_out: *jwt.JwtClaims,
) c_int {
    std.debug.assert(token_ptr != null);
    std.debug.assert(token_len > 0);
    std.debug.assert(token_len <= jwt.MAX_JWT_LEN);
    std.debug.assert(secret_ptr != null);
    std.debug.assert(secret_len > 0);
    std.debug.assert(current_time > 0);
    std.debug.assert(claims_out != null);
    
    const token = token_ptr[0..token_len];
    const secret = secret_ptr[0..secret_len];
    const is_valid = jwt.validate_jwt(token, secret, current_time, claims_out);
    
    std.debug.assert(token.len == token_len);
    
    return if (is_valid) RESULT_OK else RESULT_ERROR;
}

