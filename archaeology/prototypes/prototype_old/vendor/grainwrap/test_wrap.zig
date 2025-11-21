// test program to wrap fuzzed zig code
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
        std.debug.print("\n=== Wrapping {s} ===\n", .{file_path});

        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const code = try allocator.alloc(u8, file_size);
        defer allocator.free(code);

        _ = try file.readAll(code);

        const config = grainwrap.default_config;
        const wrapped = try grainwrap.wrap(allocator, code, config);
        defer allocator.free(wrapped);

        // check if wrapped code is compliant
        const validation = try grainwrap.validate(allocator, wrapped, 73);
        defer grainwrap.free_result(allocator, validation);

        std.debug.print(
            "Original: {d} lines\n",
            .{std.mem.count(u8, code, "\n")},
        );
        std.debug.print(
            "Wrapped: {d} lines\n",
            .{std.mem.count(u8, wrapped, "\n")},
        );
        std.debug.print(
            "Compliant: {}\n",
            .{validation.compliant},
        );
        std.debug.print(
            "Violations: {d}\n",
            .{validation.violations.len},
        );

        // write wrapped output
        const output_path = try std.fmt.allocPrint(
            allocator,
            "{s}.wrapped",
            .{file_path},
        );
        defer allocator.free(output_path);

        const output_file = try std.fs.cwd().createFile(output_path, .{});
        defer output_file.close();

        try output_file.writeAll(wrapped);
        std.debug.print("Wrapped output: {s}\n", .{output_path});
    }
}

