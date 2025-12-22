// API response helpers for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Provides helper functions for building API responses
// Ready for JSON serialization when JSON support is available

const std = @import("std");
const models = @import("models.zig");

pub const MAX_JSON_RESPONSE_LEN: u32 = 4096;

// Helper: write JSON string key
fn write_json_key(json_out: []u8, json_len: *u32, key: []const u8) void {
    std.debug.assert(key.len > 0);
    std.debug.assert(json_len.* + key.len + 4 <= json_out.len);
    
    json_out[json_len.*] = '"';
    json_len.* += 1;
    std.mem.copyForwards(u8, json_out[json_len.*..], key);
    json_len.* += @intCast(key.len);
    json_out[json_len.*] = '"';
    json_len.* += 1;
    json_out[json_len.*] = ':';
    json_len.* += 1;
}

// Helper: write JSON string value
fn write_json_string_value(json_out: []u8, json_len: *u32, value: []const u8) void {
    std.debug.assert(value.len > 0);
    std.debug.assert(json_len.* + value.len + 2 <= json_out.len);
    
    json_out[json_len.*] = '"';
    json_len.* += 1;
    std.mem.copyForwards(u8, json_out[json_len.*..], value);
    json_len.* += @intCast(value.len);
    json_out[json_len.*] = '"';
    json_len.* += 1;
}

// Helper: write JSON boolean value
fn write_json_bool_value(json_out: []u8, json_len: *u32, value: bool) void {
    std.debug.assert(json_len.* + 5 <= json_out.len);
    
    if (value) {
        json_out[json_len.*] = 't';
        json_len.* += 1;
        json_out[json_len.*] = 'r';
        json_len.* += 1;
        json_out[json_len.*] = 'u';
        json_len.* += 1;
        json_out[json_len.*] = 'e';
        json_len.* += 1;
    } else {
        json_out[json_len.*] = 'f';
        json_len.* += 1;
        json_out[json_len.*] = 'a';
        json_len.* += 1;
        json_out[json_len.*] = 'l';
        json_len.* += 1;
        json_out[json_len.*] = 's';
        json_len.* += 1;
        json_out[json_len.*] = 'e';
        json_len.* += 1;
    }
}

// Build success response JSON (simplified, manual JSON construction)
pub fn build_success_response(
    message: []const u8,
    data: []const u8,
    json_out: []u8,
) u32 {
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= models.MAX_MESSAGE_LEN);
    std.debug.assert(data.len <= MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json_out.len >= MAX_JSON_RESPONSE_LEN);
    
    var json_len: u32 = 0;
    json_out[json_len] = '{';
    json_len += 1;
    
    write_json_key(json_out, &json_len, "status");
    write_json_string_value(json_out, &json_len, "success");
    
    json_out[json_len] = ',';
    json_len += 1;
    write_json_key(json_out, &json_len, "message");
    write_json_string_value(json_out, &json_len, message);
    
    if (data.len > 0) {
        json_out[json_len] = ',';
        json_len += 1;
        write_json_key(json_out, &json_len, "data");
        std.mem.copyForwards(u8, json_out[json_len..], data);
        json_len += @intCast(data.len);
    }
    
    json_out[json_len] = '}';
    json_len += 1;
    
    std.debug.assert(json_len <= MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json_len <= json_out.len);
    
    return json_len;
}

// Build error response JSON (simplified, manual JSON construction)
pub fn build_error_response(
    error_code: []const u8,
    message: []const u8,
    json_out: []u8,
) u32 {
    std.debug.assert(error_code.len > 0);
    std.debug.assert(error_code.len <= 32);
    std.debug.assert(message.len > 0);
    std.debug.assert(message.len <= models.MAX_MESSAGE_LEN);
    std.debug.assert(json_out.len >= MAX_JSON_RESPONSE_LEN);
    
    var json_len: u32 = 0;
    json_out[json_len] = '{';
    json_len += 1;
    
    write_json_key(json_out, &json_len, "status");
    write_json_string_value(json_out, &json_len, "error");
    
    json_out[json_len] = ',';
    json_len += 1;
    write_json_key(json_out, &json_len, "error_code");
    write_json_string_value(json_out, &json_len, error_code);
    
    json_out[json_len] = ',';
    json_len += 1;
    write_json_key(json_out, &json_len, "message");
    write_json_string_value(json_out, &json_len, message);
    
    json_out[json_len] = '}';
    json_len += 1;
    
    std.debug.assert(json_len <= MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json_len <= json_out.len);
    
    return json_len;
}

// Build auth response JSON (simplified, manual JSON construction)
pub fn build_auth_response(
    auth_resp: *const models.AuthResponse,
    json_out: []u8,
) u32 {
    std.debug.assert(auth_resp != null);
    std.debug.assert(json_out.len >= MAX_JSON_RESPONSE_LEN);
    
    var json_len: u32 = 0;
    json_out[json_len] = '{';
    json_len += 1;
    
    write_json_key(json_out, &json_len, "success");
    write_json_bool_value(json_out, &json_len, auth_resp.success);
    
    if (auth_resp.token_len > 0) {
        json_out[json_len] = ',';
        json_len += 1;
        write_json_key(json_out, &json_len, "token");
        write_json_string_value(json_out, &json_len, auth_resp.token[0..auth_resp.token_len]);
    }
    
    if (auth_resp.user_id_len > 0) {
        json_out[json_len] = ',';
        json_len += 1;
        write_json_key(json_out, &json_len, "user_id");
        write_json_string_value(json_out, &json_len, auth_resp.user_id[0..auth_resp.user_id_len]);
    }
    
    json_out[json_len] = '}';
    json_len += 1;
    
    std.debug.assert(json_len <= MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json_len <= json_out.len);
    
    return json_len;
}

// Build user profile response JSON.
pub fn build_user_profile_response(
    user_id: []const u8,
    email: []const u8,
    username: []const u8,
    created_at: u64,
    json_out: []u8,
) u32 {
    std.debug.assert(user_id.len > 0);
    std.debug.assert(email.len > 0);
    std.debug.assert(json_out.len >= MAX_JSON_RESPONSE_LEN);
    
    var json_len: u32 = 0;
    json_out[json_len] = '{';
    json_len += 1;
    
    write_json_key(json_out, &json_len, "status");
    write_json_string_value(json_out, &json_len, "success");
    
    json_out[json_len] = ',';
    json_len += 1;
    write_json_key(json_out, &json_len, "data");
    json_out[json_len] = '{';
    json_len += 1;
    
    write_json_key(json_out, &json_len, "user_id");
    write_json_string_value(json_out, &json_len, user_id);
    
    json_out[json_len] = ',';
    json_len += 1;
    write_json_key(json_out, &json_len, "email");
    write_json_string_value(json_out, &json_len, email);
    
    if (username.len > 0) {
        json_out[json_len] = ',';
        json_len += 1;
        write_json_key(json_out, &json_len, "username");
        write_json_string_value(json_out, &json_len, username);
    }
    
    json_out[json_len] = ',';
    json_len += 1;
    write_json_key(json_out, &json_len, "created_at");
    var created_at_buf: [32]u8 = undefined;
    const created_at_str = std.fmt.bufPrint(&created_at_buf, "{}", .{created_at}) catch return 0;
    std.mem.copyForwards(u8, json_out[json_len..], created_at_str);
    json_len += @intCast(created_at_str.len);
    
    json_out[json_len] = '}';
    json_len += 1;
    
    json_out[json_len] = '}';
    json_len += 1;
    
    std.debug.assert(json_len <= MAX_JSON_RESPONSE_LEN);
    std.debug.assert(json_len <= json_out.len);
    
    return json_len;
}
