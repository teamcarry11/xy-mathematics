const std = @import("std");

pub const ClusterEndpoint = struct {
    host: []const u8,
    port: u16,
};

pub const RelayEndpoint = struct {
    url: []const u8,
};

pub const Client = struct {
    allocator: std.mem.Allocator,
    cluster: []const ClusterEndpoint,
    relays: []const RelayEndpoint,

    pub fn init(
        allocator: std.mem.Allocator,
        cluster: []const ClusterEndpoint,
        relays: []const RelayEndpoint,
    ) Client {
        return .{
            .allocator = allocator,
            .cluster = cluster,
            .relays = relays,
        };
    }

    pub fn submitTigerBeetle(
        self: *Client,
        payload: []const u8,
    ) !void {
        _ = payload;
        if (self.cluster.len == 0) return error.NoClusterEndpoints;
        for (self.cluster) |endpoint| {
            std.debug.print(
                "TigerBank stub: would submit {d} bytes to {s}:{d}\n",
                .{ payload.len, endpoint.host, endpoint.port },
            );
        }
    }

    pub fn broadcastRelays(
        self: *Client,
        payload: []const u8,
    ) !void {
        if (self.relays.len == 0) {
            std.debug.print(
                "TigerBank stub: no relays configured; skipping broadcast\n",
                .{},
            );
            return;
        }
        for (self.relays) |relay| {
            std.debug.print(
                "TigerBank stub: would POST {d} bytes to {s}\n",
                .{ payload.len, relay.url },
            );
        }
    }
};

test "client rejects empty cluster" {
    const client_cluster: [0]ClusterEndpoint = .{};
    const client_relays: [0]RelayEndpoint = .{};
    var client = Client.init(std.testing.allocator, client_cluster[0..], client_relays[0..]);
    try std.testing.expectError(
        error.NoClusterEndpoints,
        client.submitTigerBeetle("payload"),
    );
}
