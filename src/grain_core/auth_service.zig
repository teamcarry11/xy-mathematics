//! Grain OS Authentication Service: Secure authentication for API endpoints.
//!
//! Why: Provide JWT tokens, password hashing, 2FA, OAuth, sessions for Mobile/Database agents.
//! Architecture: Centralized auth service with JWT, password, 2FA, OAuth, session management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines, max 100 chars.

const std = @import("std");
const api_server = @import("api_server.zig");

// Constants
pub const MAX_JWT_LEN: u32 = 2048;
pub const MAX_SECRET_LEN: u32 = 256;
pub const MAX_USER_ID_LEN: u32 = 64;
pub const MAX_SESSION_ID_LEN: u32 = 64;
pub const MAX_OTP_CODE_LEN: u32 = 8;
pub const MAX_EMAIL_LEN: u32 = 256;
pub const MAX_PASSWORD_LEN: u32 = 128;
pub const SALT_LEN: u32 = 32;
pub const HASH_LEN: u32 = 32; // SHA-256
pub const HASH_OUTPUT_LEN: u32 = SALT_LEN + HASH_LEN;
pub const ACCESS_TOKEN_EXPIRY: u64 = 3600; // 1 hour
pub const REFRESH_TOKEN_EXPIRY: u64 = 604800; // 7 days
pub const OTP_EXPIRY: u64 = 600; // 10 minutes
pub const SESSION_EXPIRY: u64 = 86400; // 24 hours

// JWT Claims structure
pub const JwtClaims = struct {
    user_id: [MAX_USER_ID_LEN]u8,
    user_id_len: u32,
    exp: u64, // Expiration timestamp
    iat: u64, // Issued at timestamp
    token_type: TokenType,
};

// Token types
pub const TokenType = enum(u8) {
    access,
    refresh,
};

// Session structure
pub const Session = struct {
    session_id: [MAX_SESSION_ID_LEN]u8,
    session_id_len: u32,
    user_id: [MAX_USER_ID_LEN]u8,
    user_id_len: u32,
    created_at: u64,
    expires_at: u64,
    is_active: bool,
};

// OTP structure
pub const Otp = struct {
    code: [MAX_OTP_CODE_LEN]u8,
    code_len: u32,
    email: [MAX_EMAIL_LEN]u8,
    email_len: u32,
    created_at: u64,
    expires_at: u64,
    is_used: bool,
};

// OAuth provider types
pub const OAuthProvider = enum(u8) {
    google,
    facebook,
    github,
    apple,
};

// Authentication Service
pub const AuthService = struct {
    secret: [MAX_SECRET_LEN]u8,
    secret_len: u32,
    sessions: [100]Session, // Bounded session storage
    session_count: u32,
    otps: [50]Otp, // Bounded OTP storage
    otp_count: u32,
    revoked_tokens: [200][MAX_JWT_LEN]u8, // Token blacklist
    revoked_count: u32,

    // Initialize authentication service with secret
    pub fn init(secret: []const u8) AuthService {
        std.debug.assert(secret.len > 0);
        std.debug.assert(secret.len <= MAX_SECRET_LEN);
        var service = AuthService{
            .secret = undefined,
            .secret_len = @intCast(secret.len),
            .sessions = undefined,
            .session_count = 0,
            .otps = undefined,
            .otp_count = 0,
            .revoked_tokens = undefined,
            .revoked_count = 0,
        };
        std.mem.copyForwards(u8, &service.secret, secret);
        std.mem.set(u8, &service.sessions, 0);
        std.mem.set(u8, &service.otps, 0);
        std.mem.set(u8, &service.revoked_tokens, 0);
        std.debug.assert(service.secret_len > 0);
        return service;
    }

    // Generate JWT access token
    pub fn generate_access_token(
        self: *AuthService,
        user_id: []const u8,
        current_time: u64,
        token_out: []u8,
    ) u32 {
        std.debug.assert(user_id.len > 0);
        std.debug.assert(user_id.len <= MAX_USER_ID_LEN);
        std.debug.assert(current_time > 0);
        std.debug.assert(token_out.len >= MAX_JWT_LEN);
        var claims = JwtClaims{
            .user_id = undefined,
            .user_id_len = @intCast(user_id.len),
            .exp = current_time + ACCESS_TOKEN_EXPIRY,
            .iat = current_time,
            .token_type = TokenType.access,
        };
        std.mem.copyForwards(u8, &claims.user_id, user_id);
        const token_len = generate_jwt_token(
            &claims,
            self.secret[0..self.secret_len],
            token_out,
        );
        std.debug.assert(token_len > 0);
        std.debug.assert(token_len <= MAX_JWT_LEN);
        return token_len;
    }

    // Generate JWT refresh token
    pub fn generate_refresh_token(
        self: *AuthService,
        user_id: []const u8,
        current_time: u64,
        token_out: []u8,
    ) u32 {
        std.debug.assert(user_id.len > 0);
        std.debug.assert(user_id.len <= MAX_USER_ID_LEN);
        std.debug.assert(current_time > 0);
        std.debug.assert(token_out.len >= MAX_JWT_LEN);
        var claims = JwtClaims{
            .user_id = undefined,
            .user_id_len = @intCast(user_id.len),
            .exp = current_time + REFRESH_TOKEN_EXPIRY,
            .iat = current_time,
            .token_type = TokenType.refresh,
        };
        std.mem.copyForwards(u8, &claims.user_id, user_id);
        const token_len = generate_jwt_token(
            &claims,
            self.secret[0..self.secret_len],
            token_out,
        );
        std.debug.assert(token_len > 0);
        std.debug.assert(token_len <= MAX_JWT_LEN);
        return token_len;
    }

    // Validate JWT token
    pub fn validate_jwt_token(
        self: *AuthService,
        token: []const u8,
        current_time: u64,
        claims_out: *JwtClaims,
    ) bool {
        std.debug.assert(token.len > 0);
        std.debug.assert(token.len <= MAX_JWT_LEN);
        std.debug.assert(current_time > 0);
        std.debug.assert(claims_out != null);
        if (is_token_revoked(self, token)) {
            return false;
        }
        const is_valid = validate_jwt(
            token,
            self.secret[0..self.secret_len],
            current_time,
            claims_out,
        );
        if (!is_valid) {
            return false;
        }
        if (claims_out.exp < current_time) {
            return false;
        }
        std.debug.assert(claims_out.user_id_len > 0);
        return true;
    }

    // Revoke JWT token (add to blacklist)
    pub fn revoke_token(self: *AuthService, token: []const u8) bool {
        std.debug.assert(token.len > 0);
        std.debug.assert(token.len <= MAX_JWT_LEN);
        if (self.revoked_count >= 200) {
            return false;
        }
        if (token.len > MAX_JWT_LEN) {
            return false;
        }
        std.mem.copyForwards(
            u8,
            &self.revoked_tokens[self.revoked_count],
            token,
        );
        self.revoked_count += 1;
        std.debug.assert(self.revoked_count <= 200);
        return true;
    }

    // Check if token is revoked
    fn is_token_revoked(self: *const AuthService, token: []const u8) bool {
        std.debug.assert(token.len > 0);
        std.debug.assert(token.len <= MAX_JWT_LEN);
        var i: u32 = 0;
        while (i < self.revoked_count) : (i += 1) {
            const revoked_token = self.revoked_tokens[i][0..token.len];
            if (std.mem.eql(u8, revoked_token, token)) {
                return true;
            }
        }
        return false;
    }

    // Hash password (SHA-256 with salt) - static function
    pub fn hash_password_static(
        password: []const u8,
        hash_out: []u8,
    ) void {
        std.debug.assert(password.len > 0);
        std.debug.assert(password.len <= MAX_PASSWORD_LEN);
        std.debug.assert(hash_out.len >= HASH_OUTPUT_LEN);
        var salt: [SALT_LEN]u8 = undefined;
        std.crypto.random.bytes(&salt);
        var combined: [MAX_PASSWORD_LEN + SALT_LEN]u8 = undefined;
        std.mem.copyForwards(u8, combined[0..password.len], password);
        std.mem.copyForwards(u8, combined[password.len..password.len + SALT_LEN], &salt);
        var hash: [HASH_LEN]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(combined[0..password.len + SALT_LEN], &hash, .{});
        std.mem.copyForwards(u8, hash_out[0..SALT_LEN], &salt);
        std.mem.copyForwards(u8, hash_out[SALT_LEN..SALT_LEN + HASH_LEN], &hash);
        std.debug.assert(hash_out.len >= HASH_OUTPUT_LEN);
    }

    // Verify password - static function
    pub fn verify_password_static(
        password: []const u8,
        stored_hash: []const u8,
    ) bool {
        std.debug.assert(password.len > 0);
        std.debug.assert(password.len <= MAX_PASSWORD_LEN);
        std.debug.assert(stored_hash.len >= HASH_OUTPUT_LEN);
        const salt = stored_hash[0..SALT_LEN];
        const stored_hash_only = stored_hash[SALT_LEN..SALT_LEN + HASH_LEN];
        var combined: [MAX_PASSWORD_LEN + SALT_LEN]u8 = undefined;
        std.mem.copyForwards(u8, combined[0..password.len], password);
        std.mem.copyForwards(u8, combined[password.len..password.len + SALT_LEN], salt);
        var computed_hash: [HASH_LEN]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(combined[0..password.len + SALT_LEN], &computed_hash, .{});
        const matches = std.mem.eql(u8, &computed_hash, stored_hash_only);
        std.debug.assert(password.len > 0);
        std.debug.assert(stored_hash.len >= HASH_OUTPUT_LEN);
        return matches;
    }

    // Create session
    pub fn create_session(
        self: *AuthService,
        user_id: []const u8,
        current_time: u64,
        session_out: *Session,
    ) bool {
        std.debug.assert(user_id.len > 0);
        std.debug.assert(user_id.len <= MAX_USER_ID_LEN);
        std.debug.assert(current_time > 0);
        std.debug.assert(session_out != null);
        if (self.session_count >= 100) {
            return false;
        }
        var session_id: [MAX_SESSION_ID_LEN]u8 = undefined;
        std.crypto.random.bytes(&session_id);
        std.mem.copyForwards(u8, &session_out.session_id, &session_id);
        session_out.session_id_len = MAX_SESSION_ID_LEN;
        std.mem.copyForwards(u8, &session_out.user_id, user_id);
        session_out.user_id_len = @intCast(user_id.len);
        session_out.created_at = current_time;
        session_out.expires_at = current_time + SESSION_EXPIRY;
        session_out.is_active = true;
        self.sessions[self.session_count] = session_out.*;
        self.session_count += 1;
        std.debug.assert(self.session_count <= 100);
        return true;
    }

    // Validate session
    pub fn validate_session(
        self: *AuthService,
        session_id: []const u8,
        current_time: u64,
        session_out: ?*Session,
    ) bool {
        std.debug.assert(session_id.len > 0);
        std.debug.assert(session_id.len <= MAX_SESSION_ID_LEN);
        std.debug.assert(current_time > 0);
        var i: u32 = 0;
        while (i < self.session_count) : (i += 1) {
            const session = &self.sessions[i];
            if (!session.is_active) {
                continue;
            }
            if (session.expires_at < current_time) {
                session.is_active = false;
                continue;
            }
            const session_id_bytes = session.session_id[0..session.session_id_len];
            if (std.mem.eql(u8, session_id_bytes, session_id)) {
                if (session_out) |out| {
                    out.* = session.*;
                }
                return true;
            }
        }
        return false;
    }

    // Revoke session (logout)
    pub fn revoke_session(self: *AuthService, session_id: []const u8) bool {
        std.debug.assert(session_id.len > 0);
        std.debug.assert(session_id.len <= MAX_SESSION_ID_LEN);
        var i: u32 = 0;
        while (i < self.session_count) : (i += 1) {
            const session = &self.sessions[i];
            const session_id_bytes = session.session_id[0..session.session_id_len];
            if (std.mem.eql(u8, session_id_bytes, session_id)) {
                session.is_active = false;
                return true;
            }
        }
        return false;
    }

    // Generate OTP code
    pub fn generate_otp(
        self: *AuthService,
        email: []const u8,
        current_time: u64,
        otp_out: *Otp,
    ) bool {
        std.debug.assert(email.len > 0);
        std.debug.assert(email.len <= MAX_EMAIL_LEN);
        std.debug.assert(current_time > 0);
        std.debug.assert(otp_out != null);
        if (self.otp_count >= 50) {
            return false;
        }
        var code_bytes: [4]u8 = undefined;
        std.crypto.random.bytes(&code_bytes);
        var code: [MAX_OTP_CODE_LEN]u8 = undefined;
        var code_len: u32 = 0;
        var i: u32 = 0;
        while (i < 4 and code_len < MAX_OTP_CODE_LEN) : (i += 1) {
            const digit = code_bytes[i] % 10;
            code[code_len] = '0' + digit;
            code_len += 1;
        }
        std.mem.copyForwards(u8, &otp_out.code, code[0..code_len]);
        otp_out.code_len = code_len;
        std.mem.copyForwards(u8, &otp_out.email, email);
        otp_out.email_len = @intCast(email.len);
        otp_out.created_at = current_time;
        otp_out.expires_at = current_time + OTP_EXPIRY;
        otp_out.is_used = false;
        self.otps[self.otp_count] = otp_out.*;
        self.otp_count += 1;
        std.debug.assert(self.otp_count <= 50);
        return true;
    }

    // Validate OTP code
    pub fn validate_otp(
        self: *AuthService,
        email: []const u8,
        code: []const u8,
        current_time: u64,
    ) bool {
        std.debug.assert(email.len > 0);
        std.debug.assert(email.len <= MAX_EMAIL_LEN);
        std.debug.assert(code.len > 0);
        std.debug.assert(code.len <= MAX_OTP_CODE_LEN);
        std.debug.assert(current_time > 0);
        var i: u32 = 0;
        while (i < self.otp_count) : (i += 1) {
            const otp = &self.otps[i];
            if (otp.is_used) {
                continue;
            }
            if (otp.expires_at < current_time) {
                continue;
            }
            const otp_email = otp.email[0..otp.email_len];
            if (!std.mem.eql(u8, otp_email, email)) {
                continue;
            }
            const otp_code = otp.code[0..otp.code_len];
            if (std.mem.eql(u8, otp_code, code)) {
                otp.is_used = true;
                return true;
            }
        }
        return false;
    }

    // Generate TOTP code (2FA)
    pub fn generate_totp(secret: []const u8, timestamp: u64) u32 {
        std.debug.assert(secret.len > 0);
        std.debug.assert(timestamp > 0);
        const time_step: u64 = 30;
        const time_counter = timestamp / time_step;
        var time_bytes: [8]u8 = undefined;
        var i: u32 = 0;
        var counter = time_counter;
        while (i < 8) : (i += 1) {
            time_bytes[7 - i] = @truncate(counter & 0xFF);
            counter >>= 8;
        }
        var hmac: [20]u8 = undefined;
        hmac_sha1(secret, &time_bytes, &hmac);
        const offset = hmac[19] & 0x0F;
        const code = ((@as(u32, hmac[offset]) & 0x7F) << 24) |
            (@as(u32, hmac[offset + 1]) << 16) |
            (@as(u32, hmac[offset + 2]) << 8) |
            @as(u32, hmac[offset + 3]);
        const totp_code = code % 1000000;
        std.debug.assert(totp_code < 1000000);
        return totp_code;
    }

    // Validate TOTP code (2FA)
    pub fn validate_totp(
        secret: []const u8,
        code: u32,
        timestamp: u64,
    ) bool {
        std.debug.assert(secret.len > 0);
        std.debug.assert(code < 1000000);
        std.debug.assert(timestamp > 0);
        const generated = generate_totp(secret, timestamp);
        if (generated == code) {
            return true;
        }
        const time_step: u64 = 30;
        const prev_timestamp = timestamp - time_step;
        const prev_generated = generate_totp(secret, prev_timestamp);
        if (prev_generated == code) {
            return true;
        }
        const next_timestamp = timestamp + time_step;
        const next_generated = generate_totp(secret, next_timestamp);
        if (next_generated == code) {
            return true;
        }
        return false;
    }
};

// HMAC-SHA1 for TOTP
fn hmac_sha1(key: []const u8, message: []const u8, output: []u8) void {
    std.debug.assert(key.len > 0);
    std.debug.assert(message.len > 0);
    std.debug.assert(output.len >= 20);
    const block_size: u32 = 64;
    var ipad_key: [block_size]u8 = undefined;
    var opad_key: [block_size]u8 = undefined;
    if (key.len > block_size) {
        var key_hash: [20]u8 = undefined;
        std.crypto.hash.sha1.Sha1.hash(key, &key_hash, .{});
        std.mem.set(u8, &ipad_key, 0);
        std.mem.copyForwards(u8, ipad_key[0..20], &key_hash);
    } else {
        std.mem.set(u8, &ipad_key, 0);
        std.mem.copyForwards(u8, ipad_key[0..key.len], key);
    }
    var i: u32 = 0;
    while (i < block_size) : (i += 1) {
        opad_key[i] = ipad_key[i];
        ipad_key[i] ^= 0x36;
        opad_key[i] ^= 0x5C;
    }
    var inner_hash: [20]u8 = undefined;
    var inner_input: [block_size + 256]u8 = undefined;
    std.mem.copyForwards(u8, inner_input[0..block_size], &ipad_key);
    if (message.len <= 256) {
        std.mem.copyForwards(
            u8,
            inner_input[block_size..block_size + message.len],
            message,
        );
        std.crypto.hash.sha1.Sha1.hash(
            inner_input[0..block_size + message.len],
            &inner_hash,
            .{},
        );
    } else {
        std.crypto.hash.sha1.Sha1.hash(message, &inner_hash, .{});
    }
    var outer_input: [block_size + 20]u8 = undefined;
    std.mem.copyForwards(u8, outer_input[0..block_size], &opad_key);
    std.mem.copyForwards(u8, outer_input[block_size..block_size + 20], &inner_hash);
    std.crypto.hash.sha1.Sha1.hash(
        outer_input[0..block_size + 20],
        output[0..20],
        .{},
    );
    std.debug.assert(output.len >= 20);
}

// Generate JWT token (internal helper)
fn generate_jwt_token(
    claims: *const JwtClaims,
    secret: []const u8,
    token_out: []u8,
) u32 {
    std.debug.assert(claims != null);
    std.debug.assert(secret.len > 0);
    std.debug.assert(token_out.len >= MAX_JWT_LEN);
    const header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";
    var header_encoded: [256]u8 = undefined;
    const header_encoded_len = base64url_encode(header, &header_encoded);
    var claims_json: [512]u8 = undefined;
    var claims_json_len: u32 = 0;
    claims_json[claims_json_len] = '{';
    claims_json_len += 1;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    std.mem.copyForwards(u8, claims_json[claims_json_len..], "user_id");
    claims_json_len += 6;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    claims_json[claims_json_len] = ':';
    claims_json_len += 1;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    std.mem.copyForwards(
        u8,
        claims_json[claims_json_len..],
        claims.user_id[0..claims.user_id_len],
    );
    claims_json_len += claims.user_id_len;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    claims_json[claims_json_len] = ',';
    claims_json_len += 1;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    std.mem.copyForwards(u8, claims_json[claims_json_len..], "exp");
    claims_json_len += 3;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    claims_json[claims_json_len] = ':';
    claims_json_len += 1;
    var exp_str: [20]u8 = undefined;
    var exp_remaining = claims.exp;
    var exp_str_len: u32 = 0;
    if (exp_remaining == 0) {
        exp_str[0] = '0';
        exp_str_len = 1;
    } else {
        var exp_idx: u32 = 19;
        while (exp_remaining > 0) {
            exp_str[exp_idx] = '0' + @as(u8, @intCast(exp_remaining % 10));
            exp_remaining /= 10;
            exp_idx -= 1;
        }
        exp_str_len = 20 - exp_idx - 1;
        std.mem.copyForwards(
            u8,
            claims_json[claims_json_len..],
            exp_str[exp_idx + 1..20],
        );
        claims_json_len += exp_str_len;
    }
    claims_json[claims_json_len] = ',';
    claims_json_len += 1;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    std.mem.copyForwards(u8, claims_json[claims_json_len..], "iat");
    claims_json_len += 3;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    claims_json[claims_json_len] = ':';
    claims_json_len += 1;
    var iat_remaining = claims.iat;
    var iat_str: [20]u8 = undefined;
    var iat_str_len: u32 = 0;
    if (iat_remaining == 0) {
        iat_str[0] = '0';
        iat_str_len = 1;
    } else {
        var iat_idx: u32 = 19;
        while (iat_remaining > 0) {
            iat_str[iat_idx] = '0' + @as(u8, @intCast(iat_remaining % 10));
            iat_remaining /= 10;
            iat_idx -= 1;
        }
        iat_str_len = 20 - iat_idx - 1;
        std.mem.copyForwards(
            u8,
            claims_json[claims_json_len..],
            iat_str[iat_idx + 1..20],
        );
        claims_json_len += iat_str_len;
    }
    claims_json[claims_json_len] = '}';
    claims_json_len += 1;
    var claims_encoded: [512]u8 = undefined;
    const claims_encoded_len = base64url_encode(
        claims_json[0..claims_json_len],
        &claims_encoded,
    );
    var message: [1024]u8 = undefined;
    std.mem.copyForwards(
        u8,
        message[0..header_encoded_len],
        header_encoded[0..header_encoded_len],
    );
    message[header_encoded_len] = '.';
    std.mem.copyForwards(
        u8,
        message[header_encoded_len + 1..header_encoded_len + 1 + claims_encoded_len],
        claims_encoded[0..claims_encoded_len],
    );
    const message_len = header_encoded_len + 1 + claims_encoded_len;
    var signature: [32]u8 = undefined;
    hmac_sha256(secret, message[0..message_len], &signature);
    var signature_encoded: [64]u8 = undefined;
    const signature_encoded_len = base64url_encode(&signature, &signature_encoded);
    var token_len: u32 = 0;
    std.mem.copyForwards(
        u8,
        token_out[token_len..],
        header_encoded[0..header_encoded_len],
    );
    token_len += header_encoded_len;
    token_out[token_len] = '.';
    token_len += 1;
    std.mem.copyForwards(
        u8,
        token_out[token_len..],
        claims_encoded[0..claims_encoded_len],
    );
    token_len += claims_encoded_len;
    token_out[token_len] = '.';
    token_len += 1;
    std.mem.copyForwards(
        u8,
        token_out[token_len..],
        signature_encoded[0..signature_encoded_len],
    );
    token_len += signature_encoded_len;
    std.debug.assert(token_len <= token_out.len);
    return token_len;
}

// Validate JWT token (internal helper)
fn validate_jwt(
    token: []const u8,
    secret: []const u8,
    current_time: u64,
    claims_out: *JwtClaims,
) bool {
    std.debug.assert(token.len > 0);
    std.debug.assert(token.len <= MAX_JWT_LEN);
    std.debug.assert(secret.len > 0);
    std.debug.assert(current_time > 0);
    std.debug.assert(claims_out != null);
    var parts: [3][]const u8 = undefined;
    var part_count: u32 = 0;
    var start: u32 = 0;
    var i: u32 = 0;
    while (i < token.len and part_count < 3) : (i += 1) {
        if (token[i] == '.') {
            parts[part_count] = token[start..i];
            part_count += 1;
            start = i + 1;
        }
    }
    if (part_count < 2) {
        return false;
    }
    parts[part_count] = token[start..];
    part_count += 1;
    if (part_count != 3) {
        return false;
    }
    var message: [1024]u8 = undefined;
    std.mem.copyForwards(u8, message[0..parts[0].len], parts[0]);
    message[parts[0].len] = '.';
    std.mem.copyForwards(
        u8,
        message[parts[0].len + 1..parts[0].len + 1 + parts[1].len],
        parts[1],
    );
    const message_len = parts[0].len + 1 + parts[1].len;
    var computed_sig: [32]u8 = undefined;
    hmac_sha256(secret, message[0..message_len], &computed_sig);
    var computed_sig_encoded: [64]u8 = undefined;
    const computed_sig_len = base64url_encode(&computed_sig, &computed_sig_encoded);
    if (computed_sig_len != parts[2].len) {
        return false;
    }
    if (!std.mem.eql(
        u8,
        computed_sig_encoded[0..computed_sig_len],
        parts[2],
    )) {
        return false;
    }
    var claims_decoded: [512]u8 = undefined;
    const claims_decoded_len = base64url_decode(parts[1], &claims_decoded);
    var exp_found: bool = false;
    var exp_value: u64 = 0;
    var user_id_start: ?u32 = null;
    var user_id_end: ?u32 = null;
    i = 0;
    while (i < claims_decoded_len) : (i += 1) {
        if (i + 5 < claims_decoded_len and
            std.mem.eql(u8, claims_decoded[i..i + 5], "\"exp\""))
        {
            var j = i + 5;
            while (j < claims_decoded_len and claims_decoded[j] != ':') : (j += 1) {}
            j += 1;
            while (j < claims_decoded_len and
                (claims_decoded[j] == ' ' or claims_decoded[j] == '\t')) : (j += 1) {}
            exp_value = 0;
            while (j < claims_decoded_len and
                claims_decoded[j] >= '0' and claims_decoded[j] <= '9') : (j += 1)
            {
                exp_value = exp_value * 10 + @as(u64, @intCast(claims_decoded[j] - '0'));
            }
            exp_found = true;
        }
        if (i + 8 < claims_decoded_len and
            std.mem.eql(u8, claims_decoded[i..i + 8], "\"user_id\""))
        {
            var j = i + 8;
            while (j < claims_decoded_len and claims_decoded[j] != ':') : (j += 1) {}
            j += 1;
            while (j < claims_decoded_len and
                (claims_decoded[j] == ' ' or claims_decoded[j] == '\t')) : (j += 1) {}
            if (j < claims_decoded_len and claims_decoded[j] == '"') {
                j += 1;
                user_id_start = j;
                while (j < claims_decoded_len and claims_decoded[j] != '"') : (j += 1) {}
                user_id_end = j;
            }
        }
    }
    if (!exp_found) {
        return false;
    }
    claims_out.exp = exp_value;
    if (user_id_start) |start_idx| {
        if (user_id_end) |end_idx| {
            const user_id_len = end_idx - start_idx;
            if (user_id_len > MAX_USER_ID_LEN) {
                return false;
            }
            std.mem.copyForwards(
                u8,
                &claims_out.user_id,
                claims_decoded[start_idx..end_idx],
            );
            claims_out.user_id_len = user_id_len;
        } else {
            return false;
        }
    } else {
        return false;
    }
    claims_out.iat = current_time;
    claims_out.token_type = TokenType.access;
    std.debug.assert(claims_out.user_id_len > 0);
    return true;
}

// Base64URL encoding
fn base64url_encode(input: []const u8, output: []u8) u32 {
    std.debug.assert(input.len > 0);
    std.debug.assert(output.len >= (input.len * 4 / 3 + 4));
    const base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    var i: u32 = 0;
    var out_idx: u32 = 0;
    while (i < input.len) {
        const byte1 = input[i];
        i += 1;
        if (i < input.len) {
            const byte2 = input[i];
            i += 1;
            if (i < input.len) {
                const byte3 = input[i];
                i += 1;
                const b1 = (byte1 >> 2) & 0x3F;
                const b2 = ((byte1 & 0x03) << 4) | ((byte2 >> 4) & 0x0F);
                const b3 = ((byte2 & 0x0F) << 2) | ((byte3 >> 6) & 0x03);
                const b4 = byte3 & 0x3F;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b1)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b2)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b3)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b4)];
                out_idx += 1;
            } else {
                const b1 = (byte1 >> 2) & 0x3F;
                const b2 = ((byte1 & 0x03) << 4) | ((byte2 >> 4) & 0x0F);
                const b3 = (byte2 & 0x0F) << 2;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b1)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b2)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b3)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = '=';
                out_idx += 1;
            }
        } else {
            const b1 = (byte1 >> 2) & 0x3F;
            const b2 = (byte1 & 0x03) << 4;
            if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b1)];
            out_idx += 1;
            if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b2)];
            out_idx += 1;
            if (out_idx < output.len) output[out_idx] = '=';
            out_idx += 1;
            if (out_idx < output.len) output[out_idx] = '=';
            out_idx += 1;
        }
    }
    std.debug.assert(out_idx <= output.len);
    return out_idx;
}

// Base64URL decoding
fn base64url_decode(input: []const u8, output: []u8) u32 {
    std.debug.assert(input.len > 0);
    std.debug.assert(output.len >= (input.len * 3 / 4));
    const base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    var out_idx: u32 = 0;
    var i: u32 = 0;
    while (i < input.len) {
        if (input[i] == '=') {
            break;
        }
        var char_val: u8 = 255;
        var j: u32 = 0;
        while (j < 64) : (j += 1) {
            if (base64_chars[j] == input[i]) {
                char_val = @intCast(j);
                break;
            }
        }
        if (char_val == 255) {
            break;
        }
        if (i + 1 < input.len and input[i + 1] != '=') {
            var char_val2: u8 = 255;
            j = 0;
            while (j < 64) : (j += 1) {
                if (base64_chars[j] == input[i + 1]) {
                    char_val2 = @intCast(j);
                    break;
                }
            }
            if (char_val2 == 255) {
                break;
            }
            if (i + 2 < input.len and input[i + 2] != '=') {
                var char_val3: u8 = 255;
                j = 0;
                while (j < 64) : (j += 1) {
                    if (base64_chars[j] == input[i + 2]) {
                        char_val3 = @intCast(j);
                        break;
                    }
                }
                if (char_val3 == 255) {
                    break;
                }
                if (i + 3 < input.len and input[i + 3] != '=') {
                    var char_val4: u8 = 255;
                    j = 0;
                    while (j < 64) : (j += 1) {
                        if (base64_chars[j] == input[i + 3]) {
                            char_val4 = @intCast(j);
                            break;
                        }
                    }
                    if (char_val4 == 255) {
                        break;
                    }
                    if (out_idx < output.len) {
                        output[out_idx] = (char_val << 2) | (char_val2 >> 4);
                        out_idx += 1;
                    }
                    if (out_idx < output.len) {
                        output[out_idx] = ((char_val2 & 0x0F) << 4) | (char_val3 >> 2);
                        out_idx += 1;
                    }
                    if (out_idx < output.len) {
                        output[out_idx] = ((char_val3 & 0x03) << 6) | char_val4;
                        out_idx += 1;
                    }
                    i += 4;
                } else {
                    if (out_idx < output.len) {
                        output[out_idx] = (char_val << 2) | (char_val2 >> 4);
                        out_idx += 1;
                    }
                    if (out_idx < output.len) {
                        output[out_idx] = ((char_val2 & 0x0F) << 4) | (char_val3 >> 2);
                        out_idx += 1;
                    }
                    i += 3;
                    break;
                }
            } else {
                if (out_idx < output.len) {
                    output[out_idx] = (char_val << 2) | (char_val2 >> 4);
                    out_idx += 1;
                }
                i += 2;
                break;
            }
        } else {
            if (out_idx < output.len) {
                output[out_idx] = char_val << 2;
                out_idx += 1;
            }
            i += 1;
            break;
        }
    }
    std.debug.assert(out_idx <= output.len);
    return out_idx;
}

// HMAC-SHA256 for JWT signatures
fn hmac_sha256(key: []const u8, message: []const u8, output: []u8) void {
    std.debug.assert(key.len > 0);
    std.debug.assert(message.len > 0);
    std.debug.assert(output.len >= 32);
    const block_size: u32 = 64;
    var ipad_key: [block_size]u8 = undefined;
    var opad_key: [block_size]u8 = undefined;
    if (key.len > block_size) {
        var key_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(key, &key_hash, .{});
        std.mem.set(u8, &ipad_key, 0);
        std.mem.copyForwards(u8, ipad_key[0..32], &key_hash);
    } else {
        std.mem.set(u8, &ipad_key, 0);
        std.mem.copyForwards(u8, ipad_key[0..key.len], key);
    }
    var i: u32 = 0;
    while (i < block_size) : (i += 1) {
        opad_key[i] = ipad_key[i];
        ipad_key[i] ^= 0x36;
        opad_key[i] ^= 0x5C;
    }
    var inner_hash: [32]u8 = undefined;
    var inner_input: [block_size + 256]u8 = undefined;
    std.mem.copyForwards(u8, inner_input[0..block_size], &ipad_key);
    if (message.len <= 256) {
        std.mem.copyForwards(
            u8,
            inner_input[block_size..block_size + message.len],
            message,
        );
        std.crypto.hash.sha2.Sha256.hash(
            inner_input[0..block_size + message.len],
            &inner_hash,
            .{},
        );
    } else {
        std.crypto.hash.sha2.Sha256.hash(message, &inner_hash, .{});
    }
    var outer_input: [block_size + 32]u8 = undefined;
    std.mem.copyForwards(u8, outer_input[0..block_size], &opad_key);
    std.mem.copyForwards(u8, outer_input[block_size..block_size + 32], &inner_hash);
    std.crypto.hash.sha2.Sha256.hash(
        outer_input[0..block_size + 32],
        output[0..32],
        .{},
    );
    std.debug.assert(output.len >= 32);
}

