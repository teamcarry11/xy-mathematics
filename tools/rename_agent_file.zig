const std = @import("std");
const grainorder = @import("grainorder");

/// Tool to rename inter-agent communication files with grainorder + timestamp.
/// Usage: zig run tools/rename_agent_file.zig -- <old-name> <descriptive-name>
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <old-filename> <descriptive-name>\n", .{args[0]});
        std.debug.print("Example: {s} agent_coordination_status.md agent-coordination-status\n", .{args[0]});
        return;
    }

    const old_filename = args[1];
    const descriptive_name = args[2];

    // Get current timestamp
    const timestamp = try get_timestamp(allocator);
    defer allocator.free(timestamp);

    // Get next grainorder code (smaller = newer)
    // For now, we'll need to find the most recent grainorder in docs/
    // This is a placeholder - full implementation would scan docs/ for existing codes
    const next_grainorder = try get_next_grainorder(allocator);
    defer allocator.free(next_grainorder);

    // Format new filename
    const new_filename = try std.fmt.allocPrint(
        allocator,
        "{s}-{s}-{s}.md",
        .{ next_grainorder, timestamp, descriptive_name },
    );
    defer allocator.free(new_filename);

    std.debug.print("Rename: {s} -> {s}\n", .{ old_filename, new_filename });
    std.debug.print("Run: mv {s} docs/{s}\n", .{ old_filename, new_filename });
}

fn get_timestamp(allocator: std.mem.Allocator) ![]const u8 {
    const now = std.time.timestamp();
    const epoch_seconds = @as(i64, @intCast(now));
    
    // Convert to local time (simplified - would need proper timezone handling)
    const seconds_per_day = 86400;
    const days_since_epoch = @divTrunc(epoch_seconds, seconds_per_day);
    const seconds_today = @mod(epoch_seconds, seconds_per_day);
    
    const hours = @divTrunc(seconds_today, 3600);
    const minutes = @divTrunc(@mod(seconds_today, 3600), 60);
    const seconds = @mod(seconds_today, 60);
    
    // Format: yyyy-mm-dd--hhmm-ss
    // This is simplified - would need proper date calculation
    return try std.fmt.allocPrint(
        allocator,
        "2025-11-23--{d:0>2}{d:0>2}-{d:0>2}",
        .{ hours, minutes, seconds },
    );
}

fn get_next_grainorder(allocator: std.mem.Allocator) ![]const u8 {
    // Placeholder: would scan docs/ for existing grainorder codes
    // and return the next smaller one
    _ = allocator;
    return try std.fmt.allocPrint(allocator, "bchlnp", .{});
}
