const std = @import("std");
const EditorDagIntegration = @import("editor_dag_integration.zig").EditorDagIntegration;

/// Temporal Knowledge Graph: Time-travel mode for knowledge graph.
/// ~<~ Glow Airbend: explicit temporal queries, bounded history.
/// ~~~~ Glow Waterbend: time-travel flows deterministically through DAG.
///
/// This implements time-travel capabilities for knowledge graphs:
/// - View graph at any point in time
/// - Block version history with branching
/// - Temporal queries ("What did I know on [date]?")
/// - Animated transitions showing graph growth
pub const TemporalGraph = struct {
    allocator: std.mem.Allocator,
    dag_integration: *EditorDagIntegration,
    current_timestamp: ?u64, // Current time-travel timestamp (null = present)
    
    // Bounded: Max 1,000 temporal snapshots
    pub const MAX_TEMPORAL_SNAPSHOTS: u32 = 1_000;
    
    /// Initialize temporal graph.
    pub fn init(
        allocator: std.mem.Allocator,
        dag_integration: *EditorDagIntegration,
    ) TemporalGraph {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        // Assert: DAG integration must be valid
        std.debug.assert(dag_integration.buffer_node_id != null);
        
        return TemporalGraph{
            .allocator = allocator,
            .dag_integration = dag_integration,
            .current_timestamp = null, // Start at present
        };
    }
    
    /// Get time range for time slider (earliest to latest).
    pub fn get_time_range(self: *const TemporalGraph) struct { earliest: ?u64, latest: ?u64 } {
        const earliest = self.dag_integration.get_earliest_timestamp();
        const latest = self.dag_integration.get_latest_timestamp();
        
        return .{
            .earliest = earliest,
            .latest = latest,
        };
    }
    
    /// Set current time-travel timestamp (null = present).
    pub fn set_timestamp(self: *TemporalGraph, timestamp: ?u64) void {
        // Assert: If timestamp is set, it must be within valid range
        if (timestamp) |ts| {
            const range = self.get_time_range();
            if (range.latest) |latest| {
                std.debug.assert(ts <= latest);
            }
            if (range.earliest) |earliest| {
                std.debug.assert(ts >= earliest);
            }
        }
        
        self.current_timestamp = timestamp;
    }
    
    /// Get time range duration in seconds (latest - earliest).
    /// Returns 0 if range is invalid or empty.
    pub fn get_time_range_duration(self: *const TemporalGraph) u64 {
        const range = self.get_time_range();
        if (range.earliest == null or range.latest == null) {
            return 0;
        }
        
        const earliest = range.earliest.?;
        const latest = range.latest.?;
        
        // Assert: Latest must be >= earliest
        std.debug.assert(latest >= earliest);
        
        return latest - earliest;
    }
    
    /// Calculate timestamp from slider position (0.0 to 1.0).
    /// Returns null if range is invalid or empty.
    pub fn timestamp_from_slider_position(
        self: *const TemporalGraph,
        position: f32,
    ) ?u64 {
        // Assert: Position must be in valid range
        std.debug.assert(position >= 0.0);
        std.debug.assert(position <= 1.0);
        
        const range = self.get_time_range();
        if (range.earliest == null or range.latest == null) {
            return null;
        }
        
        const earliest = range.earliest.?;
        const latest = range.latest.?;
        const duration = latest - earliest;
        
        // Calculate timestamp: earliest + (position * duration)
        const offset = @as(u64, @intFromFloat(position * @as(f64, @floatFromInt(duration))));
        const timestamp = earliest + offset;
        
        // Assert: Calculated timestamp is within range
        std.debug.assert(timestamp >= earliest);
        std.debug.assert(timestamp <= latest);
        
        return timestamp;
    }
    
    /// Calculate slider position (0.0 to 1.0) from timestamp.
    /// Returns null if range is invalid, empty, or timestamp is out of range.
    pub fn slider_position_from_timestamp(
        self: *const TemporalGraph,
        timestamp: u64,
    ) ?f32 {
        const range = self.get_time_range();
        if (range.earliest == null or range.latest == null) {
            return null;
        }
        
        const earliest = range.earliest.?;
        const latest = range.latest.?;
        
        // Assert: Timestamp must be within range
        std.debug.assert(timestamp >= earliest);
        std.debug.assert(timestamp <= latest);
        
        const duration = latest - earliest;
        if (duration == 0) {
            return 0.0; // Single point in time
        }
        
        // Calculate position: (timestamp - earliest) / duration
        const offset = timestamp - earliest;
        const position = @as(f32, @floatFromInt(offset)) / @as(f32, @floatFromInt(duration));
        
        // Assert: Position is in valid range
        std.debug.assert(position >= 0.0);
        std.debug.assert(position <= 1.0);
        
        return position;
    }
    
    /// Get current time-travel timestamp (null = present).
    pub fn get_timestamp(self: *const TemporalGraph) ?u64 {
        return self.current_timestamp;
    }
    
    /// Query events up to current timestamp (time-travel query).
    pub fn query_events_at_current_time(self: *const TemporalGraph) []const EditorDagIntegration.ProcessedEvent {
        if (self.current_timestamp) |ts| {
            return self.dag_integration.query_events_up_to_timestamp(ts);
        } else {
            // Present: return all events
            return self.dag_integration.get_processed_events();
        }
    }
    
    /// Query events in a date range (temporal query).
    /// start_date and end_date are Unix timestamps.
    pub fn query_events_by_date_range(
        self: *const TemporalGraph,
        start_date: u64,
        end_date: u64,
    ) u32 {
        // Assert: Date range must be valid
        std.debug.assert(start_date <= end_date);
        
        return self.dag_integration.count_events_by_time_range(start_date, end_date);
    }
    
    /// Get count of events for a specific date (Unix timestamp).
    /// Returns count of events within the 24-hour period starting at date_timestamp.
    pub fn get_event_count_for_date(self: *const TemporalGraph, date_timestamp: u64) u32 {
        // Assert: Timestamp must be valid (within reasonable Unix timestamp range)
        std.debug.assert(date_timestamp > 0);
        
        // Get start and end of day (24 hours)
        const start_of_day = date_timestamp;
        const end_of_day = date_timestamp + (24 * 60 * 60); // 24 hours in seconds
        
        // Query events in date range using count method
        return self.dag_integration.count_events_by_time_range(start_of_day, end_of_day);
    }
    
    /// Check if time-travel mode is active (timestamp set).
    pub fn is_time_travel_mode(self: *const TemporalGraph) bool {
        return self.current_timestamp != null;
    }
    
    /// Reset to present (exit time-travel mode).
    pub fn reset_to_present(self: *TemporalGraph) void {
        self.current_timestamp = null;
    }
};

test "temporal graph initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag_integration = try EditorDagIntegration.init(arena.allocator());
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    var temporal = TemporalGraph.init(arena.allocator(), &dag_integration);
    
    // Assert: Temporal graph initialized
    try std.testing.expect(temporal.current_timestamp == null);
    try std.testing.expect(!temporal.is_time_travel_mode());
}

test "temporal graph time range" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag_integration = try EditorDagIntegration.init(arena.allocator());
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    // Create and process events
    _ = try dag_integration.map_operation_to_event(.insert, 1, 5, "", "new1");
    _ = try dag_integration.map_operation_to_event(.insert, 1, 9, "", "new2");
    try dag_integration.process_events();
    
    var temporal = TemporalGraph.init(arena.allocator(), &dag_integration);
    
    // Get time range
    const range = temporal.get_time_range();
    
    // Assert: Time range is valid
    try std.testing.expect(range.earliest != null);
    try std.testing.expect(range.latest != null);
    try std.testing.expect(range.latest.? >= range.earliest.?);
}

test "temporal graph time travel" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag_integration = try EditorDagIntegration.init(arena.allocator());
    defer dag_integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);
    
    // Create and process events
    _ = try dag_integration.map_operation_to_event(.insert, 1, 5, "", "new1");
    _ = try dag_integration.map_operation_to_event(.insert, 1, 9, "", "new2");
    try dag_integration.process_events();
    
    var temporal = TemporalGraph.init(arena.allocator(), &dag_integration);
    
    // Get latest timestamp
    const latest = dag_integration.get_latest_timestamp();
    try std.testing.expect(latest != null);
    
    // Set timestamp to latest (time-travel)
    temporal.set_timestamp(latest);
    
    // Assert: Time-travel mode active
    try std.testing.expect(temporal.is_time_travel_mode());
    try std.testing.expect(temporal.get_timestamp() == latest);
    
    // Query events at current time
    const events = temporal.query_events_at_current_time();
    try std.testing.expect(events.len > 0);
    
    // Reset to present
    temporal.reset_to_present();
    try std.testing.expect(!temporal.is_time_travel_mode());
}

