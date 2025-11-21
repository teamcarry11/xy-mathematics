const std = @import("std");
const GrainLoop = @import("grain_loop.zig").GrainLoop;
const GrainDatagram = GrainLoop.GrainDatagram;

/// Graindaemon: static process supervisor for `xy`, echoing s6/TigerBeetle
/// rigor while keeping the Glow G2 tone.
// ~o~  Airbend brief: hold state machines lightly, recover fast.
// ~~~~ Waterbend brief: flow across replicas without drowning buffers.
pub const Graindaemon = struct {
    pub const max_transitions = 128;

    pub const State = enum {
        cold,
        warm,
        running,
        draining,
        halted,
    };

    pub const Event = union(enum) {
        boot,
        udp_received: GrainDatagram,
        tick: u64,
        fault: []const u8,
    };

    pub const Transition = struct {
        from: State,
        to: State,
        reason: []const u8,
    };

    allocator: std.mem.Allocator,
    loop: GrainLoop,
    state: State,
    timeline: std.ArrayListUnmanaged(Transition),

    pub fn init(allocator: std.mem.Allocator) Graindaemon {
        return Graindaemon{
            .allocator = allocator,
            .loop = GrainLoop.init(allocator),
            .state = .cold,
            .timeline = .{},
        };
    }

    pub fn deinit(self: *Graindaemon) void {
        self.loop.deinit();
        self.timeline.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn loopPtr(self: *Graindaemon) *GrainLoop {
        return &self.loop;
    }

    pub fn record_transition(
        self: *Graindaemon,
        next: State,
        reason: []const u8,
    ) !void {
        if (self.timeline.items.len >= max_transitions) {
            return error.TimelineOverflow;
        }
        const t = Transition{
            .from = self.state,
            .to = next,
            .reason = reason,
        };
        try self.timeline.append(self.allocator, t);
        self.state = next;
    }

    pub fn handle(self: *Graindaemon, event: Event) !void {
        switch (event) {
            .boot => try self.record_transition(.warm, "boot-sequence"),
            .tick => |ts| {
                _ = ts;
                if (self.state == .warm) {
                    try self.record_transition(.running, "scheduler-ready");
                }
            },
            .udp_received => |datagram| {
                if (self.state == .running) {
                    // Process datagram inline; for now we just acknowledge.
                    try self.record_transition(.running, datagram_summary(datagram));
                }
            },
            .fault => |why| {
                try self.record_transition(.draining, why);
            },
        }
    }

    pub fn pump(self: *Graindaemon) void {
        self.loop.pump(GrainLoop.max_pending);
    }

    fn datagram_summary(_: GrainDatagram) []const u8 {
        return "udp-received";
    }
};

test "graindaemon boot and tick" {
    var daemon = Graindaemon.init(std.testing.allocator);
    defer daemon.deinit();

    try daemon.handle(.boot);
    try daemon.handle(.{ .tick = 1 });

    try std.testing.expectEqual(Graindaemon.State.running, daemon.state);
    try std.testing.expect(daemon.timeline.items.len == 2);
}

test "graindaemon records UDP reception" {
    var daemon = Graindaemon.init(std.testing.allocator);
    defer daemon.deinit();

    const addr = try std.net.Address.parseIp4("127.0.0.1", 9001);
    const listener = GrainLoop.Listener{
        .callback = on_udp,
        .context = @ptrCast(&daemon),
    };
    _ = try daemon.loop.register_udp(addr, listener);

    try daemon.handle(.boot);
    try daemon.handle(.{ .tick = 1 });

    try daemon.loop.inject_test_datagram(addr, "xy");
    daemon.pump();

    try std.testing.expect(daemon.timeline.items.len >= 3);
}

fn on_udp(ctx: *anyopaque, datagram: GrainDatagram) void {
    const daemon: *Graindaemon = @ptrCast(@alignCast(ctx));
    _ = daemon.handle(.{ .udp_received = datagram }) catch {};
}
