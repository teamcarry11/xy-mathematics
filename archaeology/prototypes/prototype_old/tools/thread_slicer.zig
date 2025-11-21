const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var input = try std.fs.cwd().openFile("docs/ray.md", .{});
    defer input.close();

    const data = try input.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    var output = try std.fs.cwd().createFile("docs/ray_160.md", .{ .truncate = true });
    defer output.close();

    var index: usize = 0;
    var start: usize = 0;
    while (start < data.len) {
        index += 1;
        const prefix_len = digitCount(index) + 3; // "N/ "
        var chunk_cap: usize = 160;
        if (prefix_len >= chunk_cap) break;
        chunk_cap -= prefix_len;

        var end = start + chunk_cap;
        if (end > data.len) {
            end = data.len;
        }
        const chunk = data[start..end];

        try writeBlock(allocator, &output, index, chunk);
        start = end;
    }
}

fn writeBlock(
    allocator: std.mem.Allocator,
    file: *std.fs.File,
    index: usize,
    chunk: []const u8,
) !void {
    const header = try std.fmt.allocPrint(allocator, "```{d}/ \n", .{index});
    defer allocator.free(header);

    try file.writeAll(header);
    try file.writeAll(chunk);
    try file.writeAll("\n```\n\n");
}

fn digitCount(value: usize) usize {
    var count: usize = 1;
    var v = value;
    while (v >= 10) : (v /= 10) {
        count += 1;
    }
    return count;
}
