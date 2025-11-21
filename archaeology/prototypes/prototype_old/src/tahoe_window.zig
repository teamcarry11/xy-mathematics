const std = @import("std");

/// TahoeSandbox is the future host for the Mach/Metal window that will blend
/// Vegan Tiger aesthetics with Grain terminal panes. For now it is a stub that
/// keeps the TigerStyle contract explicit.
pub const TahoeSandbox = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TahoeSandbox {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TahoeSandbox) void {
        _ = self;
        // Eventually release Metal surfaces, keybinding controllers, etc.
    }

    pub fn tick(self: *TahoeSandbox) void {
        _ = self;
        // Placeholder render loop iteration.
    }
};

test "tahoe sandbox placeholder" {
    var sandbox = TahoeSandbox.init(std.testing.allocator);
    sandbox.tick();
    sandbox.deinit();
}
