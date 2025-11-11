const std = @import("std");

pub const MenuEntry = struct {
    title: []const u8,
    action: ?[]const u8 = null,
};

pub const WindowConfig = struct {
    title: []const u8 = "Aurora",
    menu: []const MenuEntry = &.{},
};

pub const App = struct {
    allocator: std.mem.Allocator,
    config: WindowConfig,

    pub fn init(allocator: std.mem.Allocator, config: WindowConfig) !App {
        return App{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn present(self: *App) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("[Aurora] presenting window '{s}' with menu:\n", .{self.config.title});
        for (self.config.menu) |entry| {
            try stdout.print("  - {s}\n", .{entry.title});
        }
        try stdout.writeAll("[Aurora] macOS traffic lights simulated (red/yellow/green).\n");
    }

    pub fn deinit(self: *App) void {
        _ = self;
    }
};

test "aurora cocoa logs menu" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var app = try App.init(arena.allocator(), .{
        .title = "Aurora Test",
        .menu = &.{ .{ .title = "Aurora" }, .{ .title = "File" } },
    });
    defer app.deinit();

    try app.present();
}
