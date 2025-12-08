const std = @import("std");
const DagCore = @import("dag_core.zig").DagCore;

/// HashDAG Consensus: Event ordering via DAG consensus (Djinn's proposal).
/// ~<~ Glow Airbend: explicit event ordering, bounded consensus.
/// ~~~~ Glow Waterbend: consensus flows deterministically through DAG.
///
/// This implements Djinn's HashDAG v0.1 proposal:
/// - Event-based: Everything is an event (code edit, web request, UI update)
/// - Parent references: Events reference parents (like git commits)
/// - Virtual voting: Consensus without explicit vote messages
/// - Fast finality: Deterministic ordering in seconds
/// - High throughput: Parallel ingestion (not sequential blocks)
pub const HashDagConsensus = struct {
    allocator: std.mem.Allocator,
    dag: *DagCore,
    
    // Bounded: Max 10,000 pending events for consensus
    pub const MAX_PENDING_CONSENSUS: u32 = 10_000;
    
    // Bounded: Max 100 rounds for virtual voting
    pub const MAX_VOTING_ROUNDS: u32 = 100;
    
    // Bounded: Max 1,000 witnesses per round
    pub const MAX_WITNESSES_PER_ROUND: u32 = 1_000;
    
    /// Event in HashDAG consensus (extends DAG event with consensus metadata).
    pub const ConsensusEvent = struct {
        event_id: u64, // DAG event ID
        creator_id: u32, // Creator/participant ID
        parents: []const u64, // Parent event IDs (HashDAG-style)
        parents_len: u32,
        timestamp: u64, // Unix timestamp
        round: u32 = 0, // Consensus round (determined by virtual voting)
        fame: ?bool = null, // Fame status (true = famous, false = not famous, null = undecided)
        witness: bool = false, // Is this event a witness in its round?
        finality: bool = false, // Has this event achieved finality?
    };
    
    /// Consensus state for event ordering.
    pub const ConsensusState = struct {
        events: []ConsensusEvent,
        events_len: u32,
        current_round: u32 = 0,
        finalized_events: u32 = 0,
    };
    
    state: ConsensusState,
    
    /// Initialize HashDAG consensus.
    pub fn init(allocator: std.mem.Allocator, dag: *DagCore) !HashDagConsensus {
        // Assert: Allocator and DAG must be valid
        std.debug.assert(allocator.ptr != null);
        _ = dag; // DAG is owned by caller
        
        // Pre-allocate consensus event buffer
        const events = try allocator.alloc(ConsensusEvent, MAX_PENDING_CONSENSUS);
        errdefer allocator.free(events);
        
        return HashDagConsensus{
            .allocator = allocator,
            .dag = dag,
            .state = ConsensusState{
                .events = events,
                .events_len = 0,
                .current_round = 0,
                .finalized_events = 0,
            },
        };
    }
    
    /// Deinitialize HashDAG consensus.
    pub fn deinit(self: *HashDagConsensus) void {
        // Free parent arrays
        for (self.state.events[0..self.state.events_len]) |*event| {
            if (event.parents.len > 0) {
                self.allocator.free(event.parents);
            }
        }
        
        self.allocator.free(self.state.events);
    }
    
    /// Add event to consensus (HashDAG-style with parent references).
    pub fn addEvent(
        self: *HashDagConsensus,
        event_id: u64,
        creator_id: u32,
        parents: []const u64,
    ) !void {
        // Assert: Event count must be within bounds
        std.debug.assert(self.state.events_len < MAX_PENDING_CONSENSUS);
        
        // Assert: Event ID must be valid (must exist in DAG)
        const dag_event = self.findDagEvent(event_id);
        std.debug.assert(dag_event != null);
        
        // Assert: Creator ID must be valid
        std.debug.assert(creator_id < 1_000_000); // Reasonable limit
        
        // Copy parent IDs
        const parent_ids = try self.allocator.dupe(u64, parents);
        errdefer self.allocator.free(parent_ids);
        
        // Create consensus event
        const consensus_event = ConsensusEvent{
            .event_id = event_id,
            .creator_id = creator_id,
            .parents = parent_ids,
            .parents_len = @as(u32, @intCast(parent_ids.len)),
            .timestamp = std.time.timestamp(),
            .round = 0, // Will be determined by virtual voting
            .fame = null, // Will be determined by virtual voting
            .witness = false, // Will be determined by virtual voting
            .finality = false, // Will be determined by finality manager
        };
        
        const event_idx = self.state.events_len;
        self.state.events[event_idx] = consensus_event;
        self.state.events_len += 1;
        
        // Assert: Event was added
        std.debug.assert(self.state.events_len == event_idx + 1);
    }
    
    /// Determine consensus round for events (virtual voting, HashDAG-style).
    pub fn determineRounds(self: *HashDagConsensus) !void {
        // Assert: Events must be valid
        std.debug.assert(self.state.events_len <= MAX_PENDING_CONSENSUS);
        
        // Simple round determination: round = max(parent rounds) + 1
        // This is a simplified version of HashDAG's virtual voting
        for (self.state.events[0..self.state.events_len]) |*event| {
            if (event.round == 0) {
                // Find max parent round
                var max_parent_round: u32 = 0;
                
                for (event.parents) |parent_id| {
                    const parent_event = self.findConsensusEvent(parent_id);
                    if (parent_event) |parent| {
                        if (parent.round > max_parent_round) {
                            max_parent_round = parent.round;
                        }
                    }
                }
                
                // Round = max parent round + 1
                event.round = max_parent_round + 1;
                
                // Update current round
                if (event.round > self.state.current_round) {
                    self.state.current_round = event.round;
                }
            }
        }
        
        // Assert: All events have rounds assigned
        for (self.state.events[0..self.state.events_len]) |event| {
            std.debug.assert(event.round > 0);
        }
    }
    
    /// Determine witness events (events that are first in their round from their creator).
    pub fn determineWitnesses(self: *HashDagConsensus) !void {
        // Assert: Rounds must be determined first
        std.debug.assert(self.state.current_round > 0);
        
        // For each creator, find first event in each round (witness)
        var creator_rounds = std.AutoHashMap(u32, u32).init(self.allocator);
        defer creator_rounds.deinit();
        
        for (self.state.events[0..self.state.events_len]) |*event| {
            const entry = try creator_rounds.getOrPut(event.creator_id);
            
            if (!entry.found_existing) {
                // First event from this creator in this round = witness
                entry.value_ptr.* = event.round;
                event.witness = true;
            } else {
                // Check if this is first event in this round from this creator
                if (event.round < entry.value_ptr.*) {
                    // Reset previous witness
                    for (self.state.events[0..self.state.events_len]) |*e| {
                        if (e.creator_id == event.creator_id and e.round == entry.value_ptr.*) {
                            e.witness = false;
                        }
                    }
                    entry.value_ptr.* = event.round;
                    event.witness = true;
                }
            }
        }
        
        // Assert: At least one witness per round
        // TODO: Verify witness distribution
    }
    
    /// Determine fame status (simplified virtual voting).
    pub fn determineFame(self: *HashDagConsensus) !void {
        // Assert: Witnesses must be determined first
        // TODO: Verify witnesses are set
        
        // Simplified fame determination: witness events are famous
        // In full HashDAG, fame is determined by virtual voting across rounds
        for (self.state.events[0..self.state.events_len]) |*event| {
            if (event.witness) {
                event.fame = true; // Witness events are famous
            } else {
                event.fame = false; // Non-witness events are not famous
            }
        }
        
        // Assert: All events have fame status
        for (self.state.events[0..self.state.events_len]) |event| {
            std.debug.assert(event.fame != null);
        }
    }
    
    /// Determine finality (fast finality, seconds not minutes).
    pub fn determineFinality(self: *HashDagConsensus) !void {
        // Assert: Fame must be determined first
        // TODO: Verify fame is set
        
        // Simplified finality: events in rounds N-2 or earlier are finalized
        // In full HashDAG, finality is determined by famous witness consensus
        const finality_round = if (self.state.current_round >= 2) self.state.current_round - 2 else 0;
        
        for (self.state.events[0..self.state.events_len]) |*event| {
            if (event.round <= finality_round and event.fame == true) {
                event.finality = true;
                self.state.finalized_events += 1;
            }
        }
        
        // Assert: Finalized events count is correct
        var finalized_count: u32 = 0;
        for (self.state.events[0..self.state.events_len]) |event| {
            if (event.finality) {
                finalized_count += 1;
            }
        }
        std.debug.assert(finalized_count == self.state.finalized_events);
    }
    
    /// Get ordered events (deterministic ordering via HashDAG consensus).
    pub fn getOrderedEvents(self: *const HashDagConsensus) []const ConsensusEvent {
        // Return events sorted by: round, then timestamp, then event ID
        // This provides deterministic ordering
        const events = self.state.events[0..self.state.events_len];
        
        // Sort events (round, timestamp, event_id)
        // For now, return unsorted (caller should sort)
        // TODO: Implement proper sorting
        return events;
    }
    
    /// Find consensus event by DAG event ID.
    fn findConsensusEvent(self: *const HashDagConsensus, event_id: u64) ?*const ConsensusEvent {
        for (self.state.events[0..self.state.events_len]) |*event| {
            if (event.event_id == event_id) {
                return event;
            }
        }
        return null;
    }
    
    /// Find DAG event by ID (helper function).
    fn findDagEvent(self: *const HashDagConsensus, event_id: u64) ?*const DagCore.Event {
        const events = self.dag.pending_events[0..self.dag.pending_events_len];
        for (events) |*event| {
            if (event.id == event_id) {
                return event;
            }
        }
        return null;
    }
    
    /// Process consensus (determine rounds, witnesses, fame, finality).
    pub fn processConsensus(self: *HashDagConsensus) !void {
        // Assert: Events must be valid
        std.debug.assert(self.state.events_len <= MAX_PENDING_CONSENSUS);
        
        // Step 1: Determine rounds
        try self.determineRounds();
        
        // Step 2: Determine witnesses
        try self.determineWitnesses();
        
        // Step 3: Determine fame
        try self.determineFame();
        
        // Step 4: Determine finality
        try self.determineFinality();
        
        // Assert: Consensus processed
        std.debug.assert(self.state.current_round > 0);
    }
    
    /// Get finality statistics.
    pub fn getFinalityStats(self: *const HashDagConsensus) FinalityStats {
        var stats = FinalityStats{
            .total_events = self.state.events_len,
            .finalized_events = self.state.finalized_events,
            .pending_events = self.state.events_len - self.state.finalized_events,
            .current_round = self.state.current_round,
            .finality_rate = 0.0,
        };
        
        if (stats.total_events > 0) {
            stats.finality_rate = @as(f64, @floatFromInt(stats.finalized_events)) / @as(f64, @floatFromInt(stats.total_events));
        }
        
        return stats;
    }
    
    /// Finality statistics.
    pub const FinalityStats = struct {
        total_events: u32,
        finalized_events: u32,
        pending_events: u32,
        current_round: u32,
        finality_rate: f64, // 0.0 to 1.0
    };
};

test "hashdag consensus initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var consensus = try HashDagConsensus.init(arena.allocator(), &dag);
    defer consensus.deinit();
    
    // Assert: Consensus initialized
    try std.testing.expect(consensus.state.events_len == 0);
    try std.testing.expect(consensus.state.current_round == 0);
}

test "hashdag consensus add event" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var consensus = try HashDagConsensus.init(arena.allocator(), &dag);
    defer consensus.deinit();
    
    // Add DAG event first
    const dag_node_id = try dag.addNode(.ast_node, "test", .{});
    const dag_event_id = try dag.addEvent(.code_edit, dag_node_id, "edit", &.{});
    
    // Add consensus event
    try consensus.addEvent(dag_event_id, 0, &.{});
    
    // Assert: Event was added
    try std.testing.expect(consensus.state.events_len == 1);
    try std.testing.expect(consensus.state.events[0].event_id == dag_event_id);
}

test "hashdag consensus determine rounds" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var consensus = try HashDagConsensus.init(arena.allocator(), &dag);
    defer consensus.deinit();
    
    // Add DAG events
    const dag_node_id = try dag.addNode(.ast_node, "test", .{});
    const dag_event1 = try dag.addEvent(.code_edit, dag_node_id, "edit1", &.{});
    const dag_event2 = try dag.addEvent(.code_edit, dag_node_id, "edit2", &.{});
    
    // Add consensus events (event2 references event1 as parent)
    try consensus.addEvent(dag_event1, 0, &.{});
    try consensus.addEvent(dag_event2, 0, &.{dag_event1});
    
    // Determine rounds
    try consensus.determineRounds();
    
    // Assert: Rounds determined
    try std.testing.expect(consensus.state.events[0].round == 1);
    try std.testing.expect(consensus.state.events[1].round == 2);
    try std.testing.expect(consensus.state.current_round == 2);
}

test "hashdag consensus process consensus" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var consensus = try HashDagConsensus.init(arena.allocator(), &dag);
    defer consensus.deinit();
    
    // Add DAG events
    const dag_node_id = try dag.addNode(.ast_node, "test", .{});
    const dag_event1 = try dag.addEvent(.code_edit, dag_node_id, "edit1", &.{});
    const dag_event2 = try dag.addEvent(.code_edit, dag_node_id, "edit2", &.{});
    
    // Add consensus events
    try consensus.addEvent(dag_event1, 0, &.{});
    try consensus.addEvent(dag_event2, 0, &.{dag_event1});
    
    // Process consensus
    try consensus.processConsensus();
    
    // Assert: Consensus processed
    try std.testing.expect(consensus.state.current_round > 0);
    try std.testing.expect(consensus.state.events[0].fame != null);
}

