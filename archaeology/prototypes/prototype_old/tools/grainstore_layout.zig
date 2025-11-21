const std = @import("std");
const GrainStore = @import("grain_store.zig").GrainStore;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.next(); // program name
    const dev_arg = args_iter.next() orelse "@kae3g";

    var store = try GrainStore.init(allocator, dev_arg);
    defer store.deinit();

    const platforms = [_][]const u8{ "codeberg", "github", "gitab" };
    try store.ensure_platforms(&platforms);

    for (platforms) |platform| {
        const path = try store.repo_path(platform, store.devname.name, "placeholder");
        defer allocator.free(path);
        std.log.info(
            "grainstore platform ready: {s}/{s}",
            .{ store.base_dir, platform },
        );
    }
}
