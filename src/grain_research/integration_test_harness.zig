//! Grain Research Integration Test Harness: Common test infrastructure for integration tests.
//!
//! Why: Provides common test infrastructure for multi-agent integration testing.
//! Enables systematic testing of agent interactions, coordination, and system integration.
//! Architecture: Agent initialization, event bus setup, mock dependencies, test data generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-184500-pst: Integration Testing Patterns Framework (Priority 2)

const std = @import("std");
const grain_flow = @import("../grain_flow/root.zig");
const EventBus = grain_flow.EventBus;
const EventType = grain_flow.EventType;

// Bounded: Max test records.
pub const MAX_TEST_RECORDS: u32 = 1000;

// Bounded: Max test data size (10MB).
pub const MAX_TEST_SIZE: u32 = 10 * 1024 * 1024;

// Bounded: Max test duration (60 seconds).
pub const MAX_TEST_DURATION_MS: u64 = 60_000;

// Bounded: Max agents in test.
pub const MAX_TEST_AGENTS: u32 = 32;

// Test harness: Provides common test infrastructure.
pub const IntegrationTestHarness = struct {
    allocator: std.mem.Allocator,
    event_bus: ?*EventBus,
    agent_ids: std.ArrayList(u32),
    start_time: u64,

    // Initialize test harness.
    pub fn init(allocator: std.mem.Allocator) IntegrationTestHarness {
        return IntegrationTestHarness{
            .allocator = allocator,
            .event_bus = null,
            .agent_ids = std.ArrayList(u32).init(allocator),
            .start_time = 0,
        };
    }

    // Deinitialize test harness.
    pub fn deinit(self: *IntegrationTestHarness) void {
        if (self.event_bus) |bus| {
            bus.deinit();
        }
        self.agent_ids.deinit();
    }

    // Setup event bus for testing.
    pub fn setup_event_bus(self: *IntegrationTestHarness) !void {
        std.debug.assert(self.event_bus == null);

        const bus = try self.allocator.create(EventBus);
        errdefer self.allocator.destroy(bus);
        bus.* = try EventBus.init(self.allocator);
        self.event_bus = bus;
    }

    // Teardown event bus.
    pub fn teardown_event_bus(self: *IntegrationTestHarness) void {
        if (self.event_bus) |bus| {
            bus.deinit();
            self.allocator.destroy(bus);
            self.event_bus = null;
        }
    }

    // Register agent ID for tracking.
    pub fn register_agent_id(self: *IntegrationTestHarness, agent_id: u32) !void {
        std.debug.assert(self.agent_ids.items.len < MAX_TEST_AGENTS);
        try self.agent_ids.append(self.allocator, agent_id);
    }

    // Start test timer.
    pub fn start_timer(self: *IntegrationTestHarness) void {
        self.start_time = std.time.timestamp();
    }

    // Check if test duration exceeded.
    pub fn is_test_timeout(self: *const IntegrationTestHarness) bool {
        if (self.start_time == 0) {
            return false;
        }

        const current_time = std.time.timestamp();
        const elapsed_ms = (current_time - self.start_time) * 1000;
        return elapsed_ms > MAX_TEST_DURATION_MS;
    }

    // Get event bus (if set up).
    pub fn get_event_bus(self: *const IntegrationTestHarness) ?*EventBus {
        return self.event_bus;
    }

    // Get registered agent IDs.
    pub fn get_agent_ids(self: *const IntegrationTestHarness) []const u32 {
        return self.agent_ids.items;
    }
};

// Mock LLM provider for testing.
pub const MockLLMProvider = struct {
    allocator: std.mem.Allocator,
    responses: std.ArrayList([]const u8),
    response_index: u32,

    // Initialize mock LLM provider.
    pub fn init(allocator: std.mem.Allocator) MockLLMProvider {
        return MockLLMProvider{
            .allocator = allocator,
            .responses = std.ArrayList([]const u8).init(allocator),
            .response_index = 0,
        };
    }

    // Deinitialize mock LLM provider.
    pub fn deinit(self: *MockLLMProvider) void {
        for (self.responses.items) |response| {
            self.allocator.free(response);
        }
        self.responses.deinit();
    }

    // Add mock response.
    pub fn add_response(self: *MockLLMProvider, response: []const u8) !void {
        const response_copy = try self.allocator.dupe(u8, response);
        try self.responses.append(self.allocator, response_copy);
    }

    // Get next mock response.
    pub fn get_response(self: *MockLLMProvider) ?[]const u8 {
        if (self.responses.items.len == 0) {
            return null;
        }

        const index = self.response_index % self.responses.items.len;
        self.response_index += 1;
        return self.responses.items[index];
    }

    // Reset response index.
    pub fn reset(self: *MockLLMProvider) void {
        self.response_index = 0;
    }
};

// Mock database for testing.
pub const MockDatabase = struct {
    allocator: std.mem.Allocator,
    data: std.StringHashMap([]const u8),

    // Initialize mock database.
    pub fn init(allocator: std.mem.Allocator) MockDatabase {
        return MockDatabase{
            .allocator = allocator,
            .data = std.StringHashMap([]const u8).init(allocator),
        };
    }

    // Deinitialize mock database.
    pub fn deinit(self: *MockDatabase) void {
        var it = self.data.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.data.deinit();
    }

    // Store data.
    pub fn store(self: *MockDatabase, key: []const u8, value: []const u8) !void {
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= 256);
        std.debug.assert(value.len <= MAX_TEST_SIZE);

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        if (self.data.get(key_copy)) |old_value| {
            self.allocator.free(old_value);
        }
        try self.data.put(key_copy, value_copy);
    }

    // Retrieve data.
    pub fn retrieve(self: *const MockDatabase, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }
};

// Test data generator: Generates test data for integration tests.
pub const TestDataGenerator = struct {
    allocator: std.mem.Allocator,
    rng: std.Random,

    // Initialize test data generator.
    pub fn init(allocator: std.mem.Allocator, seed: u64) TestDataGenerator {
        var prng = std.rand.DefaultPrng.init(seed);
        return TestDataGenerator{
            .allocator = allocator,
            .rng = prng.random(),
        };
    }

    // Generate workflow metrics test data.
    pub fn generate_workflow_metrics(
        self: *TestDataGenerator,
        count: u32,
    ) ![]const u8 {
        std.debug.assert(count > 0);
        std.debug.assert(count <= MAX_TEST_RECORDS);

        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        try buffer.appendSlice("{\"workflow\":{\"total_executions\":");
        try self.append_u32(&buffer, count);
        try buffer.appendSlice(",\"executions\":[");

        for (0..count) |i| {
            if (i > 0) {
                try buffer.appendSlice(",");
            }
            try buffer.appendSlice("{\"workflow_id\":");
            try self.append_u32(&buffer, @as(u32, @intCast(i + 1)));
            try buffer.appendSlice(",\"execution_time_ms\":");
            const exec_time = self.rng.intRangeAtMost(u32, 100, 5000);
            try self.append_u32(&buffer, exec_time);
            try buffer.appendSlice(",\"status\":\"success\"}");
        }

        try buffer.appendSlice("]}}");
        return try buffer.toOwnedSlice();
    }

    // Generate agent coordination test data.
    pub fn generate_coordination_data(
        self: *TestDataGenerator,
        source_agent: u32,
        target_agent: u32,
    ) ![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        try buffer.appendSlice("{\"source_agent_id\":");
        try self.append_u32(&buffer, source_agent);
        try buffer.appendSlice(",\"target_agent_id\":");
        try self.append_u32(&buffer, target_agent);
        try buffer.appendSlice(",\"latency_ms\":");
        const latency = self.rng.intRangeAtMost(u32, 10, 200);
        try self.append_u32(&buffer, latency);
        try buffer.appendSlice("}");

        return try buffer.toOwnedSlice();
    }

    // Append u32 to buffer.
    fn append_u32(self: *TestDataGenerator, buffer: *std.ArrayList(u8), value: u32) !void {
        const formatted = try std.fmt.allocPrint(self.allocator, "{}", .{value});
        defer self.allocator.free(formatted);
        try buffer.appendSlice(formatted);
    }
};
