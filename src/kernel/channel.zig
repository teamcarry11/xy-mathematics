//! Grain Basin IPC Channel
//! Why: Inter-process communication via message queues.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Maximum message size (bytes).
/// Why: Bounded message size for safety and static allocation.
/// Note: Must match kernel validation (64KB max per message).
pub const MAX_MESSAGE_SIZE: u32 = 4096;

/// Maximum messages per channel.
/// Why: Bounded queue size for safety and static allocation.
pub const MAX_MESSAGES: u32 = 32;

/// Channel message.
/// Why: Store message data in channel queue.
/// Grain Style: Static allocation, bounded size.
pub const Message = struct {
    /// Message data (bounded size).
    data: [MAX_MESSAGE_SIZE]u8,
    /// Message length (bytes, <= MAX_MESSAGE_SIZE).
    length: u32,
    /// Whether message is valid (in queue).
    valid: bool,
    
    /// Initialize empty message.
    /// Why: Explicit initialization, clear state.
    pub fn init() Message {
        return Message{
            .data = [_]u8{0} ** MAX_MESSAGE_SIZE,
            .length = 0,
            .valid = false,
        };
    }
};

/// IPC channel for inter-process communication.
/// Why: Enable processes to send/receive messages.
/// Grain Style: Static allocation, bounded queue.
pub const Channel = struct {
    /// Channel ID (non-zero if allocated).
    id: u64,
    /// Message queue (bounded size).
    messages: [MAX_MESSAGES]Message,
    /// Number of messages in queue.
    message_count: u32,
    /// Read position (index of next message to read).
    read_pos: u32,
    /// Write position (index of next message to write).
    write_pos: u32,
    /// Whether channel is allocated.
    allocated: bool,
    
    /// Initialize empty channel.
    /// Why: Explicit initialization, clear state.
    pub fn init() Channel {
        return Channel{
            .id = 0,
            .messages = [_]Message{Message.init()} ** MAX_MESSAGES,
            .message_count = 0,
            .read_pos = 0,
            .write_pos = 0,
            .allocated = false,
        };
    }
    
    /// Send message to channel.
    /// Why: Add message to channel queue.
    /// Contract: data must be <= MAX_MESSAGE_SIZE, channel must be allocated.
    /// Returns: true if sent, false if queue full.
    pub fn send(self: *Channel, data: []const u8) bool {
        // Assert: Channel must be allocated.
        Debug.kassert(self.allocated, "Channel not allocated", .{});
        
        // Assert: Data length must be <= MAX_MESSAGE_SIZE.
        Debug.kassert(data.len <= MAX_MESSAGE_SIZE, "Data too large", .{});
        
        // Assert: Data length must be > 0.
        Debug.kassert(data.len > 0, "Data empty", .{});
        
        // Check if queue is full.
        if (self.message_count >= MAX_MESSAGES) {
            return false; // Queue full
        }
        
        // Assert: Write position must be within bounds.
        Debug.kassert(self.write_pos < MAX_MESSAGES, "Write pos >= MAX", .{});
        
        // Get message slot at write position.
        var msg = &self.messages[self.write_pos];
        
        // Copy data to message.
        @memcpy(msg.data[0..data.len], data);
        msg.length = @as(u32, @intCast(data.len));
        msg.valid = true;
        
        // Update write position (wrap around).
        self.write_pos = (self.write_pos + 1) % MAX_MESSAGES;
        self.message_count += 1;
        
        // Assert: Message count must be <= MAX_MESSAGES.
        Debug.kassert(self.message_count <= MAX_MESSAGES, "Message count > MAX", .{});
        
        // Assert: Message must be valid.
        Debug.kassert(msg.valid, "Message not valid", .{});
        Debug.kassert(msg.length == @as(u32, @intCast(data.len)), "Message length mismatch", .{});
        
        return true;
    }
    
    /// Receive message from channel.
    /// Why: Remove message from channel queue.
    /// Contract: buffer must be >= MAX_MESSAGE_SIZE, channel must be allocated.
    /// Returns: bytes received if message available, 0 if queue empty.
    pub fn receive(self: *Channel, buffer: []u8) u32 {
        // Assert: Channel must be allocated.
        Debug.kassert(self.allocated, "Channel not allocated", .{});
        
        // Assert: Buffer must be >= MAX_MESSAGE_SIZE.
        Debug.kassert(buffer.len >= MAX_MESSAGE_SIZE, "Buffer too small", .{});
        
        // Check if queue is empty.
        if (self.message_count == 0) {
            return 0; // Queue empty
        }
        
        // Assert: Read position must be within bounds.
        Debug.kassert(self.read_pos < MAX_MESSAGES, "Read pos >= MAX", .{});
        
        // Get message at read position.
        var msg = &self.messages[self.read_pos];
        
        // Assert: Message must be valid.
        Debug.kassert(msg.valid, "Message not valid", .{});
        
        // Copy message data to buffer.
        const bytes_to_copy = @min(msg.length, @as(u32, @intCast(buffer.len)));
        @memcpy(buffer[0..bytes_to_copy], msg.data[0..bytes_to_copy]);
        
        // Clear message.
        msg.valid = false;
        msg.length = 0;
        
        // Update read position (wrap around).
        self.read_pos = (self.read_pos + 1) % MAX_MESSAGES;
        self.message_count -= 1;
        
        // Assert: Message count must be >= 0.
        Debug.kassert(self.message_count >= 0, "Message count negative", .{});
        
        // Assert: Message must be cleared.
        Debug.kassert(!msg.valid, "Message still valid", .{});
        
        return bytes_to_copy;
    }
    
    /// Check if channel has messages.
    /// Why: Query channel state without blocking.
    /// Contract: Channel must be allocated.
    pub fn has_messages(self: *const Channel) bool {
        // Assert: Channel must be allocated.
        Debug.kassert(self.allocated, "Channel not allocated", .{});
        
        return self.message_count > 0;
    }
    
    /// Get message count.
    /// Why: Query number of messages in queue.
    /// Contract: Channel must be allocated.
    pub fn get_message_count(self: *const Channel) u32 {
        // Assert: Channel must be allocated.
        Debug.kassert(self.allocated, "Channel not allocated", .{});
        
        // Assert: Message count must be <= MAX_MESSAGES.
        Debug.kassert(self.message_count <= MAX_MESSAGES, "Message count > MAX", .{});
        
        return self.message_count;
    }
};

/// Channel table for kernel.
/// Why: Manage all IPC channels in kernel.
/// Grain Style: Static allocation, max 64 channels.
pub const ChannelTable = struct {
    /// Channels array (static allocation).
    channels: [64]Channel,
    /// Number of allocated channels.
    channel_count: u32,
    /// Next channel ID (starts at 1).
    next_channel_id: u64,
    
    /// Initialize channel table.
    /// Why: Set up channel table state.
    pub fn init() ChannelTable {
        return ChannelTable{
            .channels = [_]Channel{Channel.init()} ** 64,
            .channel_count = 0,
            .next_channel_id = 1,
        };
    }
    
    /// Create new channel.
    /// Why: Allocate channel for IPC.
    /// Returns: Channel ID if created, 0 if table full.
    pub fn create(self: *ChannelTable) u64 {
        // Assert: Channel count must be < max channels.
        Debug.kassert(self.channel_count < 64, "Channel table full", .{});
        
        // Find free channel slot.
        var slot: ?u32 = null;
        for (0..64) |i| {
            if (!self.channels[i].allocated) {
                slot = @as(u32, @intCast(i));
                break;
            }
        }
        
        if (slot == null) {
            return 0; // No free slot
        }
        
        const idx = slot.?;
        
        // Allocate channel ID.
        const channel_id = self.next_channel_id;
        self.next_channel_id += 1;
        
        // Initialize channel.
        self.channels[idx].id = channel_id;
        self.channels[idx].allocated = true;
        self.channels[idx].message_count = 0;
        self.channels[idx].read_pos = 0;
        self.channels[idx].write_pos = 0;
        
        self.channel_count += 1;
        
        // Assert: Channel must be allocated.
        Debug.kassert(self.channels[idx].allocated, "Channel not allocated", .{});
        Debug.kassert(self.channels[idx].id == channel_id, "Channel ID mismatch", .{});
        Debug.kassert(channel_id != 0, "Channel ID is 0", .{});
        
        return channel_id;
    }
    
    /// Find channel by ID.
    /// Why: Look up channel for send/receive operations.
    /// Returns: Channel pointer if found, null otherwise.
    pub fn find(self: *ChannelTable, channel_id: u64) ?*Channel {
        // Assert: Channel ID must be non-zero.
        Debug.kassert(channel_id != 0, "Channel ID is 0", .{});
        
        for (0..64) |i| {
            if (self.channels[i].allocated and self.channels[i].id == channel_id) {
                // Assert: Channel must be allocated.
                Debug.kassert(self.channels[i].allocated, "Channel not allocated", .{});
                Debug.kassert(self.channels[i].id == channel_id, "Channel ID mismatch", .{});
                
                return &self.channels[i];
            }
        }
        
        return null;
    }
    
    /// Get channel count.
    /// Why: Query number of allocated channels.
    pub fn get_count(self: *const ChannelTable) u32 {
        // Assert: Channel count must be <= 64.
        Debug.kassert(self.channel_count <= 64, "Channel count > 64", .{});
        
        return self.channel_count;
    }
};

// Test channel initialization.
test "channel init" {
    const channel = Channel.init();
    
    // Assert: Channel must be unallocated initially.
    try std.testing.expect(!channel.allocated);
    try std.testing.expect(channel.id == 0);
    try std.testing.expect(channel.message_count == 0);
}

// Test channel send and receive.
test "channel send receive" {
    var channel = Channel.init();
    channel.allocated = true;
    channel.id = 1;
    
    const data = "Hello, World!";
    const sent = channel.send(data);
    
    // Assert: Message must be sent.
    try std.testing.expect(sent);
    try std.testing.expect(channel.message_count == 1);
    
    var buffer: [MAX_MESSAGE_SIZE]u8 = undefined;
    const received = channel.receive(&buffer);
    
    // Assert: Message must be received.
    try std.testing.expect(received == data.len);
    try std.testing.expect(std.mem.eql(u8, buffer[0..received], data));
    try std.testing.expect(channel.message_count == 0);
}

// Test channel table.
test "channel table create" {
    var table = ChannelTable.init();
    
    const id1 = table.create();
    
    // Assert: Channel must be created.
    try std.testing.expect(id1 != 0);
    try std.testing.expect(table.channel_count == 1);
    
    const channel = table.find(id1);
    
    // Assert: Channel must be found.
    try std.testing.expect(channel != null);
    try std.testing.expect(channel.?.id == id1);
}

