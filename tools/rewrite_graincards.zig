//! Rewrite Graincards to 103×80 Format
//! Why: Update archaeology graincards to new 103×80 content-only specification.
//! Grain Style: Explicit types (u32/u64), bounded allocations, assertions.

const std = @import("std");
const MAX_WIDTH: u32 = 103;
const MAX_HEIGHT: u32 = 80;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        std.debug.print("Usage: {s} <input_file> [output_file]\n", .{args[0]});
        return;
    }
    
    const input_path = args[1];
    const output_path = if (args.len > 2) args[2] else input_path;
    
    const content = try std.fs.cwd().readFileAlloc(
        allocator,
        input_path,
        1024 * 1024,
    );
    defer allocator.free(content);
    
    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();
    
    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| {
        // Remove border lines (lines starting with + or - only).
        var is_border = true;
        for (line) |char| {
            if (char != '+' and char != '-' and char != ' ' and char != '\t') {
                is_border = false;
                break;
            }
        }
        
        if (!is_border and line.len > 0) {
            try lines.append(line);
        }
    }
    
    // Pad lines to MAX_WIDTH and limit to MAX_HEIGHT.
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();
    
    var line_count: u32 = 0;
    for (lines.items) |line| {
        if (line_count >= MAX_HEIGHT) break;
        
        // Pad line to MAX_WIDTH.
        const padded_len = @min(line.len, MAX_WIDTH);
        try output.writer().writeAll(line[0..padded_len]);
        
        // Pad with spaces if needed.
        var i: u32 = padded_len;
        while (i < MAX_WIDTH) : (i += 1) {
            try output.writer().writeByte(' ');
        }
        
        try output.writer().writeByte('\n');
        line_count += 1;
    }
    
    // Pad remaining lines to MAX_HEIGHT.
    while (line_count < MAX_HEIGHT) : (line_count += 1) {
        var i: u32 = 0;
        while (i < MAX_WIDTH) : (i += 1) {
            try output.writer().writeByte(' ');
        }
        try output.writer().writeByte('\n');
    }
    
    try std.fs.cwd().writeFile(output_path, output.items);
    std.debug.print("Rewrote {s} to 103×80 format\n", .{output_path});
}
