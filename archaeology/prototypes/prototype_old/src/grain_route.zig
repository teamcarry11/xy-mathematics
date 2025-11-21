const std = @import("std");

/// GrainRoute: static npub-aware routing for GrainAurora.
pub const GrainRoute = struct {
    pub const RouteSpec = struct {
        npub_prefix: []const u8,
        path: []const []const u8,
        component_id: []const u8,
    };

    pub const Match = struct {
        component_id: []const u8,
        params: Params,
    };

    pub const Params = struct {
        npub: []const u8,
        remainder: []const u8,
    };

    routes: []const RouteSpec,

    pub fn init(routes: []const RouteSpec) GrainRoute {
        return GrainRoute{ .routes = routes };
    }

    pub fn match(self: GrainRoute, url: []const u8) ?Match {
        const trimmed = std.mem.trim(u8, url, "/");
        var parts_it = std.mem.splitScalar(u8, trimmed, '/');
        const npub = parts_it.next() orelse return null;
        const remainder_start = trimmed[0..npub.len];
        const remainder = trimmed[remainder_start.len..];

        while (parts_it.next()) |_| {} // consume for now

        for (self.routes) |route| {
            if (std.mem.startsWith(u8, npub, route.npub_prefix)) {
                return Match{
                    .component_id = route.component_id,
                    .params = .{ .npub = npub, .remainder = remainder },
                };
            }
        }
        return null;
    }
};

test "grain route matches prefix" {
    const route_table = [_]GrainRoute.RouteSpec{
        .{
            .npub_prefix = "npub1grn",
            .path = &.{"timeline"},
            .component_id = "timeline",
        },
    };
    const router = GrainRoute.init(&route_table);
    const match = router.match("/npub1grnz9wf/timeline") orelse return std.testing.expect(false);
    try std.testing.expectEqualStrings("timeline", match.component_id);
    try std.testing.expectEqualStrings("npub1grnz9wf", match.params.npub);
}
