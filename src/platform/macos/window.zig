const std = @import("std");

pub const Window = struct {
    title: []const u8,

    pub fn init(title: []const u8) Window {
        return .{ .title = title };
    }

    pub fn show(self: *Window) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("[macOS] window '{s}' with traffic lights ready\n", .{self.title});
        try stdout.writeAll("[macOS] menu: Aurora | File | Edit | Selection | View | Go | Run | Terminal | Window | Help\n");
    }
};
