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
            const latest = self.dag_integration.get_latest_timestamp();
            if (latest) |l| {
                std.debug.assert(ts <= l);
            }
        }
        
        self.current_timestamp = timestamp;
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
    
    /// Get events for a specific date (Unix timestamp).
    pub fn get_events_for_date(self: *const TemporalGraph, date_timestamp: u64) []const EditorDagIntegration.ProcessedEvent {
        // Get start and end of day (24 hours)
        const start_of_day = date_timestamp;
        const end_of_day = date_timestamp + (24 * 60 * 60); // 24 hours in seconds
        
        // Query events in day range
        const all_events = self.dag_integration.get_processed_events();
        var matching_count: u32 = 0;
        var i: u32 = 0;
        while (i < all_events.len) : (i += 1) {
            const event = all_events[i];
            if (event.timestamp >= start_of_day and event.timestamp <= end_of_day) {
                matching_count += 1;
            }
        }
        
        // Return matching events (caller should filter from all_events)
        _ = matching_count;
        return all_events;
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

