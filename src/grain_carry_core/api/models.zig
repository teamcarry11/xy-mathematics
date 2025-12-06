// API data models for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Defines request/response data structures for mobile app API endpoints
// Ready for JSON serialization when JSON support is available

const std = @import("std");
const email_validation = @import("../validation/email.zig");
const password_validation = @import("../validation/password.zig");

pub const MAX_USERNAME_LEN: u32 = 64;
pub const MAX_EMAIL_LEN: u32 = email_validation.MAX_EMAIL_LEN;
pub const MAX_PASSWORD_LEN: u32 = password_validation.MAX_PASSWORD_LEN;
pub const MAX_TOKEN_LEN: u32 = 512;
pub const MAX_MESSAGE_LEN: u32 = 256;
pub const MAX_USER_ID_LEN: u32 = 64;

// Authentication request models
pub const RegisterRequest = struct {
    email: [MAX_EMAIL_LEN]u8,
    email_len: u32,
    password: [MAX_PASSWORD_LEN]u8,
    password_len: u32,
    username: [MAX_USERNAME_LEN]u8,
    username_len: u32,

    pub fn init(
        email: []const u8,
        password: []const u8,
        username: []const u8,
    ) RegisterRequest {
        std.debug.assert(email.len > 0);
        std.debug.assert(email.len <= MAX_EMAIL_LEN);
        std.debug.assert(password.len >= password_validation.MIN_PASSWORD_LEN);
        std.debug.assert(password.len <= MAX_PASSWORD_LEN);
        std.debug.assert(username.len > 0);
        std.debug.assert(username.len <= MAX_USERNAME_LEN);
        
        var req: RegisterRequest = undefined;
        std.mem.copyForwards(u8, &req.email, email);
        req.email_len = @intCast(email.len);
        std.mem.copyForwards(u8, &req.password, password);
        req.password_len = @intCast(password.len);
        std.mem.copyForwards(u8, &req.username, username);
        req.username_len = @intCast(username.len);
        
        std.debug.assert(req.email_len > 0);
        std.debug.assert(req.password_len >= password_validation.MIN_PASSWORD_LEN);
        std.debug.assert(req.username_len > 0);
        
        return req;
    }
};

pub const LoginRequest = struct {
    email: [MAX_EMAIL_LEN]u8,
    email_len: u32,
    password: [MAX_PASSWORD_LEN]u8,
    password_len: u32,

    pub fn init(email: []const u8, password: []const u8) LoginRequest {
        std.debug.assert(email.len > 0);
        std.debug.assert(email.len <= MAX_EMAIL_LEN);
        std.debug.assert(password.len >= password_validation.MIN_PASSWORD_LEN);
        std.debug.assert(password.len <= MAX_PASSWORD_LEN);
        
        var req: LoginRequest = undefined;
        std.mem.copyForwards(u8, &req.email, email);
        req.email_len = @intCast(email.len);
        std.mem.copyForwards(u8, &req.password, password);
        req.password_len = @intCast(password.len);
        
        std.debug.assert(req.email_len > 0);
        std.debug.assert(req.password_len >= password_validation.MIN_PASSWORD_LEN);
        
        return req;
    }
};

pub const OtpSendRequest = struct {
    email: [MAX_EMAIL_LEN]u8,
    email_len: u32,

    pub fn init(email: []const u8) OtpSendRequest {
        std.debug.assert(email.len > 0);
        std.debug.assert(email.len <= MAX_EMAIL_LEN);
        
        var req: OtpSendRequest = undefined;
        std.mem.copyForwards(u8, &req.email, email);
        req.email_len = @intCast(email.len);
        
        std.debug.assert(req.email_len > 0);
        
        return req;
    }
};

pub const OtpVerifyRequest = struct {
    email: [MAX_EMAIL_LEN]u8,
    email_len: u32,
    code: [6]u8,
    code_len: u32,

    pub fn init(email: []const u8, code: []const u8) OtpVerifyRequest {
        std.debug.assert(email.len > 0);
        std.debug.assert(email.len <= MAX_EMAIL_LEN);
        std.debug.assert(code.len == 6);
        
        var req: OtpVerifyRequest = undefined;
        std.mem.copyForwards(u8, &req.email, email);
        req.email_len = @intCast(email.len);
        std.mem.copyForwards(u8, &req.code, code);
        req.code_len = @intCast(code.len);
        
        std.debug.assert(req.email_len > 0);
        std.debug.assert(req.code_len == 6);
        
        return req;
    }
};

// Authentication response models
pub const AuthResponse = struct {
    success: bool,
    token: [MAX_TOKEN_LEN]u8,
    token_len: u32,
    refresh_token: [MAX_TOKEN_LEN]u8,
    refresh_token_len: u32,
    user_id: [MAX_USER_ID_LEN]u8,
    user_id_len: u32,
    expires_in: u64,

    pub fn init() AuthResponse {
        return AuthResponse{
            .success = false,
            .token_len = 0,
            .refresh_token_len = 0,
            .user_id_len = 0,
            .expires_in = 0,
        };
    }

    pub fn set_token(self: *AuthResponse, token: []const u8) bool {
        std.debug.assert(token.len > 0);
        std.debug.assert(token.len <= MAX_TOKEN_LEN);
        
        if (token.len > MAX_TOKEN_LEN) {
            return false;
        }
        
        std.mem.copyForwards(u8, &self.token, token);
        self.token_len = @intCast(token.len);
        
        std.debug.assert(self.token_len > 0);
        std.debug.assert(self.token_len <= MAX_TOKEN_LEN);
        
        return true;
    }

    pub fn set_refresh_token(self: *AuthResponse, refresh_token: []const u8) bool {
        std.debug.assert(refresh_token.len > 0);
        std.debug.assert(refresh_token.len <= MAX_TOKEN_LEN);
        
        if (refresh_token.len > MAX_TOKEN_LEN) {
            return false;
        }
        
        std.mem.copyForwards(u8, &self.refresh_token, refresh_token);
        self.refresh_token_len = @intCast(refresh_token.len);
        
        std.debug.assert(self.refresh_token_len > 0);
        std.debug.assert(self.refresh_token_len <= MAX_TOKEN_LEN);
        
        return true;
    }

    pub fn set_user_id(self: *AuthResponse, user_id: []const u8) bool {
        std.debug.assert(user_id.len > 0);
        std.debug.assert(user_id.len <= MAX_USER_ID_LEN);
        
        if (user_id.len > MAX_USER_ID_LEN) {
            return false;
        }
        
        std.mem.copyForwards(u8, &self.user_id, user_id);
        self.user_id_len = @intCast(user_id.len);
        
        std.debug.assert(self.user_id_len > 0);
        std.debug.assert(self.user_id_len <= MAX_USER_ID_LEN);
        
        return true;
    }
};

// Error response model
pub const ErrorResponse = struct {
    error_code: [32]u8,
    error_code_len: u32,
    message: [MAX_MESSAGE_LEN]u8,
    message_len: u32,

    pub fn init(error_code: []const u8, message: []const u8) ErrorResponse {
        std.debug.assert(error_code.len > 0);
        std.debug.assert(error_code.len <= 32);
        std.debug.assert(message.len > 0);
        std.debug.assert(message.len <= MAX_MESSAGE_LEN);
        
        var err: ErrorResponse = undefined;
        std.mem.copyForwards(u8, &err.error_code, error_code);
        err.error_code_len = @intCast(error_code.len);
        std.mem.copyForwards(u8, &err.message, message);
        err.message_len = @intCast(message.len);
        
        std.debug.assert(err.error_code_len > 0);
        std.debug.assert(err.message_len > 0);
        
        return err;
    }
};

