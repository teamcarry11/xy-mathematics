const std = @import("std");

const Address = std.net.Address;

/// GrainLoop: TigerStyle UDP event loop inspired by TigerBeetle's io_uring
/// design but adapted for cross-platform musl-friendly builds.
/// It favors static allocation, deterministic dispatch, and no hidden threads.
// ~( )~  Glow Airbend: packets hover, latency stays calm.
// ~/\/\~ Glow Waterbend: streams carve steady channels.
pub const GrainLoop = struct {
    pub const max_udp_slots = 8;
    pub const max_pending = 64;
    pub const max_payload = 1472; // fits within typical UDP MTU with headers.

    /// GrainDatagram: typed payload we circulate within the event loop.
    pub const GrainDatagram = struct {
        source: Address,
        length: u16,
        payload: [max_payload]u8,
    };

    pub const Listener = struct {
        callback: *const fn (context: *anyopaque, datagram: GrainDatagram) void,
        context: *anyopaque,
    };

    const UdpSlot = struct {
        address: Address,
        listener: Listener,
    };

    allocator: std.mem.Allocator,
    udp_slots: [max_udp_slots]?UdpSlot,
    pending: std.ArrayListUnmanaged(GrainDatagram),

    pub fn init(allocator: std.mem.Allocator) GrainLoop {
        const loop = GrainLoop{
            .allocator = allocator,
            .udp_slots = .{null} ** max_udp_slots,
            .pending = .{},
        };
        return loop;
    }

    pub fn deinit(self: *GrainLoop) void {
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    /// register_udp: reserve a slot for a UDP listener. Returns slot index.
    pub fn register_udp(
        self: *GrainLoop,
        address: Address,
        listener: Listener,
    ) !usize {
        var i: usize = 0;
        while (i < max_udp_slots) : (i += 1) {
            if (self.udp_slots[i] == null) {
                self.udp_slots[i] = UdpSlot{
                    .address = address,
                    .listener = listener,
                };
                return i;
            }
        }
        return error.TooManyUdpSlots;
    }

    pub fn unregister_udp(self: *GrainLoop, slot: usize) void {
        if (slot < max_udp_slots) {
            self.udp_slots[slot] = null;
        }
    }

    /// queue_datagram: static helper to enqueue data from the network.
    pub fn queue_datagram(self: *GrainLoop, datagram: GrainDatagram) !void {
        if (self.pending.items.len >= max_pending) {
            return error.PendingOverflow;
        }
        try self.pending.append(self.allocator, datagram);
    }

    /// pump: deliver queued datagrams to their listeners deterministically.
    pub fn pump(self: *GrainLoop, max_dispatch: usize) void {
        var dispatched: usize = 0;
        while (self.pending.items.len > 0 and dispatched < max_dispatch) {
            const datagram = self.pending.orderedRemove(0);
            dispatched += 1;

            var i: usize = 0;
            while (i < max_udp_slots) : (i += 1) {
                if (self.udp_slots[i]) |slot| {
                    if (slot.address.eql(datagram.source)) {
                        slot.listener.callback(slot.listener.context, datagram);
                        break;
                    }
                }
            }
        }
    }

    /// inject_test_datagram: testing helper to avoid actual sockets.
    pub fn inject_test_datagram(
        self: *GrainLoop,
        source: Address,
        payload: []const u8,
    ) !void {
        if (payload.len > max_payload) return error.PayloadTooLarge;
        var message = GrainDatagram{
            .source = source,
            .length = @as(u16, @intCast(payload.len)),
            .payload = undefined,
        };
        std.mem.copyForwards(u8, message.payload[0..payload.len], payload);
        try self.queue_datagram(message);
    }
};

test "register, inject, and dispatch datagram" {
    var loop = GrainLoop.init(std.testing.allocator);
    defer loop.deinit();

    var received = false;

    const listener = GrainLoop.Listener{
        .callback = test_loop_on_datagram,
        .context = @ptrCast(&received),
    };

    const addr = try Address.parseIp4("127.0.0.1", 9000);
    _ = try loop.register_udp(addr, listener);

    try loop.inject_test_datagram(addr, "abc");
    loop.pump(4);

    try std.testing.expect(received);
}

fn test_loop_on_datagram(
    ctx: *anyopaque,
    datagram: GrainLoop.GrainDatagram,
) void {
    const flag_ptr: *bool = @ptrCast(ctx);
    flag_ptr.* = datagram.length == 3 and datagram.payload[0] == 'a';
}
