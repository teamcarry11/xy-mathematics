// API request validation helpers for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Provides validation functions for API request models
// Ready for use in handler functions

const std = @import("std");
const email_validation = @import("../validation/email.zig");
const password_validation = @import("../validation/password.zig");
const models = @import("models.zig");

// Validate register request
pub fn validate_register_request(req: *const models.RegisterRequest) bool {
    std.debug.assert(req != null);
    std.debug.assert(req.email_len > 0);
    std.debug.assert(req.password_len >= password_validation.MIN_PASSWORD_LEN);
    std.debug.assert(req.username_len > 0);
    
    const email = req.email[0..req.email_len];
    const password = req.password[0..req.password_len];
    const username = req.username[0..req.username_len];
    
    if (!email_validation.validate_email(email)) {
        return false;
    }
    
    if (!password_validation.validate_password(password)) {
        return false;
    }
    
    if (username.len == 0 or username.len > models.MAX_USERNAME_LEN) {
        return false;
    }
    
    std.debug.assert(email_validation.validate_email(email));
    std.debug.assert(password_validation.validate_password(password));
    
    return true;
}

// Validate login request
pub fn validate_login_request(req: *const models.LoginRequest) bool {
    std.debug.assert(req != null);
    std.debug.assert(req.email_len > 0);
    std.debug.assert(req.password_len >= password_validation.MIN_PASSWORD_LEN);
    
    const email = req.email[0..req.email_len];
    const password = req.password[0..req.password_len];
    
    if (!email_validation.validate_email(email)) {
        return false;
    }
    
    if (!password_validation.validate_password(password)) {
        return false;
    }
    
    std.debug.assert(email_validation.validate_email(email));
    std.debug.assert(password_validation.validate_password(password));
    
    return true;
}

// Validate OTP send request
pub fn validate_otp_send_request(req: *const models.OtpSendRequest) bool {
    std.debug.assert(req != null);
    std.debug.assert(req.email_len > 0);
    
    const email = req.email[0..req.email_len];
    
    if (!email_validation.validate_email(email)) {
        return false;
    }
    
    std.debug.assert(email_validation.validate_email(email));
    
    return true;
}

// Validate OTP verify request
pub fn validate_otp_verify_request(req: *const models.OtpVerifyRequest) bool {
    std.debug.assert(req != null);
    std.debug.assert(req.email_len > 0);
    std.debug.assert(req.code_len == 6);
    
    const email = req.email[0..req.email_len];
    const code = req.code[0..req.code_len];
    
    if (!email_validation.validate_email(email)) {
        return false;
    }
    
    if (code.len != 6) {
        return false;
    }
    
    var i: u32 = 0;
    while (i < code.len) : (i += 1) {
        if (code[i] < '0' or code[i] > '9') {
            return false;
        }
    }
    
    std.debug.assert(email_validation.validate_email(email));
    std.debug.assert(code.len == 6);
    
    return true;
}

