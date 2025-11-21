const std = @import("std");

/// riscv_sys: placeholder syscall interface for future Grain kernel.
pub const Sys = struct {
    pub fn open(path: []const u8, flags: u32) !u32 {
        _ = path;
        _ = flags;
        return error.Unsupported;
    }

    pub fn renderScanline(buffer: []const u8) !void {
        _ = buffer;
        return error.Unsupported;
    }

    pub fn timestamp() u64 {
        return @as(u64, @intCast(std.time.timestamp()));
    }

    pub fn panic(msg: []const u8) noreturn {
        std.debug.panic("riscv_sys panic: {s}", .{msg});
    }
};

test "riscv sys timestamp monotonic-ish" {
    const a = Sys.timestamp();
    const b = Sys.timestamp();
    try std.testing.expect(b >= a);
}
