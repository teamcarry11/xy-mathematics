const std = @import("std");

/// GrainPulse: libuv-style loop tuned for TigerStyle stacks.
/// Glow G2 Airbend:
///   ~~~\  )
///      |\/
///      |/  steady breath, steady packets.
pub const GrainPulse = struct {
    allocator: std.mem.Allocator,
    backend: Backend,
    udp_slots: std.ArrayListUnmanaged(UdpSlot),

    pub fn init(allocator: std.mem.Allocator, config: PulseConfig) GrainPulse {
        std.debug.assert(config.max_handlers > 0);
        return .{
            .allocator = allocator,
            .backend = config.backend,
            .udp_slots = .{},
        };
    }

    pub fn deinit(self: *GrainPulse) void {
        var i: usize = self.udp_slots.items.len;
        while (i > 0) {
            i -= 1;
            var slot = self.udp_slots.items[i];
            self.allocator.free(slot.buffer);
        }
        self.udp_slots.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn registerUdp(
        self: *GrainPulse,
        spec: UdpSpec,
        handler: UdpHandler,
        ctx: *anyopaque,
    ) !usize {
        std.debug.assert(spec.buffer_len > 0);
        const buffer = try self.allocator.alloc(u8, spec.buffer_len);
        errdefer self.allocator.free(buffer);
        const slot = UdpSlot{
            .spec = spec,
            .buffer = buffer,
            .handler = handler,
            .ctx = ctx,
        };
        try self.udp_slots.append(self.allocator, slot);
        return self.udp_slots.items.len - 1;
    }

    pub fn handlers(self: GrainPulse) usize {
        return self.udp_slots.items.len;
    }

    pub fn simulateDatagram(
        self: *GrainPulse,
        index: usize,
        payload: []const u8,
        from: std.net.Address,
    ) !void {
        std.debug.assert(index < self.udp_slots.items.len);
        var slot = &self.udp_slots.items[index];
        std.debug.assert(payload.len <= slot.buffer.len);
        std.mem.copyForwards(u8, slot.buffer[0..payload.len], payload);
        try slot.handler(payload, from, slot.ctx);
    }
};

pub const PulseConfig = struct {
    backend: Backend = .auto,
    max_handlers: usize = 16,
};

pub const Backend = enum {
    auto,
    io_uring,
    poll,
};

pub const UdpSpec = struct {
    port: u16,
    buffer_len: usize,
};

pub const UdpHandler = fn (
    payload: []const u8,
    address: std.net.Address,
    ctx: *anyopaque,
) anyerror!void;

pub const UdpSlot = struct {
    spec: UdpSpec,
    buffer: []u8,
    handler: UdpHandler,
    ctx: *anyopaque,
};

test "register stores udp slot with correct buffer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var pulse = GrainPulse.init(gpa.allocator(), .{});
    defer pulse.deinit();

    var calls: usize = 0;
    const cb = struct {
        fn handle(_: []const u8, _: std.net.Address, ctx: *anyopaque) !void {
            var counter: *usize = @ptrCast(*usize, ctx);
            counter.* += 1;
        }
    }.handle;

    const idx = try pulse.registerUdp(.{ .port = 9000, .buffer_len = 64 }, cb, &calls);
    try std.testing.expectEqual(@as(usize, 0), calls);
    try std.testing.expectEqual(@as(usize, 1), pulse.handlers());

    const addr = try std.net.Address.parseIp4("127.0.0.1", 9000);
    const payload = "rain at midnight";
    try pulse.simulateDatagram(idx, payload, addr);
    try std.testing.expectEqual(@as(usize, 1), calls);
}

test "backend configuration reflects io_uring preference" {
    var pulse = GrainPulse.init(std.testing.allocator, .{
        .backend = .io_uring,
        .max_handlers = 4,
    });
    defer pulse.deinit();
    try std.testing.expect(pulse.backend == .io_uring);
}

