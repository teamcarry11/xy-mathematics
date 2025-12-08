const RawIO = @import("raw_io.zig");
const std = @import("std");

/// Grain Style: Explicit logging levels
pub const LogLevel = enum {
    debug,
    info,
    warn,
    error_lvl, // 'error' is a keyword
};

/// Grain Style: Minimal kprint implementation to avoid heavy std dependencies
/// and linker errors with atomics.
/// Grain Style: Minimal kprint implementation to avoid heavy std dependencies
/// and linker errors with atomics.
pub fn kprint(comptime fmt: []const u8, args: anytype) void {
    var arg_idx: usize = 0;
    var i: usize = 0;
    while (i < fmt.len) {
        if (fmt[i] == '{') {
            // Handle format specifier
            if (i + 1 < fmt.len and fmt[i+1] == '}') {
                // Simple {}
                print_arg(args, arg_idx);
                arg_idx += 1;
                i += 2;
            } else if (i + 2 < fmt.len and fmt[i+1] == 'd' and fmt[i+2] == '}') {
                // {d} decimal
                print_arg(args, arg_idx);
                arg_idx += 1;
                i += 3;
            } else if (i + 2 < fmt.len and fmt[i+1] == 'x' and fmt[i+2] == '}') {
                // {x} hex
                print_hex_arg(args, arg_idx);
                arg_idx += 1;
                i += 3;
            } else if (i + 2 < fmt.len and fmt[i+1] == 's' and fmt[i+2] == '}') {
                // {s} string
                print_arg(args, arg_idx);
                arg_idx += 1;
                i += 3;
            } else {
                // Unknown, just print char
                RawIO.write_byte(fmt[i]);
                i += 1;
            }
        } else {
            RawIO.write_byte(fmt[i]);
            i += 1;
        }
    }
}

fn print_arg(args: anytype, idx: usize) void {
    inline for (std.meta.fields(@TypeOf(args)), 0..) |field, i| {
        if (i == idx) {
            const val = @field(args, field.name);
            const T = @TypeOf(val);
            if (T == []const u8) {
                RawIO.write(val);
            } else {
                switch (@typeInfo(T)) {
                    .int => print_int(val),
                    .bool => if (val) RawIO.write("true") else RawIO.write("false"),
                    else => RawIO.write("?"),
                }
            }
            return;
        }
    }
}

fn print_hex_arg(args: anytype, idx: usize) void {
    inline for (std.meta.fields(@TypeOf(args)), 0..) |field, i| {
        if (i == idx) {
            const val = @field(args, field.name);
            const T = @TypeOf(val);
            switch (@typeInfo(T)) {
                .int => print_hex(val),
                else => RawIO.write("?"),
            }
            return;
        }
    }
}

fn print_int(val: anytype) void {
    if (val == 0) {
        RawIO.write_byte('0');
        return;
    }
    
    var v = val;
    var buf: [32]u8 = undefined;
    var i: usize = 0;
    
    // Handle negative for signed integers
    const info = @typeInfo(@TypeOf(val));
    if (info == .int and info.int.signedness == .signed) {
        if (v < 0) {
            RawIO.write_byte('-');
            v = -v;
        }
    }
    
    while (v > 0) {
        buf[i] = @as(u8, @intCast(v % 10)) + '0';
        v = @divTrunc(v, 10);
        i += 1;
    }
    
    while (i > 0) {
        i -= 1;
        RawIO.write_byte(buf[i]);
    }
}

fn print_hex(val: anytype) void {
    if (val == 0) {
        RawIO.write("0x0");
        return;
    }
    
    RawIO.write("0x");
    var v = val;
    var buf: [32]u8 = undefined;
    var i: usize = 0;
    
    while (v > 0) {
        const digit = @as(u8, @intCast(v % 16));
        if (digit < 10) {
            buf[i] = digit + '0';
        } else {
            buf[i] = digit - 10 + 'a';
        }
        v = @divTrunc(v, 16);
        i += 1;
    }
    
    while (i > 0) {
        i -= 1;
        RawIO.write_byte(buf[i]);
    }
}

/// Grain Style: Explicit assertion with message
pub fn kassert(ok: bool, comptime msg: []const u8, args: anytype) void {
    if (!ok) {
        kprint("\n[ASSERT FAILED] ", .{});
        kprint(msg, args);
        kprint("\n", .{});
        
        // Trap/Hang
        while (true) {
            asm volatile ("wfi");
        }
    }
}

/// Grain Style: Log with level
pub fn log(comptime level: LogLevel, comptime fmt: []const u8, args: anytype) void {
    const prefix = switch (level) {
        .debug => "[DEBUG] ",
        .info => "[INFO]  ",
        .warn => "[WARN]  ",
        .error_lvl => "[ERROR] ",
    };
    
    RawIO.write(prefix);
    kprint(fmt, args);
    RawIO.write("\n");
}
