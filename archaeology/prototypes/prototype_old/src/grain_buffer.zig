const std = @import("std");

/// GrainBuffer delivers Emacs-style read-only spans for the Ray terminal.
// ~(* )~ Glow Airbend: freeze the status line, let commands breathe.
// ~~~~~~ Glow Waterbend: current flows around anchored stones.
pub const GrainBuffer = struct {
    pub const max_segments = 64;

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
        if (start >= end or end > self.text.items.len) return error.InvalidRange;
        if (self.readonly_segments.items.len >= max_segments) return error.TooManySegments;
        const segment = Segment{ .start = start, .end = end };
        try self.readonly_segments.append(self.allocator, segment);
    }

    pub fn append(self: *GrainBuffer, data: []const u8) !void {
        try self.text.appendSlice(self.allocator, data);
    }

    pub fn insert(self: *GrainBuffer, index: usize, data: []const u8) !void {
        if (index > self.text.items.len) return error.OutOfBounds;
        if (self.intersectsReadonly(index, index)) return error.ReadOnlyViolation;
        try self.text.insertSlice(self.allocator, index, data);
        try self.shiftSegments(index, @as(isize, @intCast(data.len)));
    }

    pub fn overwrite(self: *GrainBuffer, index: usize, data: []const u8) !void {
        const end = index + data.len;
        if (end > self.text.items.len) return error.OutOfBounds;
        if (self.intersectsReadonly(index, end)) return error.ReadOnlyViolation;
        std.mem.copyForwards(u8, self.text.items[index..end], data);
    }

    pub fn overwriteSystem(self: *GrainBuffer, index: usize, data: []const u8) !void {
        const end = index + data.len;
        if (end > self.text.items.len) return error.OutOfBounds;
        std.mem.copyForwards(u8, self.text.items[index..end], data);
    }

    pub fn erase(self: *GrainBuffer, index: usize, count: usize) !void {
        if (count == 0) return;
        const end = index + count;
        if (end > self.text.items.len) return error.OutOfBounds;
        if (self.intersectsReadonly(index, end)) return error.ReadOnlyViolation;
        try self.text.replaceRange(self.allocator, index, count, &.{});
        try self.shiftSegments(index, -@as(isize, @intCast(count)));
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
