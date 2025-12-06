// Password validation for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Password Policy:
// - Minimum 32 characters required (security best practice)
// - Recommended: Use 1Password password manager with "Memorable Password" option
// - 1Password strategy: Words + Numbers/Symbols as separators
// - Example: "aladdin!petition7inge1kalinda3TABLET" (words separated by numbers/symbols)
// - Benefits: Easy to remember, type, and share while maintaining high security

const std = @import("std");
const errors = @import("../utils/errors.zig");

// Password requirements aligned with 1Password memorable password strategy
// Recommended: Use 1Password-style memorable passwords (words + separators)
// Example: "aladdin!petition7inge1kalinda3TABLET" (32+ chars, words + numbers/symbols)
pub const MAX_PASSWORD_LEN: u32 = 128;
pub const MIN_PASSWORD_LEN: u32 = 32;  // Require 32+ chars for security
pub const MIN_UPPERCASE: u32 = 1;
pub const MIN_LOWERCASE: u32 = 1;
pub const MIN_DIGITS: u32 = 1;
pub const MIN_SPECIAL: u32 = 1;

pub const PasswordStrength = enum(u8) {
    weak = 0,
    medium = 1,
    strong = 2,
};

pub fn validate_password(password: []const u8) bool {
    std.debug.assert(password.len > 0);
    
    if (password.len < MIN_PASSWORD_LEN) {
        return false;
    }
    
    if (password.len > MAX_PASSWORD_LEN) {
        return false;
    }
    
    std.debug.assert(password.len >= MIN_PASSWORD_LEN);
    std.debug.assert(password.len <= MAX_PASSWORD_LEN);
    
    const has_upper = count_uppercase(password) >= MIN_UPPERCASE;
    const has_lower = count_lowercase(password) >= MIN_LOWERCASE;
    const has_digit = count_digits(password) >= MIN_DIGITS;
    const has_special = count_special(password) >= MIN_SPECIAL;
    
    const is_valid = has_upper and has_lower and has_digit and has_special;
    
    std.debug.assert(!is_valid or password.len >= MIN_PASSWORD_LEN);
    std.debug.assert(!is_valid or password.len <= MAX_PASSWORD_LEN);
    
    return is_valid;
}

// Password strength calculation favors longer passwords (32+ chars recommended)
// 1Password-style memorable passwords (words + separators) score well
pub fn get_password_strength(password: []const u8) PasswordStrength {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= MAX_PASSWORD_LEN);
    
    const upper_count = count_uppercase(password);
    const lower_count = count_lowercase(password);
    const digit_count = count_digits(password);
    const special_count = count_special(password);
    
    const score = upper_count + lower_count + digit_count + special_count;
    // Length bonus: 32+ chars (1Password recommendation) gets highest bonus
    const length_bonus: u32 = if (password.len >= 32) 4 else if (password.len >= 24) 3 else if (password.len >= 16) 2 else if (password.len >= 12) 1 else 0;
    const total_score = score + length_bonus;
    
    std.debug.assert(total_score >= 0);
    
    // Adjusted thresholds for 32-char minimum requirement
    if (total_score < 6) {
        return .weak;
    } else if (total_score < 12) {
        return .medium;
    } else {
        return .strong;
    }
}

fn count_uppercase(password: []const u8) u32 {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= MAX_PASSWORD_LEN);
    
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < password.len) : (i += 1) {
        if (password[i] >= 'A' and password[i] <= 'Z') {
            count += 1;
        }
    }
    
    std.debug.assert(count <= password.len);
    return count;
}

fn count_lowercase(password: []const u8) u32 {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= MAX_PASSWORD_LEN);
    
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < password.len) : (i += 1) {
        if (password[i] >= 'a' and password[i] <= 'z') {
            count += 1;
        }
    }
    
    std.debug.assert(count <= password.len);
    return count;
}

fn count_digits(password: []const u8) u32 {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= MAX_PASSWORD_LEN);
    
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < password.len) : (i += 1) {
        if (password[i] >= '0' and password[i] <= '9') {
            count += 1;
        }
    }
    
    std.debug.assert(count <= password.len);
    return count;
}

fn count_special(password: []const u8) u32 {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= MAX_PASSWORD_LEN);
    
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < password.len) : (i += 1) {
        const c = password[i];
        const is_special = (c == '!' or c == '@' or c == '#' or c == '$' or
            c == '%' or c == '^' or c == '&' or c == '*' or
            c == '(' or c == ')' or c == '-' or c == '_' or
            c == '+' or c == '=' or c == '[' or c == ']' or
            c == '{' or c == '}' or c == '|' or c == '\\' or
            c == ';' or c == ':' or c == '\'' or c == '"' or
            c == '<' or c == '>' or c == ',' or c == '.' or
            c == '?' or c == '/');
        if (is_special) {
            count += 1;
        }
    }
    
    std.debug.assert(count <= password.len);
    return count;
}

