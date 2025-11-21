const std = @import("std");
const Graindaemon = @import("../src/graindaemon.zig").Graindaemon;

// ~<o>~ Glow Airbend CLI: keep the run loop light and observable.
// ~~~~~ Glow Waterbend CLI: flow config values into static buffers.

pub const CliConfig = struct {
    watch_space: []const u8,
    alloc_limit_bytes: u64,
};

pub fn main() !void {
    var buffer: [1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fixed.allocator();

    const config = parse_args(allocator) catch |err| switch (err) {
        error.HelpRequested => {
            try print_usage();
            return;
        },
        else => return err,
    };

    var daemon = Graindaemon.init(allocator);
    defer daemon.deinit();

    try daemon.handle(.boot);
    try daemon.handle(.{ .tick = 1 });

    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        "graindaemon watch={s} alloc={d} state={s}\n",
        .{ config.watch_space, config.alloc_limit_bytes, @tagName(daemon.state) },
    );
}

fn parse_args(allocator: std.mem.Allocator) !CliConfig {
    var raw = try std.process.argsWithAllocator(allocator);
    defer raw.deinit();

    var wrapper = ProcessArgs{ .iter = &raw };
    return parse_args_inner(allocator, &wrapper);
}

fn parse_u64(text: []const u8) !u64 {
    return std.fmt.parseUnsigned(u64, text, 10);
}

fn print_usage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\Usage: graindaemon [--watch <path>] [--alloc <bytes>]
        \\  --watch  Directory or alias to supervise (default: xy)
        \\  --alloc  Maximum bytes for allocator (default: 33554432)
        \\  --help   Show this help text
        \\
    , .{});
}

test "parse_args default config" {
    var buffer: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fixed.allocator();

    const config = try parse_args_synthetic(allocator, &[_][]const u8{"graindaemon"});
    try std.testing.expectEqualStrings("xy", config.watch_space);
    try std.testing.expectEqual(@as(u64, 32 * 1024 * 1024), config.alloc_limit_bytes);
}

test "parse_args overrides" {
    var buffer: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fixed.allocator();

    const config = try parse_args_synthetic(
        allocator,
        &[_][]const u8{ "graindaemon", "--watch", "grain", "--alloc", "65536" },
    );
    try std.testing.expectEqualStrings("grain", config.watch_space);
    try std.testing.expectEqual(@as(u64, 65536), config.alloc_limit_bytes);
}

fn parse_args_synthetic(
    allocator: std.mem.Allocator,
    synthetic: []const []const u8,
) !CliConfig {
    var iterator = SyntheticArgs{
        .items = synthetic,
        .index = 0,
    };
    return parse_args_inner(allocator, &iterator);
}

const ProcessArgs = struct {
    iter: *std.process.ArgIterator,

    fn next(self: *ProcessArgs) ?[]const u8 {
        return self.iter.next();
    }
};

const SyntheticArgs = struct {
    items: []const []const u8,
    index: usize,

    fn next(self: *SyntheticArgs) ?[]const u8 {
        if (self.index >= self.items.len) return null;
        const item = self.items[self.index];
        self.index += 1;
        return item;
    }
};

fn parse_args_inner(
    allocator: std.mem.Allocator,
    iter: anytype,
) !CliConfig {
    var config = CliConfig{
        .watch_space = "xy",
        .alloc_limit_bytes = 32 * 1024 * 1024,
    };
    var watch_storage: ?[]u8 = null;

    _ = iter.next();
    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--watch")) {
            const value = iter.next() orelse return error.MissingWatchValue;
            watch_storage = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, arg, "--alloc")) {
            const value = iter.next() orelse return error.MissingAllocValue;
            config.alloc_limit_bytes = try parse_u64(value);
        } else if (std.mem.eql(u8, arg, "--help")) {
            return error.HelpRequested;
        } else {
            return error.UnknownFlag;
        }
    }
    if (watch_storage) |watch| config.watch_space = watch;
    return config;
}
