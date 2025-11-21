const std = @import("std");
const Graindaemon = @import("graindaemon.zig").Graindaemon;
const GrainLoop = @import("grain_loop.zig").GrainLoop;
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;

/// GrainLoom — unified framework for Grain networked apps.
// ~(\\\\)~ Glow Airbend: weave command, status, logs into one cloth.
// ~~~~~~~~ Glow Waterbend: stream updates without tearing read-only seams.
pub const GrainLoom = struct {
    const StatusRegion = struct {
        start: usize,
        len: usize,
    };

    allocator: std.mem.Allocator,
    daemon: Graindaemon,
    terminal: GrainBuffer,
    status: StatusRegion,

    pub fn init(
        allocator: std.mem.Allocator,
        command_line: []const u8,
        status_line: []const u8,
    ) !GrainLoom {
        const daemon = Graindaemon.init(allocator);
        var terminal = GrainBuffer.init(allocator);
        try terminal.append(command_line);
        try terminal.append("\n");
        const status_start = terminal.textSlice().len;
        try terminal.append(status_line);
        try terminal.append("\n");
        const status_len = terminal.textSlice().len - status_start - 1; // exclude newline
        try terminal.markReadOnly(status_start, status_start + status_len);

        return GrainLoom{
            .allocator = allocator,
            .daemon = daemon,
            .terminal = terminal,
            .status = .{ .start = status_start, .len = status_len },
        };
    }

    pub fn deinit(self: *GrainLoom) void {
        self.daemon.deinit();
        self.terminal.deinit();
        self.* = undefined;
    }

    pub fn buffer(self: *GrainLoom) *GrainBuffer {
        return &self.terminal;
    }

    pub fn loopPtr(self: *GrainLoom) *GrainLoop {
        return self.daemon.loopPtr();
    }

    pub fn updateStatus(self: *GrainLoom, status_line: []const u8) !void {
        if (status_line.len > self.status.len) return error.StatusTooLong;
        try self.terminal.overwriteSystem(self.status.start, status_line);
        const pad = self.status.len - status_line.len;
        if (pad > 0) {
            const scratch = try self.allocator.alloc(u8, pad);
            defer self.allocator.free(scratch);
            @memset(scratch, ' ');
            try self.terminal.overwriteSystem(self.status.start + status_line.len, scratch);
        }
    }

    pub fn handle(self: *GrainLoom, event: Graindaemon.Event) !void {
        switch (event) {
            .boot => try self.updateStatus("warming..."),
            .tick => |ts| {
                _ = ts;
                try self.updateStatus("running...");
            },
            .udp_received => |packet| {
                const payload = packet.payload[0..packet.length];
                try self.terminal.append(payload);
                try self.terminal.append("\n");
            },
            .fault => |why| try self.updateStatus(why),
        }
        try self.daemon.handle(event);
    }
};

test "loom keeps status read-only for user but mutable for system" {
    var buffer: [512]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fixed.allocator();

    var loom = try GrainLoom.init(allocator, "cargo run", "idle          ");
    defer loom.deinit();

    const status_slice = loom.buffer().textSlice()[loom.status.start .. loom.status.start + loom.status.len];
    try std.testing.expectEqualStrings("idle", std.mem.trimRight(u8, status_slice, " "));

    try loom.handle(.boot);
    const warmed = loom.buffer().textSlice()[loom.status.start .. loom.status.start + loom.status.len];
    try std.testing.expectEqualStrings("warming...", std.mem.trimRight(u8, warmed, " "));

    try loom.handle(.{ .fault = "panic!" });
    const faulted = loom.buffer().textSlice()[loom.status.start .. loom.status.start + loom.status.len];
    try std.testing.expectEqualStrings("panic!", std.mem.trimRight(u8, faulted, " "));
}

test "loom appends udp logs after status" {
    var buffer: [512]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fixed.allocator();

    var loom = try GrainLoom.init(allocator, "grain conduct run", "ready         ");
    defer loom.deinit();

    const addr = try std.net.Address.parseIp4("127.0.0.1", 9999);
    var packet = GrainLoop.GrainDatagram{
        .source = addr,
        .length = 5,
        .payload = undefined,
    };
    std.mem.copyForwards(u8, packet.payload[0..packet.length], "hello");

    try loom.handle(.boot);
    try loom.handle(.{ .udp_received = packet });

    const text = loom.buffer().textSlice();
    try std.testing.expect(std.mem.endsWith(u8, text, "hello\n"));
}
