const std = @import("std");
const GrainLoom = @import("grain_loom.zig").GrainLoom;
const GrainRoute = @import("grain_route.zig").GrainRoute;

/// GrainOrchestrator coordinates Graindaemon, Aurora views, and agents.
pub const GrainOrchestrator = struct {
    pub const AgentSpec = struct {
        id: []const u8,
        persona: []const u8,
        tools: []const ToolSpec,
    };

    pub const ToolSpec = struct {
        name: []const u8,
        description: []const u8,
        endpoint: []const u8,
    };

    allocator: std.mem.Allocator,
    loom: GrainLoom,
    router: GrainRoute,
    agents: std.ArrayListUnmanaged(AgentSpec),

    pub fn init(
        allocator: std.mem.Allocator,
        loom: GrainLoom,
        router: GrainRoute,
    ) GrainOrchestrator {
        return GrainOrchestrator{
            .allocator = allocator,
            .loom = loom,
            .router = router,
            .agents = .{},
        };
    }

    pub fn deinit(self: *GrainOrchestrator) void {
        self.agents.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn registerAgent(self: *GrainOrchestrator, spec: AgentSpec) !void {
        try self.agents.append(self.allocator, spec);
    }

    pub fn findRoute(self: *GrainOrchestrator, url: []const u8) ?GrainRoute.Match {
        return self.router.match(url);
    }

    pub fn agentCount(self: *GrainOrchestrator) usize {
        return self.agents.items.len;
    }
};

test "grain orchestrator registers agents" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var loom = try GrainLoom.init(arena.allocator(), "boot", "status     ");
    defer loom.deinit();

    const routes = [_]GrainRoute.RouteSpec{
        .{ .npub_prefix = "npub1", .path = &.{}, .component_id = "home" },
    };
    var orchestrator = GrainOrchestrator.init(arena.allocator(), loom, GrainRoute.init(&routes));
    defer orchestrator.deinit();

    try orchestrator.registerAgent(.{
        .id = "glow",
        .persona = "Glow G2",
        .tools = &.{.{ .name = "cursor-cli", .description = "Cursor pipeline", .endpoint = "cursor://" }},
    });
    try std.testing.expectEqual(@as(usize, 1), orchestrator.agentCount());
}
