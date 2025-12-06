//! Grain OS JSON Helpers: Bounded JSON parsing and generation for API server.
//!
//! Why: Provide JSON parsing and generation without dynamic allocation.
//! Architecture: Bounded JSON parsing/generation for request/response bodies.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");

// Bounded: Max JSON key length.
pub const MAX_JSON_KEY_LEN: u32 = 128;

// Bounded: Max JSON string value length.
pub const MAX_JSON_STRING_LEN: u32 = 4096;

// JSON parse result.
pub const JsonParseResult = struct {
    success: bool,
    value_start: u32,
    value_len: u32,
};

// Find JSON key in object.
pub fn find_json_key(
    json: []const u8,
    key: []const u8,
) ?JsonParseResult {
    std.debug.assert(json.len > 0);
    std.debug.assert(key.len > 0);
    std.debug.assert(key.len <= MAX_JSON_KEY_LEN);
    if (json.len > MAX_JSON_STRING_LEN) {
        return null;
    }
    var i: u32 = 0;
    while (i < json.len) : (i += 1) {
        if (json[i] == '"') {
            i += 1;
            const key_start_pos = i;
            var key_match: bool = true;
            var j: u32 = 0;
            while (j < key.len and i < json.len) : (j += 1) {
                if (json[i] == '\\') {
                    i += 1;
                    if (i >= json.len) {
                        key_match = false;
                        break;
                    }
                }
                if (i >= json.len or json[i] != key[j]) {
                    key_match = false;
                    break;
                }
                i += 1;
            }
            if (key_match and j == key.len and i < json.len and json[i] == '"') {
                i += 1;
                while (i < json.len and (json[i] == ' ' or json[i] == '\t')) : (i += 1) {}
                if (i < json.len and json[i] == ':') {
                    i += 1;
                    while (i < json.len and (json[i] == ' ' or json[i] == '\t')) : (i += 1) {}
                    if (i < json.len) {
                        const value_start = i;
                        var value_len: u32 = 0;
                        var value_i = i;
                        if (json[value_i] == '"') {
                            value_i += 1;
                            value_len = 1;
                            while (value_i < json.len) : (value_i += 1) {
                                if (json[value_i] == '\\') {
                                    value_i += 1;
                                    value_len += 1;
                                    if (value_i >= json.len) {
                                        break;
                                    }
                                    value_len += 1;
                                } else if (json[value_i] == '"') {
                                    value_len += 1;
                                    break;
                                } else {
                                    value_len += 1;
                                }
                            }
                        } else {
                            while (value_i < json.len and json[value_i] != ',' and json[value_i] != '}' and json[value_i] != ']' and json[value_i] != '\n' and json[value_i] != '\r') : (value_i += 1) {
                                value_len += 1;
                            }
                        }
                        return JsonParseResult{
                            .success = true,
                            .value_start = value_start,
                            .value_len = value_len,
                        };
                    }
                }
            }
            i = key_start_pos;
        }
    }
    return null;
}

// Extract JSON string value (unquoted, unescaped).
pub fn extract_json_string_value(
    json: []const u8,
    result: *JsonParseResult,
    output: []u8,
) ?u32 {
    std.debug.assert(json.len > 0);
    std.debug.assert(output.len > 0);
    if (!result.success) {
        return null;
    }
    if (result.value_start >= json.len) {
        return null;
    }
    if (json[result.value_start] != '"') {
        return null;
    }
    var i: u32 = result.value_start + 1;
    var output_pos: u32 = 0;
    while (i < json.len and i < result.value_start + result.value_len) : (i += 1) {
        if (json[i] == '"') {
            break;
        }
        if (json[i] == '\\') {
            i += 1;
            if (i >= json.len) {
                return null;
            }
            if (output_pos >= output.len) {
                return null;
            }
            switch (json[i]) {
                'n' => output[output_pos] = '\n',
                'r' => output[output_pos] = '\r',
                't' => output[output_pos] = '\t',
                '\\' => output[output_pos] = '\\',
                '"' => output[output_pos] = '"',
                else => output[output_pos] = json[i],
            }
            output_pos += 1;
        } else {
            if (output_pos >= output.len) {
                return null;
            }
            output[output_pos] = json[i];
            output_pos += 1;
        }
    }
    return output_pos;
}

// Extract JSON number value.
pub fn extract_json_number_value(
    json: []const u8,
    result: *JsonParseResult,
) ?i64 {
    std.debug.assert(json.len > 0);
    if (!result.success) {
        return null;
    }
    if (result.value_start >= json.len) {
        return null;
    }
    var i: u32 = result.value_start;
    var is_negative: bool = false;
    if (json[i] == '-') {
        is_negative = true;
        i += 1;
    }
    if (i >= json.len) {
        return null;
    }
    var num: i64 = 0;
    while (i < json.len and i < result.value_start + result.value_len) : (i += 1) {
        if (json[i] >= '0' and json[i] <= '9') {
            num = num * 10 + (json[i] - '0');
        } else {
            break;
        }
    }
    if (is_negative) {
        num = -num;
    }
    return num;
}

// Extract JSON boolean value.
pub fn extract_json_bool_value(
    json: []const u8,
    result: *JsonParseResult,
) ?bool {
    std.debug.assert(json.len > 0);
    if (!result.success) {
        return null;
    }
    if (result.value_start >= json.len) {
        return null;
    }
    const value_str = json[result.value_start..result.value_start + result.value_len];
    if (std.mem.eql(u8, value_str, "true")) {
        return true;
    } else if (std.mem.eql(u8, value_str, "false")) {
        return false;
    }
    return null;
}

// Write JSON string with escaping.
pub fn write_json_string(
    output: []u8,
    output_pos: *u32,
    value: []const u8,
) bool {
    std.debug.assert(output.len > 0);
    std.debug.assert(value.len > 0);
    if (output_pos.* + value.len * 2 + 2 > output.len) {
        return false;
    }
    output[output_pos.*] = '"';
    output_pos.* += 1;
    var i: u32 = 0;
    while (i < value.len) : (i += 1) {
        switch (value[i]) {
            '"' => {
                output[output_pos.*] = '\\';
                output_pos.* += 1;
                output[output_pos.*] = '"';
                output_pos.* += 1;
            },
            '\\' => {
                output[output_pos.*] = '\\';
                output_pos.* += 1;
                output[output_pos.*] = '\\';
                output_pos.* += 1;
            },
            '\n' => {
                output[output_pos.*] = '\\';
                output_pos.* += 1;
                output[output_pos.*] = 'n';
                output_pos.* += 1;
            },
            '\r' => {
                output[output_pos.*] = '\\';
                output_pos.* += 1;
                output[output_pos.*] = 'r';
                output_pos.* += 1;
            },
            '\t' => {
                output[output_pos.*] = '\\';
                output_pos.* += 1;
                output[output_pos.*] = 't';
                output_pos.* += 1;
            },
            else => {
                output[output_pos.*] = value[i];
                output_pos.* += 1;
            },
        }
    }
    output[output_pos.*] = '"';
    output_pos.* += 1;
    return true;
}

// Write JSON number.
pub fn write_json_number(
    output: []u8,
    output_pos: *u32,
    value: i64,
) bool {
    std.debug.assert(output.len > 0);
    if (output_pos.* + 32 > output.len) {
        return false;
    }
    const num_str = std.fmt.bufPrint(
        output[output_pos.*..],
        "{d}",
        .{value},
    ) catch return false;
    output_pos.* += @intCast(num_str.len);
    return true;
}

// Write JSON boolean.
pub fn write_json_bool(
    output: []u8,
    output_pos: *u32,
    value: bool,
) bool {
    std.debug.assert(output.len > 0);
    if (value) {
        if (output_pos.* + 4 > output.len) {
            return false;
        }
        output[output_pos.*] = 't';
        output_pos.* += 1;
        output[output_pos.*] = 'r';
        output_pos.* += 1;
        output[output_pos.*] = 'u';
        output_pos.* += 1;
        output[output_pos.*] = 'e';
        output_pos.* += 1;
    } else {
        if (output_pos.* + 5 > output.len) {
            return false;
        }
        output[output_pos.*] = 'f';
        output_pos.* += 1;
        output[output_pos.*] = 'a';
        output_pos.* += 1;
        output[output_pos.*] = 'l';
        output_pos.* += 1;
        output[output_pos.*] = 's';
        output_pos.* += 1;
        output[output_pos.*] = 'e';
        output_pos.* += 1;
    }
    return true;
}

