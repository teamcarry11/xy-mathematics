const std = @import("std");
const grainvalidate = @import("grainvalidate");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const targets = [_][]const u8{
        "src/ray.zig",
        "src/ray_app.zig",
        "src/nostr.zig",
    };

    var failure = false;

    for (targets) |path| {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(contents);

        const result = try grainvalidate.validate(
            allocator,
            contents,
            grainvalidate.default_config,
        );
        defer grainvalidate.free_result(allocator, result);

        if (!result.compliant) {
            failure = true;
            std.log.err("{s}: {d} violations (functions: {d}, lines: {d})", .{ path, result.violations.len, result.total_functions, result.total_lines });

            for (result.violations) |violation| {
                std.log.err("  line {d}: {s}", .{ violation.line, violation.message });
            }
        } else {
            std.log.info("{s}: compliant", .{path});
        }
    }

    if (failure) {
        return error.ValidationFailed;
    }
}
