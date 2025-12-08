//! Grain Skate Line Buffer Adapter: Wraps GrainBuffer with line-based API.
//!
//! Why: Editor uses line-based operations (lines array, replace_line, remove_line),
//!      but GrainBuffer is byte-based (flat buffer). This adapter bridges the gap.
//! Architecture: Maintains line index cache, converts between line/column and byte offsets.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, iterative algorithms.
//!
//! 2025-12-06-054343-pst: Active implementation (Phase 2: Text Buffer Unification)

const std = @import("std");
const GrainBuffer = @import("../grain_buffer.zig").GrainBuffer;

/// Line buffer adapter: Wraps GrainBuffer with line-based API.
// 2025-12-06-054343-pst: Active struct
pub const LineBufferAdapter = struct {
    // Bounded: Max buffer size (explicit limit, in bytes)
    pub const MAX_BUFFER_SIZE: u32 = 10_485_760; // 10 MB

    // Bounded: Max line length (explicit limit)
    pub const MAX_LINE_LEN: u32 = 65_536; // 64 KB

    // Bounded: Max lines (explicit limit)
    pub const MAX_LINES: u32 = MAX_BUFFER_SIZE / 64; // Max lines estimate

    /// Underlying GrainBuffer (byte-based)
    buffer: GrainBuffer,

    /// Cached lines array (computed from buffer)
    lines: []const []const u8,

    /// Number of lines
    lines_len: u32,

    /// Allocator for line cache
    allocator: std.mem.Allocator,

    /// Line index cache: byte offsets of line starts (for efficient updates)
    line_starts: []u32,

    /// Whether line cache is valid (false after buffer modifications)
    cache_valid: bool,

    /// Initialize line buffer adapter from content.
    // 2025-12-06-054343-pst: Active function
    pub fn init(allocator: std.mem.Allocator, content: []const u8) !LineBufferAdapter {
        // Assert: Content must be bounded
        std.debug.assert(content.len <= MAX_BUFFER_SIZE);

        // Initialize GrainBuffer from content
        var buffer = try GrainBuffer.fromSlice(allocator, content);

        // Build line index cache
        var line_starts = try allocator.alloc(u32, MAX_LINES);
        errdefer allocator.free(line_starts);
        var line_starts_len: u32 = 0;

        var pos: u32 = 0;
        line_starts[0] = 0;
        line_starts_len = 1;

        var i: u32 = 0;
        while (i < content.len) : (i += 1) {
            if (content[i] == '\n') {
                if (line_starts_len >= MAX_LINES) {
                    return error.TooManyLines;
                }
                line_starts[line_starts_len] = i + 1;
                line_starts_len += 1;
                pos = i + 1;
            }
        }

        // Add last line if no trailing newline
        if (pos < content.len) {
            if (line_starts_len >= MAX_LINES) {
                return error.TooManyLines;
            }
            line_starts[line_starts_len] = pos;
            line_starts_len += 1;
        } else if (content.len > 0 and content[content.len - 1] == '\n') {
            // Empty line at end
            if (line_starts_len >= MAX_LINES) {
                return error.TooManyLines;
            }
            line_starts[line_starts_len] = content.len;
            line_starts_len += 1;
        }

        // Trim line_starts to actual size
        const line_starts_trimmed = try allocator.realloc(line_starts, line_starts_len);
        line_starts = line_starts_trimmed;

        // Build lines array from line index cache
        const lines = try allocator.alloc([]const u8, line_starts_len);
        errdefer allocator.free(lines);

        const text_slice = buffer.textSlice();
        var line_idx: u32 = 0;
        while (line_idx < line_starts_len) : (line_idx += 1) {
            const line_start = line_starts[line_idx];
            const line_end = if (line_idx + 1 < line_starts_len)
                line_starts[line_idx + 1] - 1 // Exclude newline
            else
                @as(u32, @intCast(text_slice.len));

            if (line_end > line_start) {
                const line_len = line_end - line_start;
                if (line_len > MAX_LINE_LEN) {
                    return error.LineTooLong;
                }
                lines[line_idx] = text_slice[line_start..line_end];
            } else {
                lines[line_idx] = text_slice[line_start..line_start]; // Empty line
            }
        }

        return LineBufferAdapter{
            .buffer = buffer,
            .lines = lines,
            .lines_len = line_starts_len,
            .allocator = allocator,
            .line_starts = line_starts,
            .cache_valid = true,
        };
    }

    /// Deinitialize line buffer adapter and free memory.
    // 2025-12-06-054343-pst: Active function
    pub fn deinit(self: *LineBufferAdapter) void {
        // Assert: Allocator must be valid
        _ = self.allocator;

        // Free GrainBuffer
        self.buffer.deinit();

        // Free lines array
        if (self.lines.len > 0) {
            self.allocator.free(self.lines);
        }

        // Free line index cache
        if (self.line_starts.len > 0) {
            self.allocator.free(self.line_starts);
        }

        self.* = undefined;
    }

    /// Get content as single string.
    // 2025-12-06-054343-pst: Active function
    pub fn get_content(self: *const LineBufferAdapter) ![]const u8 {
        // Use GrainBuffer's text slice directly
        const text_slice = self.buffer.textSlice();
        const content = try self.allocator.alloc(u8, text_slice.len);
        errdefer self.allocator.free(content);
        @memcpy(content, text_slice);
        return content;
    }

    /// Replace a line in the buffer.
    // 2025-12-06-054343-pst: Active function
    pub fn replace_line(self: *LineBufferAdapter, line_index: u32, new_line: []const u8) !void {
        std.debug.assert(line_index < self.lines_len);
        std.debug.assert(new_line.len <= MAX_LINE_LEN);

        // Invalidate cache
        self.cache_valid = false;

        // Get line byte range (line content only, excluding newline)
        const line_start = self.line_starts[line_index];
        const text_slice = self.buffer.textSlice();
        const line_end = if (line_index + 1 < self.lines_len)
            self.line_starts[line_index + 1] - 1 // Exclude newline
        else
            @as(u32, @intCast(text_slice.len));

        const old_line_len = line_end - line_start;

        // Replace line content in GrainBuffer (preserve newline structure)
        if (old_line_len == new_line.len) {
            // Same length: overwrite
            try self.buffer.overwrite(line_start, new_line);
        } else {
            // Different length: erase old content, insert new content
            // Note: We don't touch the newline character (it's between lines)
            try self.buffer.erase(line_start, old_line_len);
            try self.buffer.insert(line_start, new_line);
        }

        // Update line index cache (shift subsequent lines)
        const delta: i64 = @as(i64, @intCast(new_line.len)) - @as(i64, @intCast(old_line_len));
        var i: u32 = line_index + 1;
        while (i < self.lines_len) : (i += 1) {
            if (delta >= 0) {
                self.line_starts[i] = @as(u32, @intCast(@as(i64, @intCast(self.line_starts[i])) + delta));
            } else {
                const delta_u32 = @as(u32, @intCast(-delta));
                std.debug.assert(self.line_starts[i] >= delta_u32);
                self.line_starts[i] -= delta_u32;
            }
        }

        // Rebuild lines array
        try self.rebuild_lines_cache();
    }

    /// Remove a line from the buffer.
    // 2025-12-06-054343-pst: Active function
    pub fn remove_line(self: *LineBufferAdapter, line_index: u32) !void {
        std.debug.assert(line_index < self.lines_len);

        // Invalidate cache
        self.cache_valid = false;

        // Get line byte range (including newline if not last line)
        const line_start = self.line_starts[line_index];
        const line_end = if (line_index + 1 < self.lines_len)
            self.line_starts[line_index + 1] // Include newline
        else
            @as(u32, @intCast(self.buffer.textSlice().len));

        const line_len = line_end - line_start;

        // Remove line from GrainBuffer
        try self.buffer.erase(line_start, line_len);

        // Update line index cache (remove entry, shift subsequent lines)
        var i: u32 = line_index;
        while (i + 1 < self.lines_len) : (i += 1) {
            self.line_starts[i] = self.line_starts[i + 1] - line_len;
        }
        self.lines_len -= 1;

        // Trim line_starts array
        const line_starts_trimmed = try self.allocator.realloc(self.line_starts, self.lines_len);
        self.line_starts = line_starts_trimmed;

        // Rebuild lines array
        try self.rebuild_lines_cache();
    }

    /// Rebuild lines cache from GrainBuffer and line index cache.
    // 2025-12-06-054343-pst: Active function
    fn rebuild_lines_cache(self: *LineBufferAdapter) !void {
        // Free old lines array
        if (self.lines.len > 0) {
            self.allocator.free(self.lines);
        }

        // Build new lines array
        const lines = try self.allocator.alloc([]const u8, self.lines_len);
        errdefer self.allocator.free(lines);

        const text_slice = self.buffer.textSlice();
        var line_idx: u32 = 0;
        while (line_idx < self.lines_len) : (line_idx += 1) {
            const line_start = self.line_starts[line_idx];
            const line_end = if (line_idx + 1 < self.lines_len)
                self.line_starts[line_idx + 1] - 1 // Exclude newline
            else
                @as(u32, @intCast(text_slice.len));

            if (line_end > line_start) {
                lines[line_idx] = text_slice[line_start..line_end];
            } else {
                lines[line_idx] = text_slice[line_start..line_start]; // Empty line
            }
        }

        self.lines = lines;
        self.cache_valid = true;
    }
};

