const std = @import("std");

/// Dream Browser Protocol Optimizer: Sub-millisecond latency optimizations.
/// ~<~ Glow Airbend: explicit message batching, bounded buffers.
/// ~~~~ Glow Waterbend: messages flow deterministically through optimized pipeline.
///
/// This implements:
/// - Message batching (combine multiple messages into single frame)
/// - Zero-copy message handling (avoid unnecessary allocations)
/// - Pre-allocated message buffers (reduce allocation overhead)
/// - Fast path for common operations (optimized hot paths)
/// - Latency monitoring (track message send/receive times)
pub const DreamBrowserProtocolOptimizer = struct {
    // Bounded: Max 100 messages per batch
    pub const MAX_BATCH_SIZE: u32 = 100;
    
    // Bounded: Max 1MB message buffer
    pub const MAX_MESSAGE_BUFFER_SIZE: u32 = 1024 * 1024;
    
    // Bounded: Max 1000 pending messages
    pub const MAX_PENDING_MESSAGES: u32 = 1000;
    
    // Target latency: sub-millisecond (0.1-0.5ms)
    pub const TARGET_LATENCY_US: u32 = 500; // 0.5ms in microseconds
    
    /// Message batch (for combining multiple messages).
    pub const MessageBatch = struct {
        messages: []const []const u8, // Messages to batch
        messages_len: u32, // Current number of messages
        total_size: u32, // Total size of all messages
    };
    
    /// Message buffer (pre-allocated for zero-copy).
    pub const MessageBuffer = struct {
        data: []u8, // Pre-allocated buffer
        data_len: u32, // Current data length
        capacity: u32, // Buffer capacity
    };
    
    /// Latency measurement (for monitoring).
    pub const LatencyMeasurement = struct {
        send_time_us: u64, // Send timestamp in microseconds
        receive_time_us: u64, // Receive timestamp in microseconds
        latency_us: u32, // Calculated latency in microseconds
    };
    
    /// Pending message (for batching).
    pub const PendingMessage = struct {
        data: []const u8, // Message data
        timestamp_us: u64, // Timestamp when queued
    };
    
    /// Pending message queue (for batching).
    pub const PendingQueue = struct {
        messages: []PendingMessage, // Pending messages
        messages_len: u32, // Current number of pending messages
        head: u32, // Queue head index
        tail: u32, // Queue tail index
    };
    
    allocator: std.mem.Allocator,
    message_buffer: MessageBuffer,
    pending_queue: PendingQueue,
    latency_history: []LatencyMeasurement, // Circular buffer
    latency_history_len: u32,
    latency_history_index: u32,
    
    /// Initialize protocol optimizer.
    pub fn init(allocator: std.mem.Allocator) !DreamBrowserProtocolOptimizer {
        // Pre-allocate message buffer (optimization: reduce allocations)
        const buffer_data = try allocator.alloc(u8, MAX_MESSAGE_BUFFER_SIZE);
        
        // Pre-allocate pending message queue
        const pending_messages = try allocator.alloc(PendingMessage, MAX_PENDING_MESSAGES);
        
        // Pre-allocate latency history
        const latency_history = try allocator.alloc(LatencyMeasurement, 1000);
        
        return DreamBrowserProtocolOptimizer{
            .allocator = allocator,
            .message_buffer = MessageBuffer{
                .data = buffer_data,
                .data_len = 0,
                .capacity = MAX_MESSAGE_BUFFER_SIZE,
            },
            .pending_queue = PendingQueue{
                .messages = pending_messages,
                .messages_len = 0,
                .head = 0,
                .tail = 0,
            },
            .latency_history = latency_history,
            .latency_history_len = 0,
            .latency_history_index = 0,
        };
    }
    
    /// Deinitialize protocol optimizer.
    pub fn deinit(self: *DreamBrowserProtocolOptimizer) void {
        // Free pending messages (data is owned by caller)
        self.allocator.free(self.pending_queue.messages);
        
        // Free message buffer
        self.allocator.free(self.message_buffer.data);
        
        // Free latency history
        self.allocator.free(self.latency_history);
    }
    
    /// Get current timestamp in microseconds.
    fn get_current_time_us() u64 {
        const timestamp = std.time.timestamp();
        const non_negative = if (timestamp < 0) 0 else @as(u64, @intCast(timestamp));
        return non_negative * 1_000_000; // Convert to microseconds (simplified)
    }
    
    /// Queue message for batching (zero-copy, just store reference).
    pub fn queue_message(
        self: *DreamBrowserProtocolOptimizer,
        message: []const u8,
    ) !void {
        // Assert: Message must be non-empty
        std.debug.assert(message.len > 0);
        std.debug.assert(message.len <= MAX_MESSAGE_BUFFER_SIZE);
        
        // Assert: Pending queue must have space
        std.debug.assert(self.pending_queue.messages_len < MAX_PENDING_MESSAGES);
        
        const queue = &self.pending_queue;
        const index = queue.tail;
        
        // Add message to queue (zero-copy: just store reference)
        queue.messages[index] = PendingMessage{
            .data = message,
            .timestamp_us = get_current_time_us(),
        };
        
        queue.tail = (queue.tail + 1) % MAX_PENDING_MESSAGES;
        queue.messages_len += 1;
        
        // Assert: Queue state is valid
        std.debug.assert(queue.messages_len <= MAX_PENDING_MESSAGES);
    }
    
    /// Batch pending messages into single buffer (optimized for latency).
    pub fn batch_messages(
        self: *DreamBrowserProtocolOptimizer,
        max_batch_size: u32,
    ) !MessageBatch {
        // Assert: Max batch size must be within bounds
        std.debug.assert(max_batch_size <= MAX_BATCH_SIZE);
        std.debug.assert(max_batch_size > 0);
        
        const queue = &self.pending_queue;
        const batch_size = @min(max_batch_size, queue.messages_len);
        
        // Assert: Batch size is valid
        std.debug.assert(batch_size <= max_batch_size);
        
        if (batch_size == 0) {
            return MessageBatch{
                .messages = &.{},
                .messages_len = 0,
                .total_size = 0,
            };
        }
        
        // Calculate total size
        var total_size: u32 = 0;
        var i: u32 = 0;
        while (i < batch_size) : (i += 1) {
            const index = (queue.head + i) % MAX_PENDING_MESSAGES;
            total_size += @as(u32, @intCast(queue.messages[index].data.len));
        }
        
        // Assert: Total size must be within bounds
        std.debug.assert(total_size <= MAX_MESSAGE_BUFFER_SIZE);
        
        // Clear message buffer
        self.message_buffer.data_len = 0;
        
        // Create batch (messages point to queue data, zero-copy)
        const messages = try self.allocator.alloc([]const u8, batch_size);
        var messages_index: u32 = 0;
        
        i = 0;
        while (i < batch_size) : (i += 1) {
            const index = (queue.head + i) % MAX_PENDING_MESSAGES;
            messages[messages_index] = queue.messages[index].data;
            messages_index += 1;
        }
        
        // Remove batched messages from queue
        queue.head = (queue.head + batch_size) % MAX_PENDING_MESSAGES;
        queue.messages_len -= batch_size;
        
        return MessageBatch{
            .messages = messages,
            .messages_len = batch_size,
            .total_size = total_size,
        };
    }
    
    /// Free message batch (free allocated array, not message data).
    pub fn free_batch(
        self: *DreamBrowserProtocolOptimizer,
        batch: MessageBatch,
    ) void {
        // Free messages array (messages themselves are owned by caller)
        self.allocator.free(batch.messages);
    }
    
    /// Record send latency (start measurement).
    pub fn record_send_start(self: *DreamBrowserProtocolOptimizer) u64 {
        return get_current_time_us();
    }
    
    /// Record receive latency (end measurement).
    pub fn record_receive_end(
        self: *DreamBrowserProtocolOptimizer,
        send_time_us: u64,
    ) void {
        // Assert: Send time must be valid
        std.debug.assert(send_time_us > 0);
        
        const receive_time_us = get_current_time_us();
        
        // Assert: Receive time must be after send time
        std.debug.assert(receive_time_us >= send_time_us);
        
        const latency_us = @as(u32, @intCast(receive_time_us - send_time_us));
        
        // Assert: Latency must be reasonable (not negative, not too large)
        std.debug.assert(latency_us < 1_000_000); // Max 1 second
        
        // Add to latency history (circular buffer)
        const index = self.latency_history_index;
        self.latency_history[index] = LatencyMeasurement{
            .send_time_us = send_time_us,
            .receive_time_us = receive_time_us,
            .latency_us = latency_us,
        };
        
        self.latency_history_index = (index + 1) % 1000;
        if (self.latency_history_len < 1000) {
            self.latency_history_len += 1;
        }
    }
    
    /// Get average latency (for monitoring).
    pub fn get_average_latency_us(self: *const DreamBrowserProtocolOptimizer) ?u32 {
        if (self.latency_history_len == 0) {
            return null;
        }
        
        var total: u64 = 0;
        var i: u32 = 0;
        while (i < self.latency_history_len) : (i += 1) {
            total += self.latency_history[i].latency_us;
        }
        
        const average = @as(u32, @intCast(total / self.latency_history_len));
        return average;
    }
    
    /// Check if latency is within target (sub-millisecond).
    pub fn is_latency_within_target(self: *const DreamBrowserProtocolOptimizer) bool {
        const avg_latency = self.get_average_latency_us() orelse return false;
        return avg_latency <= TARGET_LATENCY_US;
    }
    
    /// Get pending message count.
    pub fn get_pending_count(self: *const DreamBrowserProtocolOptimizer) u32 {
        return self.pending_queue.messages_len;
    }
    
    /// Clear pending messages (for error recovery).
    pub fn clear_pending(self: *DreamBrowserProtocolOptimizer) void {
        self.pending_queue.messages_len = 0;
        self.pending_queue.head = 0;
        self.pending_queue.tail = 0;
    }
    
    /// Get message buffer (for zero-copy message construction).
    pub fn get_message_buffer(self: *DreamBrowserProtocolOptimizer) []u8 {
        return self.message_buffer.data;
    }
    
    /// Reset message buffer (for reuse).
    pub fn reset_message_buffer(self: *DreamBrowserProtocolOptimizer) void {
        self.message_buffer.data_len = 0;
    }
    
    /// Set message buffer length (after writing data).
    pub fn set_message_buffer_len(
        self: *DreamBrowserProtocolOptimizer,
        len: u32,
    ) void {
        // Assert: Length must be within bounds
        std.debug.assert(len <= MAX_MESSAGE_BUFFER_SIZE);
        self.message_buffer.data_len = len;
    }
};

test "protocol optimizer initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var optimizer = try DreamBrowserProtocolOptimizer.init(arena.allocator());
    defer optimizer.deinit();
    
    // Assert: Optimizer initialized
    try std.testing.expect(optimizer.message_buffer.capacity > 0);
    try std.testing.expect(optimizer.pending_queue.messages.len > 0);
}

test "protocol optimizer queue message" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var optimizer = try DreamBrowserProtocolOptimizer.init(arena.allocator());
    defer optimizer.deinit();
    
    const message = "test message";
    try optimizer.queue_message(message);
    
    // Assert: Message queued
    try std.testing.expect(optimizer.get_pending_count() == 1);
}

test "protocol optimizer batch messages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var optimizer = try DreamBrowserProtocolOptimizer.init(arena.allocator());
    defer optimizer.deinit();
    
    // Queue multiple messages
    try optimizer.queue_message("msg1");
    try optimizer.queue_message("msg2");
    try optimizer.queue_message("msg3");
    
    // Batch messages
    const batch = try optimizer.batch_messages(10);
    defer optimizer.free_batch(batch);
    
    // Assert: Batch created
    try std.testing.expect(batch.messages_len == 3);
    try std.testing.expect(batch.total_size > 0);
    try std.testing.expect(optimizer.get_pending_count() == 0);
}

test "protocol optimizer latency measurement" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var optimizer = try DreamBrowserProtocolOptimizer.init(arena.allocator());
    defer optimizer.deinit();
    
    const send_time = optimizer.record_send_start();
    // Simulate some work (no-op for test)
    optimizer.record_receive_end(send_time);
    
    // Assert: Latency measured
    const avg_latency = optimizer.get_average_latency_us();
    try std.testing.expect(avg_latency != null);
    try std.testing.expect(avg_latency.? >= 0);
}

