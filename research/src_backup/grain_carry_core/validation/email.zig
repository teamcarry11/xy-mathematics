// Email validation for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions

const std = @import("std");
const errors = @import("../utils/errors.zig");

pub const MAX_EMAIL_LEN: u32 = 256;
pub const MIN_EMAIL_LEN: u32 = 3;

pub fn validate_email(email: []const u8) bool {
    std.debug.assert(email.len > 0);
    
    if (email.len < MIN_EMAIL_LEN) {
        return false;
    }
    
    if (email.len > MAX_EMAIL_LEN) {
        return false;
    }
    
    std.debug.assert(email.len >= MIN_EMAIL_LEN);
    std.debug.assert(email.len <= MAX_EMAIL_LEN);
    
    const has_at = has_at_symbol(email);
    const has_dot_after_at = has_dot_after_at_symbol(email);
    const is_valid_format = has_at and has_dot_after_at;
    
    std.debug.assert(!is_valid_format or email.len >= MIN_EMAIL_LEN);
    std.debug.assert(!is_valid_format or email.len <= MAX_EMAIL_LEN);
    
    return is_valid_format;
}

fn has_at_symbol(email: []const u8) bool {
    std.debug.assert(email.len > 0);
    std.debug.assert(email.len <= MAX_EMAIL_LEN);
    
    var found: bool = false;
    var i: u32 = 0;
    while (i < email.len) : (i += 1) {
        if (email[i] == '@') {
            found = true;
            break;
        }
    }
    
    std.debug.assert(i <= email.len);
    return found;
}

fn has_dot_after_at_symbol(email: []const u8) bool {
    std.debug.assert(email.len > 0);
    std.debug.assert(email.len <= MAX_EMAIL_LEN);
    
    var at_index: ?u32 = null;
    var i: u32 = 0;
    while (i < email.len) : (i += 1) {
        if (email[i] == '@') {
            at_index = i;
            break;
        }
    }
    
    if (at_index == null) {
        return false;
    }
    
    const at_pos = at_index.?;
    std.debug.assert(at_pos < email.len);
    
    var j: u32 = at_pos + 1;
    while (j < email.len) : (j += 1) {
        if (email[j] == '.') {
            return true;
        }
    }
    
    std.debug.assert(j <= email.len);
    return false;
}

