const std = @import("std");

/// GrainBuffer delivers Emacs-style read-only spans for the Ray terminal.
// ~(* )~ Glow Airbend: freeze the status line, let commands breathe.
// ~~~~~~ Glow Waterbend: current flows around anchored stones.
pub const GrainBuffer = struct {
    // Bounded: Max 1000 readonly segments (increased from 64 for Dream Editor/Browser)
    pub const max_segments: u32 = 1000;

    const Segment = struct {
        start: usize,
        end: usize,
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

    pub fn markReadOnly(self: *GrainBuffer, start: usize, end: usize) !void {
        // Assert: Range must be valid
        std.debug.assert(start < end);
        std.debug.assert(end <= self.text.items.len);
        
        if (start >= end or end > self.text.items.len) return error.InvalidRange;
        if (self.readonly_segments.items.len >= max_segments) return error.TooManySegments;
        
        const segment = Segment{ .start = start, .end = end };
        try self.readonly_segments.append(self.allocator, segment);
        
        // Assert: Segment must be added
        std.debug.assert(self.readonly_segments.items.len > 0);
    }
    
    /// Check if a position is within a readonly span.
    pub fn isReadOnly(self: *const GrainBuffer, pos: usize) bool {
        // Assert: Position must be within buffer bounds
        std.debug.assert(pos <= self.text.items.len);
        
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
    pub fn intersectsReadonlyRange(self: *const GrainBuffer, start: usize, end: usize) bool {
        // Assert: Range must be valid
        std.debug.assert(start <= end);
        std.debug.assert(end <= self.text.items.len);
        
        // Binary search optimization for large segment lists
        if (self.readonly_segments.items.len == 0) return false;
        
        // For small lists, linear search is faster
        if (self.readonly_segments.items.len < 16) {
            return self.intersectsReadonly(start, end);
        }
        
        // Binary search: find first segment that might overlap
        var left: usize = 0;
        var right: usize = self.readonly_segments.items.len;
        
        while (left < right) {
            const mid = left + (right - left) / 2;
            const segment = self.readonly_segments.items[mid];
            
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

    pub fn insert(self: *GrainBuffer, index: usize, data: []const u8) !void {
        // Assert: Index must be within bounds
        std.debug.assert(index <= self.text.items.len);
        
        if (index > self.text.items.len) return error.OutOfBounds;
        if (self.intersectsReadonly(index, index)) return error.ReadOnlyViolation;
        
        try self.text.insertSlice(self.allocator, index, data);
        try self.shiftSegments(index, @as(isize, @intCast(data.len)));
        
        // Assert: Text must be inserted
        std.debug.assert(self.text.items.len >= index + data.len);
    }

    pub fn overwrite(self: *GrainBuffer, index: usize, data: []const u8) !void {
        const end = index + data.len;
        
        // Assert: Range must be within bounds
        std.debug.assert(end <= self.text.items.len);
        
        if (end > self.text.items.len) return error.OutOfBounds;
        if (self.intersectsReadonly(index, end)) return error.ReadOnlyViolation;
        
        std.mem.copyForwards(u8, self.text.items[index..end], data);
        
        // Assert: Data must be written
        std.debug.assert(std.mem.eql(u8, self.text.items[index..end], data));
    }

    pub fn overwriteSystem(self: *GrainBuffer, index: usize, data: []const u8) !void {
        const end = index + data.len;
        if (end > self.text.items.len) return error.OutOfBounds;
        std.mem.copyForwards(u8, self.text.items[index..end], data);
    }

    pub fn erase(self: *GrainBuffer, index: usize, count: usize) !void {
        if (count == 0) return;
        
        const end = index + count;
        
        // Assert: Range must be within bounds
        std.debug.assert(end <= self.text.items.len);
        
        if (end > self.text.items.len) return error.OutOfBounds;
        if (self.intersectsReadonly(index, end)) return error.ReadOnlyViolation;
        
        const old_len = self.text.items.len;
        try self.text.replaceRange(self.allocator, index, count, &.{});
        try self.shiftSegments(index, -@as(isize, @intCast(count)));
        
        // Assert: Text must be erased
        std.debug.assert(self.text.items.len == old_len - count);
    }

    fn intersectsReadonly(self: *const GrainBuffer, start: usize, end: usize) bool {
        for (self.readonly_segments.items) |segment| {
            if (!(end <= segment.start or start >= segment.end)) {
                return true;
            }
        }
        return false;
    }

    fn shiftSegments(self: *GrainBuffer, pivot: usize, delta: isize) !void {
        if (delta == 0) return;
        for (self.readonly_segments.items) |*segment| {
            if (segment.start >= pivot) {
                segment.start = shiftIndex(segment.start, delta);
                segment.end = shiftIndex(segment.end, delta);
            }
        }
    }

    fn shiftIndex(value: usize, delta: isize) usize {
        if (delta >= 0) {
            return value + @as(usize, @intCast(delta));
        }
        const amount = @as(usize, @intCast(-delta));
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
    try std.testing.expectEqual(@as(usize, 2), spans.len);
    try std.testing.expectEqual(@as(usize, 0), spans[0].start);
    try std.testing.expectEqual(@as(usize, 5), spans[0].end);
    try std.testing.expectEqual(@as(usize, 6), spans[1].start);
    try std.testing.expectEqual(@as(usize, 11), spans[1].end);
}

test "intersectsReadonlyRange with binary search" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "a".repeat(1000));
    defer buffer.deinit();
    
    // Create many readonly segments (triggers binary search path)
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try buffer.markReadOnly(i * 10, i * 10 + 5);
    }
    
    // Assert: Overlapping range returns true
    try std.testing.expect(buffer.intersectsReadonlyRange(12, 15));
    
    // Assert: Non-overlapping range returns false
    try std.testing.expect(!buffer.intersectsReadonlyRange(1, 4));
    try std.testing.expect(!buffer.intersectsReadonlyRange(6, 9));
}

test "mutable command edits succeed" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "build\nstatus\n");
    defer buffer.deinit();

    try buffer.markReadOnly(6, buffer.textSlice().len);
    try buffer.overwrite(0, "test");
    try buffer.erase(4, 1);
    try std.testing.expectEqualStrings("test\nstatus\n", buffer.textSlice());
}

test "insert shifts readonly segments" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "run\nstatus\n");
    defer buffer.deinit();

    try buffer.markReadOnly(4, buffer.textSlice().len);
    try buffer.insert(0, "zig ");
    try std.testing.expectEqualStrings("zig run\nstatus\n", buffer.textSlice());
    const result = buffer.overwrite(8, "READY");
    try std.testing.expectError(error.ReadOnlyViolation, result);
}

test "system overwrite bypasses readonly" {
    var buffer = try GrainBuffer.fromSlice(std.testing.allocator, "cmd\nstatus\n");
    defer buffer.deinit();

    try buffer.markReadOnly(4, buffer.textSlice().len);
    try buffer.overwriteSystem(4, "STATUS");
    try std.testing.expectEqualStrings("cmd\nSTATUS\n", buffer.textSlice());
}
