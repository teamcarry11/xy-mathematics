const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // skip executable name
    if (args.next()) |input| {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("// Aurora preprocessor stub: {s}\n", .{input});
    } else {
        try printUsage();
    }
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("usage: aurora-preprocess <file.aurora>\n", .{});
}
