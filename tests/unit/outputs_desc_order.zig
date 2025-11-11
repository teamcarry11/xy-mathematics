const std = @import("std");

fn digitSlice(line: []const u8) ?[]const u8 {
    var start: usize = 0;
    var end: usize = line.len;
    while (start < end and !std.ascii.isDigit(line[start])) start += 1;
    while (end > start and !std.ascii.isDigit(line[end - 1])) end -= 1;
    if (end <= start) return null;
    return line[start..end];
}

fn collectIds(allocator: std.mem.Allocator) !std.ArrayListUnmanaged(u64) {
    var list = std.ArrayListUnmanaged(u64){};
    errdefer list.deinit(allocator);

    const file = try std.fs.cwd().openFile("docs/outputs.md", .{});
    defer file.close();

    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    var it = std.mem.splitScalar(u8, buffer, '\n');
    const marker = ".id =";
    while (it.next()) |line| {
        if (std.mem.indexOf(u8, line, marker)) |pos| {
            var idx = pos + marker.len;
            while (idx < line.len and !std.ascii.isDigit(line[idx])) idx += 1;
            const start = idx;
            while (idx < line.len and std.ascii.isDigit(line[idx])) idx += 1;
            if (idx == start) continue;
            const digits = line[start..idx];
            const id = try std.fmt.parseInt(u64, digits, 10);
            try list.append(allocator, id);
        }
    }

    return list;
}

fn verifyDescending(ids: []const u64) bool {
    if (ids.len < 2) return true;
    var i: usize = 1;
    while (i < ids.len) : (i += 1) {
        if (!(ids[i - 1] > ids[i])) return false;
    }
    return true;
}

test "outputs ids descend" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ids = try collectIds(allocator);
    defer ids.deinit(allocator);

    const ok = verifyDescending(ids.items);
    if (!ok) {
        std.debug.print("OUTPUTS array not strictly descending: {any}\n", .{ids.items});
    }
    try std.testing.expect(ok);
}
