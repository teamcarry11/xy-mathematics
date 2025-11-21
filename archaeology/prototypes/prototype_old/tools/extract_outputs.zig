const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // skip executable name

    const input_arg = args.next();
    const output_arg = args.next();

    if (input_arg != null and output_arg != null) {
        try run(allocator, input_arg.?, output_arg.?, .non_interactive);
        return;
    }

    if (input_arg == null and output_arg == null) {
        stdout("Interactive mode engaged.\n");
        const input_path = try promptForPath(allocator, "Enter cursor markdown export (.md) path: ");
        defer allocator.free(input_path);
        const output_path = try promptForPath(allocator, "Enter output zig path (.zig): ");
        defer allocator.free(output_path);
        try run(allocator, input_path, output_path, .interactive);
        return;
    }

    stderr("error: expected either zero args (interactive) or two args (input output)\n");
    printUsage();
}

const Mode = enum { interactive, non_interactive };

fn run(
    allocator: std.mem.Allocator,
    input_path: []const u8,
    output_path: []const u8,
    mode: Mode,
) !void {
    try ensureExtension(input_path, ".md");
    try ensureCursorPrefix(input_path);

    const cwd = std.fs.cwd();
    const content = try cwd.readFileAlloc(allocator, input_path, std.math.maxInt(usize));
    defer allocator.free(content);

    var responses = std.ArrayListUnmanaged(Response){};
    defer responses.deinit(allocator);
    try extractResponses(allocator, content, &responses);

    const file = try cwd.createFile(output_path, .{ .truncate = true });
    defer file.close();

    try file.writeAll("# Output Chronicle (u64 Append Ledger)\n\n```zig\n");
    try file.writeAll("pub const OutputEntry = struct {\n");
    try file.writeAll("    id: u64,\n");
    try file.writeAll("    timestamp: ?[]const u8,\n");
    try file.writeAll("    content: []const u8,\n");
    try file.writeAll("};\n\n");
    try file.writeAll("pub const OUTPUTS = [_]OutputEntry{\n");

    var entry_index: usize = responses.items.len;
    while (entry_index > 0) : (entry_index -= 1) {
        const response = responses.items[entry_index - 1];
        const entry_id = entry_index - 1;
        const content_str = try summarize(allocator, response.first_line, mode);
        defer allocator.free(content_str);

        const line = try std.fmt.allocPrint(allocator, "    .{{ .id = {d}, .timestamp = null, .content = \"{s}\" }},\n", .{
            entry_id,
            content_str,
        });
        defer allocator.free(line);
        try file.writeAll(line);
    }
    try file.writeAll("};\n\n");
    try file.writeAll("pub const OUTPUT_COUNT = OUTPUTS.len;\n");
    try file.writeAll("pub const latest_output = OUTPUTS[0];\n");
    try file.writeAll("```\n");

    std.debug.print(
        "Extraction complete.\nInput: {s}\nOutput: {s}\nEntries: {d}\n",
        .{ input_path, output_path, responses.items.len },
    );
}

const Response = struct {
    first_line: []const u8,
};

fn summarize(allocator: std.mem.Allocator, line: []const u8, mode: Mode) ![]u8 {
    _ = mode;
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    var list = std.ArrayListUnmanaged(u8){};
    defer list.deinit(allocator);

    if (trimmed.len == 0) {
        try list.appendSlice(allocator, "(empty response)");
    } else {
        for (trimmed) |ch| {
            switch (ch) {
                '\\' => try list.appendSlice(allocator, "\\\\"),
                '"' => try list.appendSlice(allocator, "\\\""),
                '\n' => try list.appendSlice(allocator, "\\n"),
                '\r' => try list.appendSlice(allocator, "\\r"),
                '\t' => try list.appendSlice(allocator, "\\t"),
                else => try list.append(allocator, ch),
            }
        }
    }

    return try list.toOwnedSlice(allocator);
}

fn extractResponses(
    allocator: std.mem.Allocator,
    content: []const u8,
    responses: *std.ArrayListUnmanaged(Response),
) !void {
    var iter = std.mem.splitScalar(u8, content, '\n');
    while (iter.next()) |line| {
        if (std.mem.startsWith(u8, line, "**Cursor**")) {
            var first_line: []const u8 = "(empty response)";
            var found = false;
            while (iter.next()) |candidate| {
                const trimmed = std.mem.trim(u8, candidate, " \r\t");
                if (trimmed.len == 0) continue;
                if (std.mem.startsWith(u8, trimmed, "---")) break;
                if (std.mem.startsWith(u8, trimmed, "```")) continue;
                if (!found) {
                    first_line = trimmed;
                    found = true;
                }
            }
            try responses.append(allocator, .{ .first_line = first_line });
        }
    }
}

fn ensureExtension(path: []const u8, ext: []const u8) !void {
    if (!std.mem.endsWith(u8, path, ext)) {
        std.debug.print("error: expected path ending with {s}: {s}\n", .{ ext, path });
        return error.InvalidExtension;
    }
}

fn promptForPath(allocator: std.mem.Allocator, prompt: []const u8) ![]u8 {
    stdout(prompt);
    const stdin_file = std.fs.File.stdin();

    var line = std.ArrayListUnmanaged(u8){};
    defer line.deinit(allocator);

    var buf: [1]u8 = undefined;
    var got_any = false;
    while (true) {
        const n = try std.posix.read(stdin_file.handle, buf[0..]);
        if (n == 0) break;
        got_any = true;
        if (buf[0] == '\n') break;
        try line.append(allocator, buf[0]);
    }
    if (!got_any and line.items.len == 0) return error.NoInput;

    const trimmed = std.mem.trim(u8, line.items, " \r\n\t");
    if (trimmed.len == 0) return error.EmptyPath;

    const copy = try allocator.alloc(u8, trimmed.len);
    std.mem.copyForwards(u8, copy, trimmed);
    return copy;
}

fn stdout(msg: []const u8) void {
    std.debug.print("{s}", .{msg});
}

fn stderr(msg: []const u8) void {
    std.debug.print("{s}", .{msg});
}

fn printUsage() void {
    stdout(
        "usage: extract_outputs <input.md> <output.zig>\n" ++
            "       extract_outputs            # interactive mode\n",
    );
}

fn ensureCursorPrefix(path: []const u8) !void {
    const base = std.fs.path.basename(path);
    if (!std.mem.startsWith(u8, base, "cursor")) {
        std.debug.print("error: markdown export must begin with 'cursor': {s}\n", .{path});
        return error.InvalidPrefix;
    }
}
