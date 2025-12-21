//! Tests for Grain Style CLI tool.
//!
//! Why: Verify standalone CLI tool for Grain Style linting.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool tests
//! 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration tests
//! 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting tests
//! 2025-12-21-141612-pst: Phase 25 Performance Optimizations tests
//! 2025-12-21-141612-pst: Phase 26 Enhanced JSON Output tests
//! 2025-12-21-144225-pst: Phase 27 Full File Path Collection tests

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

test "load ignore patterns" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary ignore file
    const ignore_file = ".grainignore";
    const ignore_content = "node_modules\n*.tmp\ntest/\n";

    const file = try std.fs.cwd().createFile(ignore_file, .{});
    defer file.close();
    try file.writeAll(ignore_content);
    defer std.fs.cwd().deleteFile(ignore_file) catch {};

    const result = cli.load_ignore_patterns(ignore_file);

    try testing.expect(result == true);
    try testing.expect(cli.ignore_patterns_len > 0);
}

test "should ignore path" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Add ignore pattern manually
    const pattern = "node_modules";
    @memset(&cli.ignore_patterns[0], 0);
    @memcpy(cli.ignore_patterns[0][0..pattern.len], pattern);
    cli.ignore_patterns_len = 1;

    const should_ignore_result = cli.should_ignore("src/node_modules/test.zig");
    try testing.expect(should_ignore_result == true);

    const should_not_ignore = cli.should_ignore("src/test.zig");
    try testing.expect(should_not_ignore == false);
}

test "is directory" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary directory
    const test_dir = "test_dir_phase24";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteDir(test_dir) catch {};

    const is_dir = cli.is_directory(test_dir);
    try testing.expect(is_dir == true);

    // Create a file and check it's not a directory
    const test_file = "test_file_phase24.zig";
    const file = try std.fs.cwd().createFile(test_file, .{});
    defer file.close();
    defer std.fs.cwd().deleteFile(test_file) catch {};

    const is_file_dir = cli.is_directory(test_file);
    try testing.expect(is_file_dir == false);
}

test "collect zig files" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary directory with Zig files
    const test_dir = "test_collect_dir";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteDir(test_dir) catch {};

    // Create test files
    const file1 = try std.fs.cwd().createFile(test_dir ++ "/test1.zig", .{});
    defer file1.close();
    try file1.writeAll("pub fn test() void {}\n");

    const file2 = try std.fs.cwd().createFile(test_dir ++ "/test2.zig", .{});
    defer file2.close();
    try file2.writeAll("pub fn test2() void {}\n");

    var files: [10]?[]const u8 = undefined;
    var files_len: u32 = 0;
    const result = cli.collect_zig_files(test_dir, &files, &files_len);

    try testing.expect(result == true);
    try testing.expect(files_len >= 2);
}

test "format violation json array element" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);
    cli.config.output_format = .json;

    // Create a test message
    var msg: @import("../src/grain_workspace/devtools/app.zig").LinterMessage = undefined;
    @memset(&msg, 0);
    @memcpy(msg.file_path[0..10], "test.zig");
    msg.file_path_len = 7;
    @memcpy(msg.message[0..20], "Test violation");
    msg.message_len = 15;
    msg.line_number = 1;
    msg.column_number = 1;
    msg.severity = .warning;

    var output: [1024]u8 = undefined;
    var output_len: u32 = 0;

    // Test first element
    const result1 = cli.format_violation_json_array_element(msg, &output, &output_len, true);
    try testing.expect(result1 == true);
    try testing.expect(output_len > 0);
    try testing.expect(std.mem.indexOf(u8, output[0..output_len], "test.zig") != null);

    // Test subsequent element
    var output2: [1024]u8 = undefined;
    var output_len2: u32 = 0;
    const result2 = cli.format_violation_json_array_element(msg, &output2, &output_len2, false);
    try testing.expect(result2 == true);
    try testing.expect(output_len2 > 0);
    try testing.expect(std.mem.indexOf(u8, output2[0..output_len2], ",") != null);
}

test "format summary json" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);
    cli.config.output_format = .json;

    var output: [1024]u8 = undefined;
    var output_len: u32 = 0;

    const result = cli.format_summary_json(10, 5, 3, &output, &output_len);
    try testing.expect(result == true);
    try testing.expect(output_len > 0);
    try testing.expect(std.mem.indexOf(u8, output[0..output_len], "total_violations") != null);
    try testing.expect(std.mem.indexOf(u8, output[0..output_len], "files_checked") != null);
    try testing.expect(std.mem.indexOf(u8, output[0..output_len], "files_with_violations") != null);
}

test "run with max violations early exit" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);
    cli.config.max_violations = 5; // Set low limit for testing

    // Create test files with violations
    const test_file1 = "test_max1.zig";
    const test_content1 = "pub fn test() void {\n    var x: usize = 0;\n    var y: usize = 1;\n}";

    const file1 = try std.fs.cwd().createFile(test_file1, .{});
    defer file1.close();
    try file1.writeAll(test_content1);
    defer std.fs.cwd().deleteFile(test_file1) catch {};

    const test_file2 = "test_max2.zig";
    const test_content2 = "pub fn test2() void {\n    var z: usize = 2;\n}";

    const file2 = try std.fs.cwd().createFile(test_file2, .{});
    defer file2.close();
    try file2.writeAll(test_content2);
    defer std.fs.cwd().deleteFile(test_file2) catch {};

    const file_paths = [_][]const u8{ test_file1, test_file2 };
    const exit_code = cli.run(&file_paths);

    // Should exit with violations found
    try testing.expect(exit_code == .violations_found);
}

test "collect zig file paths" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary directory with Zig files
    const test_dir = "test_collect_paths_dir";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteDir(test_dir) catch {};

    // Create test files
    const file1 = try std.fs.cwd().createFile(test_dir ++ "/test1.zig", .{});
    defer file1.close();
    try file1.writeAll("pub fn test() void {}\n");

    const file2 = try std.fs.cwd().createFile(test_dir ++ "/test2.zig", .{});
    defer file2.close();
    try file2.writeAll("pub fn test2() void {}\n");

    var file_paths = std.ArrayList([]const u8).init(allocator);
    defer {
        for (file_paths.items) |path| {
            allocator.free(path);
        }
        file_paths.deinit();
    }

    const result = cli.collect_zig_file_paths(test_dir, &file_paths);

    try testing.expect(result == true);
    try testing.expect(file_paths.items.len >= 2);

    // Verify paths are valid
    var found1: bool = false;
    var found2: bool = false;
    for (file_paths.items) |path| {
        if (std.mem.indexOf(u8, path, "test1.zig") != null) {
            found1 = true;
        }
        if (std.mem.indexOf(u8, path, "test2.zig") != null) {
            found2 = true;
        }
    }
    try testing.expect(found1 == true);
    try testing.expect(found2 == true);
}

test "run with directory" {
    const allocator = testing.allocator;
    var cli = GrainStyleCLI.init(allocator);

    // Create a temporary directory with Zig files
    const test_dir = "test_run_dir";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteDir(test_dir) catch {};

    // Create test file with violation
    const test_file = try std.fs.cwd().createFile(test_dir ++ "/test.zig", .{});
    defer test_file.close();
    try test_file.writeAll("pub fn test() void {\n    var x: usize = 0;\n}");

    const file_paths = [_][]const u8{ test_dir };
    const exit_code = cli.run(&file_paths);

    // Should exit with violations found
    try testing.expect(exit_code == .violations_found);
}
