const std = @import("std");

test "prompts ids are not strictly descending" {
    const content = @embedFile("../../docs/prompts.md");
    var it = std.mem.splitScalar(u8, content, '\n');

    var ids = std.ArrayList(u64).init(std.testing.allocator);
    defer ids.deinit();

    const marker = ".id = ";

    while (it.next()) |line| {
        if (std.mem.indexOf(u8, line, marker)) |idx| {
            const slice_start = idx + marker.len;
            const remaining = line[slice_start..];
            const trimmed =
                std.mem.trim(u8, remaining, " \t,");
            if (trimmed.len == 0) continue;

            const id = std.fmt.parseInt(u64, trimmed, 10) catch continue;
            ids.append(id) catch unreachable;
        }
    }

    try std.testing.expect(ids.items.len > 1);

    var is_descending = true;
    var prev = ids.items[0];
    for (ids.items[1..]) |current| {
        if (current >= prev) {
            is_descending = false;
            break;
        }
        prev = current;
    }

    try std.testing.expect(!is_descending);
}

