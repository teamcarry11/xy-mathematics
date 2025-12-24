//! Grain Court ZON Format: Token-efficient serialization for LLM communication.
//!
//! Why: Enable 35-70% token reduction for LLM communication vs JSON.
//! Architecture: ZON encoder/decoder, tabular array encoding, nested objects.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");

// Bounded: Max ZON output size (1MB).
pub const MAX_ZON_SIZE: u64 = 1_048_576;

// Bounded: Max table rows for tabular encoding.
pub const MAX_TABLE_ROWS: u32 = 10000;

// Bounded: Max field name length.
pub const MAX_FIELD_NAME_LEN: u32 = 128;

// Bounded: Max string value length.
pub const MAX_STRING_VALUE_LEN: u32 = 65536;

// ZON encoding result.
pub const ZonEncodeResult = struct {
    data: []u8,
    len: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ZonEncodeResult) void {
        std.debug.assert(self.allocator != null);
        self.allocator.free(self.data);
        self.* = undefined;
    }
};

// ZON value type.
pub const ZonValueType = enum(u8) {
    null_value,
    bool_value,
    u32_value,
    u64_value,
    i32_value,
    i64_value,
    f32_value,
    f64_value,
    string_value,
    array_value,
    object_value,
};

// ZON value.
pub const ZonValue = struct {
    value_type: ZonValueType,
    bool_val: bool,
    u32_val: u32,
    u64_val: u64,
    i32_val: i32,
    i64_val: i64,
    f32_val: f32,
    f64_val: f64,
    string_val: [MAX_STRING_VALUE_LEN]u8,
    string_val_len: u32,

    // Create ZonValue from bool.
    pub fn from_bool(value: bool) ZonValue {
        std.debug.assert(value == true or value == false);
        var zv = ZonValue{
            .value_type = .bool_value,
            .bool_val = value,
            .u32_val = 0,
            .u64_val = 0,
            .i32_val = 0,
            .i64_val = 0,
            .f32_val = 0.0,
            .f64_val = 0.0,
            .string_val = undefined,
            .string_val_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_STRING_VALUE_LEN) : (i += 1) {
            zv.string_val[i] = 0;
        }
        std.debug.assert(zv.value_type == .bool_value);
        return zv;
    }

    // Create ZonValue from u32.
    pub fn from_u32(value: u32) ZonValue {
        var zv = ZonValue{
            .value_type = .u32_value,
            .bool_val = false,
            .u32_val = value,
            .u64_val = 0,
            .i32_val = 0,
            .i64_val = 0,
            .f32_val = 0.0,
            .f64_val = 0.0,
            .string_val = undefined,
            .string_val_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_STRING_VALUE_LEN) : (i += 1) {
            zv.string_val[i] = 0;
        }
        std.debug.assert(zv.value_type == .u32_value);
        return zv;
    }

    // Create ZonValue from string.
    pub fn from_string(value: []const u8) ZonValue {
        std.debug.assert(value.len > 0);
        std.debug.assert(value.len <= MAX_STRING_VALUE_LEN);
        var zv = ZonValue{
            .value_type = .string_value,
            .bool_val = false,
            .u32_val = 0,
            .u64_val = 0,
            .i32_val = 0,
            .i64_val = 0,
            .f32_val = 0.0,
            .f64_val = 0.0,
            .string_val = undefined,
            .string_val_len = @intCast(value.len),
        };
        var i: u32 = 0;
        while (i < MAX_STRING_VALUE_LEN) : (i += 1) {
            zv.string_val[i] = 0;
        }
        i = 0;
        const copy_len = @min(value.len, MAX_STRING_VALUE_LEN);
        while (i < copy_len) : (i += 1) {
            zv.string_val[i] = value[i];
        }
        std.debug.assert(zv.value_type == .string_value);
        return zv;
    }
};

// Encode boolean to ZON format (T/F).
fn encode_bool(value: bool, output: []u8, output_pos: *u32) bool {
    std.debug.assert(output.len > 0);
    std.debug.assert(output_pos.* + 1 <= output.len);
    if (value) {
        output[output_pos.*] = 'T';
    } else {
        output[output_pos.*] = 'F';
    }
    output_pos.* += 1;
    std.debug.assert(output_pos.* <= output.len);
    return true;
}

// Encode u32 to ZON format.
fn encode_u32(value: u32, output: []u8, output_pos: *u32) bool {
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
    std.debug.assert(output_pos.* <= output.len);
    return true;
}

// Encode u64 to ZON format.
fn encode_u64(value: u64, output: []u8, output_pos: *u32) bool {
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
    std.debug.assert(output_pos.* <= output.len);
    return true;
}

// Encode string to ZON format (with escaping).
fn encode_string(value: []const u8, output: []u8, output_pos: *u32) bool {
    std.debug.assert(value.len > 0);
    std.debug.assert(output.len > 0);
    std.debug.assert(value.len <= MAX_STRING_VALUE_LEN);
    if (output_pos.* + value.len * 2 + 2 > output.len) {
        return false;
    }
    var i: u32 = 0;
    while (i < value.len) : (i += 1) {
        switch (value[i]) {
            ',' => {
                output[output_pos.*] = '\\';
                output_pos.* += 1;
                output[output_pos.*] = ',';
                output_pos.* += 1;
            },
            ':' => {
                output[output_pos.*] = '\\';
                output_pos.* += 1;
                output[output_pos.*] = ':';
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
            else => {
                output[output_pos.*] = value[i];
                output_pos.* += 1;
            },
        }
        if (output_pos.* >= output.len) {
            return false;
        }
    }
    std.debug.assert(output_pos.* <= output.len);
    return true;
}

// Encode simple key-value pair.
fn encode_key_value(
    key: []const u8,
    value: ZonValue,
    output: []u8,
    output_pos: *u32,
) bool {
    std.debug.assert(key.len > 0);
    std.debug.assert(key.len <= MAX_FIELD_NAME_LEN);
    std.debug.assert(output.len > 0);
    if (output_pos.* + key.len + 32 > output.len) {
        return false;
    }
    var i: u32 = 0;
    while (i < key.len) : (i += 1) {
        output[output_pos.*] = key[i];
        output_pos.* += 1;
    }
    output[output_pos.*] = ':';
    output_pos.* += 1;
    switch (value.value_type) {
        .bool_value => {
            if (!encode_bool(value.bool_val, output, output_pos)) {
                return false;
            }
        },
        .u32_value => {
            if (!encode_u32(value.u32_val, output, output_pos)) {
                return false;
            }
        },
        .u64_value => {
            if (!encode_u64(value.u64_val, output, output_pos)) {
                return false;
            }
        },
        .string_value => {
            const str_val = value.string_val[0..value.string_val_len];
            if (!encode_string(str_val, output, output_pos)) {
                return false;
            }
        },
        .null_value => {
            if (output_pos.* + 4 > output.len) {
                return false;
            }
            output[output_pos.*] = 'n';
            output_pos.* += 1;
            output[output_pos.*] = 'u';
            output_pos.* += 1;
            output[output_pos.*] = 'l';
            output_pos.* += 1;
            output[output_pos.*] = 'l';
            output_pos.* += 1;
        },
        else => return false,
    }
    std.debug.assert(output_pos.* <= output.len);
    return true;
}

// Encode tabular array to ZON format (public API).
pub fn encode_tabular_array_zon(
    key: []const u8,
    field_names: []const []const u8,
    rows: []const []const ZonValue,
    allocator: std.mem.Allocator,
) !ZonEncodeResult {
    std.debug.assert(key.len > 0);
    std.debug.assert(field_names.len > 0);
    std.debug.assert(rows.len > 0);
    std.debug.assert(rows.len <= MAX_TABLE_ROWS);
    std.debug.assert(allocator != null);
    var output_buffer = try allocator.alloc(u8, @as(usize, @intCast(MAX_ZON_SIZE)));
    errdefer allocator.free(output_buffer);
    var output_pos: u32 = 0;
    if (!encode_tabular_array_internal(key, field_names, rows, output_buffer, &output_pos)) {
        allocator.free(output_buffer);
        return error.ZonEncodeFailed;
    }
    std.debug.assert(output_pos <= MAX_ZON_SIZE);
    const result_data = try allocator.alloc(u8, output_pos);
    @memcpy(result_data, output_buffer[0..output_pos]);
    allocator.free(output_buffer);
    return ZonEncodeResult{
        .data = result_data,
        .len = output_pos,
        .allocator = allocator,
    };
}

// Encode tabular array to ZON format (internal).
fn encode_tabular_array_internal(
    key: []const u8,
    field_names: []const []const u8,
    rows: []const []const ZonValue,
    output: []u8,
    output_pos: *u32,
) bool {
    std.debug.assert(key.len > 0);
    std.debug.assert(field_names.len > 0);
    std.debug.assert(rows.len > 0);
    std.debug.assert(rows.len <= MAX_TABLE_ROWS);
    std.debug.assert(output.len > 0);
    if (output_pos.* + key.len + 64 > output.len) {
        return false;
    }
    var i: u32 = 0;
    while (i < key.len) : (i += 1) {
        output[output_pos.*] = key[i];
        output_pos.* += 1;
    }
    output[output_pos.*] = ':';
    output_pos.* += 1;
    output[output_pos.*] = '@';
    output_pos.* += 1;
    output[output_pos.*] = '(';
    output_pos.* += 1;
    if (!encode_u32(@intCast(rows.len), output, output_pos)) {
        return false;
    }
    output[output_pos.*] = ')';
    output_pos.* += 1;
    output[output_pos.*] = ':';
    output_pos.* += 1;
    i = 0;
    while (i < field_names.len) : (i += 1) {
        if (i > 0) {
            output[output_pos.*] = ',';
            output_pos.* += 1;
        }
        const field_name = field_names[i];
        var j: u32 = 0;
        while (j < field_name.len) : (j += 1) {
            output[output_pos.*] = field_name[j];
            output_pos.* += 1;
        }
    }
    output[output_pos.*] = '\n';
    output_pos.* += 1;
    i = 0;
    while (i < rows.len) : (i += 1) {
        const row = rows[i];
        var j: u32 = 0;
        while (j < row.len) : (j += 1) {
            if (j > 0) {
                output[output_pos.*] = ',';
                output_pos.* += 1;
            }
            const cell = row[j];
            switch (cell.value_type) {
                .bool_value => {
                    if (!encode_bool(cell.bool_val, output, output_pos)) {
                        return false;
                    }
                },
                .u32_value => {
                    if (!encode_u32(cell.u32_val, output, output_pos)) {
                        return false;
                    }
                },
                .string_value => {
                    const str_val = cell.string_val[0..cell.string_val_len];
                    if (!encode_string(str_val, output, output_pos)) {
                        return false;
                    }
                },
                else => return false,
            }
        }
        output[output_pos.*] = '\n';
        output_pos.* += 1;
    }
    std.debug.assert(output_pos.* <= output.len);
    return true;
}

// Encode ZON format from key-value pairs.
pub fn encode_zon(
    pairs: []const struct { key: []const u8, value: ZonValue },
    allocator: std.mem.Allocator,
) !ZonEncodeResult {
    std.debug.assert(pairs.len > 0);
    std.debug.assert(allocator != null);
    var output_buffer = try allocator.alloc(u8, @as(usize, @intCast(MAX_ZON_SIZE)));
    errdefer allocator.free(output_buffer);
    var output_pos: u32 = 0;
    var i: u32 = 0;
    while (i < pairs.len) : (i += 1) {
        if (i > 0) {
            if (output_pos + 1 > MAX_ZON_SIZE) {
                return error.ZonEncodeBufferFull;
            }
            output_buffer[output_pos] = '\n';
            output_pos += 1;
        }
        if (!encode_key_value(pairs[i].key, pairs[i].value, output_buffer, &output_pos)) {
            return error.ZonEncodeFailed;
        }
    }
    std.debug.assert(output_pos <= MAX_ZON_SIZE);
    const result_data = try allocator.alloc(u8, output_pos);
    @memcpy(result_data, output_buffer[0..output_pos]);
    return ZonEncodeResult{
        .data = result_data,
        .len = output_pos,
        .allocator = allocator,
    };
}

// Nested object field.
pub const ZonNestedField = struct {
    key: []const u8,
    value: ZonValue,
};

// Encode nested object to ZON format.
pub fn encode_nested_object_zon(
    prefix: []const u8,
    fields: []const ZonNestedField,
    allocator: std.mem.Allocator,
) !ZonEncodeResult {
    std.debug.assert(prefix.len > 0);
    std.debug.assert(fields.len > 0);
    std.debug.assert(allocator != null);
    var output_buffer = try allocator.alloc(u8, @as(usize, @intCast(MAX_ZON_SIZE)));
    errdefer allocator.free(output_buffer);
    var output_pos: u32 = 0;
    if (!encode_nested_object_internal(prefix, fields, output_buffer, &output_pos)) {
        allocator.free(output_buffer);
        return error.ZonEncodeFailed;
    }
    std.debug.assert(output_pos <= MAX_ZON_SIZE);
    const result_data = try allocator.alloc(u8, output_pos);
    @memcpy(result_data, output_buffer[0..output_pos]);
    allocator.free(output_buffer);
    return ZonEncodeResult{
        .data = result_data,
        .len = output_pos,
        .allocator = allocator,
    };
}

// Encode nested object to ZON format (internal).
fn encode_nested_object_internal(
    prefix: []const u8,
    fields: []const ZonNestedField,
    output: []u8,
    output_pos: *u32,
) bool {
    std.debug.assert(prefix.len > 0);
    std.debug.assert(fields.len > 0);
    std.debug.assert(output.len > 0);
    if (output_pos.* + prefix.len + 64 > output.len) {
        return false;
    }
    var i: u32 = 0;
    while (i < prefix.len) : (i += 1) {
        output[output_pos.*] = prefix[i];
        output_pos.* += 1;
    }
    output[output_pos.*] = '{';
    output_pos.* += 1;
    i = 0;
    while (i < fields.len) : (i += 1) {
        if (i > 0) {
            output[output_pos.*] = ',';
            output_pos.* += 1;
        }
        const field = fields[i];
        var j: u32 = 0;
        while (j < field.key.len) : (j += 1) {
            output[output_pos.*] = field.key[j];
            output_pos.* += 1;
        }
        output[output_pos.*] = ':';
        output_pos.* += 1;
        switch (field.value.value_type) {
            .bool_value => {
                if (!encode_bool(field.value.bool_val, output, output_pos)) {
                    return false;
                }
            },
            .u32_value => {
                if (!encode_u32(field.value.u32_val, output, output_pos)) {
                    return false;
                }
            },
            .u64_value => {
                if (!encode_u64(field.value.u64_val, output, output_pos)) {
                    return false;
                }
            },
            .string_value => {
                const str_val = field.value.string_val[0..field.value.string_val_len];
                if (!encode_string(str_val, output, output_pos)) {
                    return false;
                }
            },
            else => return false,
        }
    }
    output[output_pos.*] = '}';
    output_pos.* += 1;
    std.debug.assert(output_pos.* <= output.len);
    return true;
}

// ZON decoding result.
pub const ZonDecodeResult = struct {
    pairs: []struct { key: []const u8, value: ZonValue },
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ZonDecodeResult) void {
        std.debug.assert(self.allocator != null);
        self.allocator.free(self.pairs);
        self.* = undefined;
    }
};

// Decode ZON format to key-value pairs.
pub fn decode_zon(
    zon_data: []const u8,
    allocator: std.mem.Allocator,
) !ZonDecodeResult {
    std.debug.assert(zon_data.len > 0);
    std.debug.assert(allocator != null);
    var pairs = std.ArrayList(struct { key: []const u8, value: ZonValue }).init(allocator);
    defer pairs.deinit();
    var pos: u32 = 0;
    while (pos < zon_data.len) {
        while (pos < zon_data.len and (zon_data[pos] == '\n' or zon_data[pos] == ' ')) {
            pos += 1;
        }
        if (pos >= zon_data.len) {
            break;
        }
        const key_start = pos;
        while (pos < zon_data.len and zon_data[pos] != ':') {
            pos += 1;
        }
        if (pos >= zon_data.len) {
            return error.InvalidZonFormat;
        }
        const key = zon_data[key_start..pos];
        pos += 1;
        if (pos >= zon_data.len) {
            return error.InvalidZonFormat;
        }
        if (zon_data[pos] == '@') {
            pos += 1;
            if (pos >= zon_data.len or zon_data[pos] != '(') {
                return error.InvalidZonFormat;
            }
            pos += 1;
            var count: u32 = 0;
            while (pos < zon_data.len and zon_data[pos] >= '0' and zon_data[pos] <= '9') {
                count = count * 10 + (zon_data[pos] - '0');
                pos += 1;
            }
            if (pos >= zon_data.len or zon_data[pos] != ')') {
                return error.InvalidZonFormat;
            }
            pos += 1;
            if (pos >= zon_data.len or zon_data[pos] != ':') {
                return error.InvalidZonFormat;
            }
            pos += 1;
            while (pos < zon_data.len and zon_data[pos] != '\n') {
                pos += 1;
            }
            if (pos < zon_data.len) {
                pos += 1;
            }
            var row_count: u32 = 0;
            while (row_count < count and pos < zon_data.len) {
                while (pos < zon_data.len and zon_data[pos] != '\n') {
                    pos += 1;
                }
                if (pos < zon_data.len) {
                    pos += 1;
                }
                row_count += 1;
            }
            continue;
        }
        const value_start = pos;
        while (pos < zon_data.len and zon_data[pos] != '\n' and zon_data[pos] != ' ') {
            pos += 1;
        }
        const value_str = zon_data[value_start..pos];
        const value = try parse_zon_value(value_str, allocator);
        try pairs.append(.{ .key = key, .value = value });
        if (pos < zon_data.len and zon_data[pos] == '\n') {
            pos += 1;
        }
    }
    const result_pairs = try allocator.alloc(
        struct { key: []const u8, value: ZonValue },
        pairs.items.len,
    );
    var i: u32 = 0;
    while (i < pairs.items.len) : (i += 1) {
        result_pairs[i] = pairs.items[i];
    }
    std.debug.assert(result_pairs.len == pairs.items.len);
    return ZonDecodeResult{
        .pairs = result_pairs,
        .allocator = allocator,
    };
}

// Parse ZON value from string.
fn parse_zon_value(value_str: []const u8, allocator: std.mem.Allocator) !ZonValue {
    std.debug.assert(value_str.len > 0);
    std.debug.assert(allocator != null);
    if (std.mem.eql(u8, value_str, "T")) {
        return ZonValue.from_bool(true);
    }
    if (std.mem.eql(u8, value_str, "F")) {
        return ZonValue.from_bool(false);
    }
    if (std.mem.eql(u8, value_str, "null")) {
        return ZonValue{
            .value_type = .null_value,
            .bool_val = false,
            .u32_val = 0,
            .u64_val = 0,
            .i32_val = 0,
            .i64_val = 0,
            .f32_val = 0.0,
            .f64_val = 0.0,
            .string_val = undefined,
            .string_val_len = 0,
        };
    }
    var is_number = true;
    var i: u32 = 0;
    while (i < value_str.len) : (i += 1) {
        if (value_str[i] < '0' or value_str[i] > '9') {
            is_number = false;
            break;
        }
    }
    if (is_number and value_str.len > 0) {
        var num: u32 = 0;
        i = 0;
        while (i < value_str.len) : (i += 1) {
            num = num * 10 + (value_str[i] - '0');
        }
        return ZonValue.from_u32(num);
    }
    return ZonValue.from_string(value_str);
}

// Round-trip test result for integration validation.
pub const RoundTripTestResult = struct {
    original_pairs: []const struct { key: []const u8, value: ZonValue },
    encoded_data: []const u8,
    decoded_pairs: []const struct { key: []const u8, value: ZonValue },
    success: bool,
    data_integrity: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *RoundTripTestResult) void {
        std.debug.assert(self.allocator != null);
        if (self.encoded_data.len > 0) {
            self.allocator.free(self.encoded_data);
        }
        if (self.decoded_pairs.len > 0) {
            self.allocator.free(self.decoded_pairs);
        }
        self.* = undefined;
    }
};

// Perform round-trip test (encode then decode).
pub fn round_trip_test(
    pairs: []const struct { key: []const u8, value: ZonValue },
    allocator: std.mem.Allocator,
) !RoundTripTestResult {
    std.debug.assert(pairs.len > 0);
    std.debug.assert(allocator != null);
    const encode_result = try encode_zon(pairs, allocator);
    defer encode_result.deinit();
    const encoded_data = try allocator.alloc(u8, encode_result.len);
    @memcpy(encoded_data, encode_result.data[0..encode_result.len]);
    const decode_result = try decode_zon(encoded_data, allocator);
    defer decode_result.deinit();
    const decoded_pairs = try allocator.alloc(
        struct { key: []const u8, value: ZonValue },
        decode_result.pairs.len,
    );
    var i: u32 = 0;
    while (i < decode_result.pairs.len) : (i += 1) {
        decoded_pairs[i] = decode_result.pairs[i];
    }
    var success = true;
    var data_integrity = true;
    if (pairs.len != decode_result.pairs.len) {
        success = false;
        data_integrity = false;
    } else {
        i = 0;
        while (i < pairs.len) : (i += 1) {
            if (!std.mem.eql(u8, pairs[i].key, decode_result.pairs[i].key)) {
                success = false;
                data_integrity = false;
                break;
            }
            if (pairs[i].value.value_type != decode_result.pairs[i].value.value_type) {
                success = false;
                data_integrity = false;
                break;
            }
            switch (pairs[i].value.value_type) {
                .bool_value => {
                    if (pairs[i].value.bool_val != decode_result.pairs[i].value.bool_val) {
                        success = false;
                        data_integrity = false;
                        break;
                    }
                },
                .u32_value => {
                    if (pairs[i].value.u32_val != decode_result.pairs[i].value.u32_val) {
                        success = false;
                        data_integrity = false;
                        break;
                    }
                },
                .string_value => {
                    const str1 = pairs[i].value.string_val[0..pairs[i].value.string_val_len];
                    const str2 = decode_result.pairs[i].value.string_val[0..decode_result.pairs[i].value.string_val_len];
                    if (!std.mem.eql(u8, str1, str2)) {
                        success = false;
                        data_integrity = false;
                        break;
                    }
                },
                else => {},
            }
        }
    }
    std.debug.assert(encoded_data.len > 0);
    return RoundTripTestResult{
        .original_pairs = pairs,
        .encoded_data = encoded_data,
        .decoded_pairs = decoded_pairs,
        .success = success,
        .data_integrity = data_integrity,
        .allocator = allocator,
    };
}

// Performance benchmark for encoding.
pub fn benchmark_encode(
    pairs: []const struct { key: []const u8, value: ZonValue },
    iterations: u32,
    allocator: std.mem.Allocator,
) !u64 {
    std.debug.assert(pairs.len > 0);
    std.debug.assert(iterations > 0);
    std.debug.assert(iterations <= 10000);
    std.debug.assert(allocator != null);
    const start_time = std.time.nanoTimestamp();
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        const result = try encode_zon(pairs, allocator);
        result.deinit();
    }
    const end_time = std.time.nanoTimestamp();
    const elapsed_ns = @as(u64, @intCast(end_time - start_time));
    const elapsed_ms = elapsed_ns / 1_000_000;
    std.debug.assert(elapsed_ms > 0);
    return elapsed_ms;
}

// Performance benchmark for decoding.
pub fn benchmark_decode(
    zon_data: []const u8,
    iterations: u32,
    allocator: std.mem.Allocator,
) !u64 {
    std.debug.assert(zon_data.len > 0);
    std.debug.assert(iterations > 0);
    std.debug.assert(iterations <= 10000);
    std.debug.assert(allocator != null);
    const start_time = std.time.nanoTimestamp();
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        const result = try decode_zon(zon_data, allocator);
        result.deinit();
    }
    const end_time = std.time.nanoTimestamp();
    const elapsed_ns = @as(u64, @intCast(end_time - start_time));
    const elapsed_ms = elapsed_ns / 1_000_000;
    std.debug.assert(elapsed_ms > 0);
    return elapsed_ms;
}

// ZON encoding errors.
pub const ZonEncodeError = error{
    ZonEncodeBufferFull,
    ZonEncodeFailed,
    InvalidZonFormat,
    ZonDecodeFailed,
};
