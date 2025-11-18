// Simple test at commit 0d618a3
const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const Syscall = basin_kernel.Syscall;
const MapFlags = basin_kernel.MapFlags;

test "006_simple_at_commit" {
    std.debug.print("[test] Starting simple test at commit 0d618a3\n", .{});
    var kernel = BasinKernel.init();
    std.debug.print("[test] Kernel initialized\n", .{});
    
    // Simple map: kernel chooses address, 4KB, read+write
    const flags = MapFlags.init(.{ .read = true, .write = true });
    std.debug.print("[test] Calling map syscall\n", .{});
    
    const result = kernel.handle_syscall(
        @intFromEnum(Syscall.map),
        0,
        4096,
        @as(u64, @as(u32, @bitCast(flags))),
        0,
    ) catch |err| {
        std.debug.print("[test] Map failed: {}\n", .{err});
        return;
    };
    
    std.debug.print("[test] Map succeeded: 0x{x}\n", .{result.success});
    std.debug.print("[test] Test complete\n", .{});
}

