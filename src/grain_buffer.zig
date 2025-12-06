const std = @import("std");

/// GrainBuffer delivers Emacs-style read-only spans for the Ray terminal.
// ~(* )~ Glow Airbend: freeze the status line, let commands breathe.
// ~~~~~~ Glow Waterbend: current flows around anchored stones.
pub const GrainBuffer = struct {
    // Bounded: Max 1000 readonly segments (increased from 64 for Dream Editor/Browser)
    pub const max_segments: u32 = 1000;

    const Segment = struct {
        start: u32,
        end: u32,
    };

    allocator: std.mem.Allocator,
    text: std.ArrayListUnmanaged(u8),
    readonly_segments: std.ArrayListUnmanaged(Segment),

    pub fn init(allocator: std.mem.Allocator) GrainBuffer {
        return .{
            .allocator = allocator,
            .text = .{},
            .readonly_segments = .{},
        };
    }

    pub fn deinit(self: *GrainBuffer) void {
        self.text.deinit(self.allocator);
        self.readonly_segments.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn fromSlice(
        allocator: std.mem.Allocator,
        slice: []const u8,
    ) !GrainBuffer {
        var buffer = GrainBuffer.init(allocator);
        try buffer.text.appendSlice(allocator, slice);
        return buffer;
    }

    pub fn textSlice(self: *const GrainBuffer) []const u8 {
        return self.text.items;
    }

    pub fn markReadOnly(self: *GrainBuffer, start: u32, end: u32) !void {
        // Assert: Range must be valid
        std.debug.assert(start < end);
        const text_len = @as(u32, @intCast(self.text.items.len));
        std.debug.assert(end <= text_len);
        
        if (start >= end or end > text_len) return error.InvalidRange;
        if (self.readonly_segments.items.len >= max_segments) return error.TooManySegments;
        
        const segment = Segment{ .start = start, .end = end };
        try self.readonly_segments.append(self.allocator, segment);
        
        // Assert: Segment must be added
        std.debug.assert(self.readonly_segments.items.len > 0);
    }
    
    /// Check if a position is within a readonly span.
    pub fn isReadOnly(self: *const GrainBuffer, pos: u32) bool {
        // Assert: Position must be within buffer bounds
        const text_len = @as(u32, @intCast(self.text.items.len));
        std.debug.assert(pos <= text_len);
        
        for (self.readonly_segments.items) |segment| {
            if (pos >= segment.start and pos < segment.end) {
                return true;
            }
        }
        return false;
    }
    
    /// Get all readonly segments (for rendering/visual distinction).
    pub fn getReadonlySpans(self: *const GrainBuffer) []const Segment {
        return self.readonly_segments.items;
    }
    
    /// Check if a range intersects any readonly span (optimized with binary search).
    pub fn intersectsReadonlyRange(self: *const GrainBuffer, start: u32, end: u32) bool {
        // Assert: Range must be valid
        std.debug.assert(start <= end);
        const text_len = @as(u32, @intCast(self.text.items.len));
        std.debug.assert(end <= text_len);
        
        // Binary search optimization for large segment lists
        if (self.readonly_segments.items.len == 0) return false;
        
        // For small lists, linear search is faster
        if (self.readonly_segments.items.len < 16) {
            return self.intersectsReadonly(start, end);
        }
        
        // Binary search: find first segment that might overlap
        var left: u32 = 0;
        const segments_len = @as(u32, @intCast(self.readonly_segments.items.len));
        var right: u32 = segments_len;
        
        while (left < right) {
            const mid = left + (right - left) / 2;
            const mid_usize = @as(usize, @intCast(mid));
            const segment = self.readonly_segments.items[mid_usize];
            
            if (end <= segment.start) {
                right = mid;
            } else if (start >= segment.end) {
                left = mid + 1;
            } else {
                // Overlap found
                return true;
            }
        }
        
        return false;
    }

    pub fn append(self: *GrainBuffer, data: []const u8) !void {
        try self.text.appendSlice(self.allocator, data);
    }

    pub fn insert(self: *GrainBuffer, index: u32, data: []const u8) !void {
        // Assert: Index must be within bounds
        const text_len = self.text.items.len;
        const index_usize = @as(usize, @intCast(index));
        std.debug.assert(index_usize <= text_len);
        
        if (index_usize > text_len) return error.OutOfBounds;
        if (self.intersectsReadonly(index, index)) return error.ReadOnlyViolation;
        
        try self.text.insertSlice(self.allocator, index_usize, data);
        const data_len = @as(u32, @intCast(data.len));
        try self.shiftSegments(index, @as(i64, @intCast(data_len)));
        
        // Assert: Text must be inserted
        std.debug.assert(self.text.items.len >= index_usize + data.len);
    }

    pub fn overwrite(self: *GrainBuffer, index: u32, data: []const u8) !void {
        const data_len = @as(u32, @intCast(data.len));
        const end = index + data_len;
        
        // Assert: Range must be within bounds
        const text_len = @as(u32, @intCast(self.text.items.len));
        std.debug.assert(end <= text_len);
        
        if (end > text_len) return error.OutOfBounds;
        if (self.intersectsReadonly(index, end)) return error.ReadOnlyViolation;
        
        const index_usize = @as(usize, @intCast(index));
        const end_usize = @as(usize, @intCast(end));
        std.mem.copyForwards(u8, self.text.items[index_usize..end_usize], data);
        
        // Assert: Data must be written
        std.debug.assert(std.mem.eql(u8, self.text.items[index_usize..end_usize], data));
    }

    pub fn overwriteSystem(self: *GrainBuffer, index: u32, data: []const u8) !void {
        const data_len = @as(u32, @intCast(data.len));
        const end = index + data_len;
        const text_len = @as(u32, @intCast(self.text.items.len));
        if (end > text_len) return error.OutOfBounds;
        const index_usize = @as(usize, @intCast(index));
        const end_usize = @as(usize, @intCast(end));
        std.mem.copyForwards(u8, self.text.items[index_usize..end_usize], data);
    }

    pub fn erase(self: *GrainBuffer, index: u32, count: u32) !void {
        if (count == 0) return;
        
        const end = index + count;
        
        // Assert: Range must be within bounds
        const text_len = @as(u32, @intCast(self.text.items.len));
        std.debug.assert(end <= text_len);
        
        if (end > text_len) return error.OutOfBounds;
        if (self.intersectsReadonly(index, end)) return error.ReadOnlyViolation;
        
        const old_len = self.text.items.len;
        const index_usize = @as(usize, @intCast(index));
        const count_usize = @as(usize, @intCast(count));
        try self.text.replaceRange(self.allocator, index_usize, count_usize, &.{});
        try self.shiftSegments(index, -@as(i64, @intCast(count)));
        
        // Assert: Text must be erased
        std.debug.assert(self.text.items.len == old_len - count_usize);
    }

    fn intersectsReadonly(self: *const GrainBuffer, start: u32, end: u32) bool {
        for (self.readonly_segments.items) |segment| {
            if (!(end <= segment.start or start >= segment.end)) {
                return true;
            }
        }
        return false;
    }

    fn shiftSegments(self: *GrainBuffer, pivot: u32, delta: i64) !void {
        if (delta == 0) return;
        for (self.readonly_segments.items) |*segment| {
            if (segment.start >= pivot) {
                segment.start = shiftIndex(segment.start, delta);
                segment.end = shiftIndex(segment.end, delta);
            }
        }
    }

    fn shiftIndex(value: u32, delta: i64) u32 {
        if (delta >= 0) {
            const delta_u32 = @as(u32, @intCast(delta));
            return value + delta_u32;
        }
        const amount = @as(u32, @intCast(-delta));
        std.debug.assert(value >= amount);
        return value - amount;
    }
};

test "readonly prevents overwrite" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "cmd\nstatus\n");
    defer buffer.deinit();

    try buffer.markReadOnly(4, 10);
    const result = buffer.overwrite(6, "READY");
    try std.testing.expectError(error.ReadOnlyViolation, result);
}

test "isReadOnly checks position" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "hello world");
    defer buffer.deinit();
    
    try buffer.markReadOnly(6, 11);
    
    // Assert: Positions within readonly span return true
    try std.testing.expect(buffer.isReadOnly(6));
    try std.testing.expect(buffer.isReadOnly(10));
    
    // Assert: Positions outside readonly span return false
    try std.testing.expect(!buffer.isReadOnly(0));
    try std.testing.expect(!buffer.isReadOnly(5));
    try std.testing.expect(!buffer.isReadOnly(11));
}

test "getReadonlySpans returns all segments" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "hello world test");
    defer buffer.deinit();
    
    try buffer.markReadOnly(0, 5);
    try buffer.markReadOnly(6, 11);
    
    const spans = buffer.getReadonlySpans();
    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(spans.len)));
    try std.testing.expectEqual(@as(u32, 0), spans[0].start);
    try std.testing.expectEqual(@as(u32, 5), spans[0].end);
    try std.testing.expectEqual(@as(u32, 6), spans[1].start);
    try std.testing.expectEqual(@as(u32, 11), spans[1].end);
}

test "intersectsReadonlyRange with binary search" {
    // Create large buffer (1000 chars)
    const large_text = try std.testing.allocator.alloc(u8, 1000);
    defer std.testing.allocator.free(large_text);
    @memset(large_text, 'a');
    
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, large_text);
    defer buffer.deinit();
    
    // Create many readonly segments (triggers binary search path)
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        try buffer.markReadOnly(i * 10, i * 10 + 5);
    }
    
    // Assert: Overlapping range returns true (12-15 overlaps with segment 10-15)
    try std.testing.expect(buffer.intersectsReadonlyRange(12, 15));
    
    // Assert: Non-overlapping range returns false (1-4 is before first segment 0-5, but overlaps!)
    // Actually 1-4 overlaps with segment 0-5, so test non-overlapping ranges
    try std.testing.expect(!buffer.intersectsReadonlyRange(6, 9)); // Between segments
    try std.testing.expect(!buffer.intersectsReadonlyRange(16, 19)); // Between segments
}

test "mutable command edits succeed" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "build\nstatus\n");
    defer buffer.deinit();

    const text_len = @as(u32, @intCast(buffer.textSlice().len));
    try buffer.markReadOnly(6, text_len);
    try buffer.overwrite(0, "test");
    try buffer.erase(4, 1);
    try std.testing.expectEqualStrings("test\nstatus\n", buffer.textSlice());
}

test "insert shifts readonly segments" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "run\nstatus\n");
    defer buffer.deinit();

    const text_len = @as(u32, @intCast(buffer.textSlice().len));
    try buffer.markReadOnly(4, text_len);
    try buffer.insert(0, "zig ");
    try std.testing.expectEqualStrings("zig run\nstatus\n", buffer.textSlice());
    const result = buffer.overwrite(8, "READY");
    try std.testing.expectError(error.ReadOnlyViolation, result);
}

test "system overwrite bypasses readonly" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "cmd\nstatus\n");
    defer buffer.deinit();

    const text_len = @as(u32, @intCast(buffer.textSlice().len));
    try buffer.markReadOnly(4, text_len);
    try buffer.overwriteSystem(4, "STATUS");
    try std.testing.expectEqualStrings("cmd\nSTATUS\n", buffer.textSlice());
}
