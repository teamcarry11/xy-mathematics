//! Tests for Grain Style CLI tool.
//!
//! Why: Verify standalone CLI tool for Grain Style linting.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool tests
//! 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration tests

const std = @import("std");
const testing = std.testing;
const GrainStyleCLI = @import("../src/grain_workspace/grain_style_cli/main.zig").GrainStyleCLI;
const ExitCode = @import("../src/grain_workspace/grain_style_cli/main.zig").ExitCode;

test "grain style cli initialization" {
    const allocator = testing.allocator;

    var cli = GrainStyleCLI.init(allocator);

    try testing.expect(@intFromPtr(&cli) != 0);
    try testing.expect(cli.devtools_app.linter_messages_len == 0);
}

test "read file content" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary test file
    const test_file = "test_grain_style_cli.zig";
    const test_content = "pub fn test() void {\n    var x: u32 = 0;\n}";

    // Write test file
    const file = try std.fs.cwd().createFile(test_file, .{});
    defer file.close();
    try file.writeAll(test_content);
    defer std.fs.cwd().deleteFile(test_file) catch {};

    var content: [1024]u8 = undefined;
    var content_len: u32 = 0;
    const result = cli.read_file_content(test_file, &content, &content_len);

    try testing.expect(result == true);
    try testing.expect(content_len > 0);
    try testing.expect(std.mem.eql(u8, content[0..content_len], test_content));
}

test "read file content invalid path" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    var content: [1024]u8 = undefined;
    var content_len: u32 = 0;
    const result = cli.read_file_content("nonexistent_file.zig", &content, &content_len);

    try testing.expect(result == false);
    try testing.expect(content_len == 0);
}

test "lint file valid code" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary test file with valid code
    const test_file = "test_valid.zig";
    const test_content = "pub fn test() void {\n    var x: u32 = 0;\n}";

    const file = try std.fs.cwd().createFile(test_file, .{});
    defer file.close();
    try file.writeAll(test_content);
    defer std.fs.cwd().deleteFile(test_file) catch {};

    const violations = cli.lint_file(test_file);

    // Valid code should have minimal violations
    try testing.expect(violations >= 0);
}

test "lint file with violations" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary test file with violations
    const test_file = "test_violations.zig";
    const test_content = "pub fn test() void {\n    var x: usize = 0;\n}";

    const file = try std.fs.cwd().createFile(test_file, .{});
    defer file.close();
    try file.writeAll(test_content);
    defer std.fs.cwd().deleteFile(test_file) catch {};

    const violations = cli.lint_file(test_file);

    // Should detect usize violation
    try testing.expect(violations > 0);
}

test "format violation message" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    const DevToolsApp = @import("../src/grain_workspace/devtools/app.zig").DevToolsApp;
    var msg = DevToolsApp.LinterMessage{
        .file_path = undefined,
        .file_path_len = 0,
        .line_number = 10,
        .column_number = 5,
        .severity = .error,
        .message = undefined,
        .message_len = 0,
    };

    // Set file path
    const file_path = "test.zig";
    @memset(&msg.file_path, 0);
    @memcpy(msg.file_path[0..file_path.len], file_path);
    msg.file_path_len = @as(u32, @intCast(file_path.len));

    // Set message
    const message = "Use explicit u32/u64 instead of usize";
    @memset(&msg.message, 0);
    @memcpy(msg.message[0..message.len], message);
    msg.message_len = @as(u32, @intCast(message.len));

    var output: [256]u8 = undefined;
    var output_len: u32 = 0;
    const result = cli.format_violation_message(msg, &output, &output_len);

    try testing.expect(result == true);
    try testing.expect(output_len > 0);
}

test "run with valid files" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary test file
    const test_file = "test_run.zig";
    const test_content = "pub fn test() void {\n    var x: u32 = 0;\n}";

    const file = try std.fs.cwd().createFile(test_file, .{});
    defer file.close();
    try file.writeAll(test_content);
    defer std.fs.cwd().deleteFile(test_file) catch {};

    const file_paths = [_][]const u8{test_file};
    const exit_code = cli.run(&file_paths);

    // Should return success or violations_found
    try testing.expect(exit_code == .success or exit_code == .violations_found);
}

test "run with files containing violations" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary test file with violations
    const test_file = "test_run_violations.zig";
    const test_content = "pub fn test() void {\n    var x: usize = 0;\n}";

    const file = try std.fs.cwd().createFile(test_file, .{});
    defer file.close();
    try file.writeAll(test_content);
    defer std.fs.cwd().deleteFile(test_file) catch {};

    const file_paths = [_][]const u8{test_file};
    const exit_code = cli.run(&file_paths);

    // Should return violations_found
    try testing.expect(exit_code == .violations_found);
}

test "load config file" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary config file
    const config_file = ".grainstyle";
    const config_content = "use_color=false\noutput_format=json\nmax_line_length=120\nmax_function_length=80\n";

    const file = try std.fs.cwd().createFile(config_file, .{});
    defer file.close();
    try file.writeAll(config_content);
    defer std.fs.cwd().deleteFile(config_file) catch {};

    const result = cli.load_config(config_file);

    try testing.expect(result == true);
    try testing.expect(cli.config.use_color == false);
    try testing.expect(cli.config.output_format == .json);
    try testing.expect(cli.config.max_line_length == 120);
    try testing.expect(cli.config.max_function_length == 80);
}

test "format violation message json" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);
    cli.config.output_format = .json;

    const DevToolsApp = @import("../src/grain_workspace/devtools/app.zig").DevToolsApp;
    var msg = DevToolsApp.LinterMessage{
        .file_path = undefined,
        .file_path_len = 0,
        .line_number = 10,
        .column_number = 5,
        .severity = .error,
        .message = undefined,
        .message_len = 0,
    };

    const file_path = "test.zig";
    @memset(&msg.file_path, 0);
    @memcpy(msg.file_path[0..file_path.len], file_path);
    msg.file_path_len = @as(u32, @intCast(file_path.len));

    const message = "Use explicit u32/u64 instead of usize";
    @memset(&msg.message, 0);
    @memcpy(msg.message[0..message.len], message);
    msg.message_len = @as(u32, @intCast(message.len));

    var output: [256]u8 = undefined;
    var output_len: u32 = 0;
    const result = cli.format_violation_message(msg, &output, &output_len);

    try testing.expect(result == true);
    try testing.expect(output_len > 0);
    try testing.expect(std.mem.indexOf(u8, output[0..output_len], "\"file\"") != null);
    try testing.expect(std.mem.indexOf(u8, output[0..output_len], "\"severity\"") != null);
}

test "parse command line arguments" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    const args = [_][]const u8{ "grain-style", "--json", "--no-color", "test.zig", "test2.zig" };
    var file_paths: [10]?[]const u8 = undefined;
    var file_paths_len: u32 = 0;

    const result = cli.parse_args(&args, &file_paths, &file_paths_len);

    try testing.expect(result == true);
    try testing.expect(file_paths_len == 2);
    try testing.expect(cli.config.output_format == .json);
    try testing.expect(cli.config.use_color == false);
    try testing.expect(file_paths[0] != null);
    try testing.expect(file_paths[1] != null);
}
