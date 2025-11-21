// test program to validate fuzzed zig code
const std = @import("std");
const grainwrap = @import("grainwrap");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const test_files = [_][]const u8{
        "test_data/long_lines.zig",
        "test_data/mixed_lines.zig",
    };

    for (test_files) |file_path| {
        std.debug.print("\n=== Testing {s} ===\n", .{file_path});

        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const code = try allocator.alloc(u8, file_size);
        defer allocator.free(code);

        _ = try file.readAll(code);

        const result = try grainwrap.validate(allocator, code, 73);
        defer grainwrap.free_result(allocator, result);

        std.debug.print(
            "Total lines: {d}\n",
            .{result.total_lines},
        );
        std.debug.print(
            "Compliant: {}\n",
            .{result.compliant},
        );
        std.debug.print(
            "Violations: {d}\n",
            .{result.violations.len},
        );

        if (result.violations.len > 0) {
            std.debug.print("\nViolations:\n", .{});
            for (result.violations) |violation| {
                std.debug.print(
                    "  Line {d}: {d} chars\n",
                    .{ violation.line_number, violation.length },
                );
                std.debug.print(
                    "    {s}\n",
                    .{violation.content},
                );
            }
        }
    }
}

