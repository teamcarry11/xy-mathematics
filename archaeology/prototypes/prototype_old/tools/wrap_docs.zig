const std = @import("std");
const grainwrap = @import("grainwrap");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.next(); // skip program name

    var targets = std.ArrayListUnmanaged([]const u8){};
    defer targets.deinit(allocator);

    while (args_iter.next()) |arg| {
        try targets.append(allocator, arg);
    }

    if (targets.items.len == 0) {
        try targets.append(allocator, "docs/ray.md");
        try targets.append(allocator, "docs/prompts.md");
    }

    var had_change = false;

    for (targets.items) |path| {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(contents);

        const wrapped = try grainwrap.wrap(
            allocator,
            contents,
            grainwrap.default_config,
        );
        defer allocator.free(wrapped);

        if (!std.mem.eql(u8, contents, wrapped)) {
            had_change = true;
            try std.fs.cwd().writeFile(.{
                .sub_path = path,
                .data = wrapped,
            });
        }
    }

    if (had_change) {
        std.log.info("wrap_docs: updated content to 73-char width", .{});
    } else {
        std.log.info("wrap_docs: no changes required", .{});
    }
}
