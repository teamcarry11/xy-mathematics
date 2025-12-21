//! Grain Style CLI: Standalone command-line tool for Grain Style linting.
//!
//! Why: Provide standalone CLI tool for linting Zig code for Grain Style compliance.
//! Architecture: CLI interface using DevTools linting functions.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
//! 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
//! 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
//! 2025-12-21-141612-pst: Phase 25 Performance Optimizations
//! 2025-12-21-141612-pst: Phase 26 Enhanced JSON Output
//! 2025-12-21-144225-pst: Phase 27 Full File Path Collection
//!
//! Open-Source Service Model: 100% open-source, revenue from services (consulting,
//! training, hosted services, enterprise support, sponsorships, grants).

const std = @import("std");
const grain_workspace = @import("grain_workspace");

// Bounded: Max file path length (explicit limit, in bytes)
// 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
pub const MAX_FILE_PATH_LEN: u32 = 512;

// Bounded: Max file size (explicit limit, in bytes)
// 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
pub const MAX_FILE_SIZE: u32 = 10_000_000; // 10 MB

// Bounded: Max output buffer size (explicit limit, in bytes)
// 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
pub const MAX_OUTPUT_BUFFER_SIZE: u32 = 1_048_576; // 1 MB

// Bounded: Max config file size (explicit limit, in bytes)
// 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
pub const MAX_CONFIG_FILE_SIZE: u32 = 8192; // 8 KB

// Bounded: Max config key length (explicit limit, in bytes)
// 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
pub const MAX_CONFIG_KEY_LEN: u32 = 64;

// Bounded: Max config value length (explicit limit, in bytes)
// 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
pub const MAX_CONFIG_VALUE_LEN: u32 = 256;

// Bounded: Max files to lint (explicit limit)
// 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
pub const MAX_FILES_TO_LINT: u32 = 10_000;

// Bounded: Max ignore patterns (explicit limit)
// 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
pub const MAX_IGNORE_PATTERNS: u32 = 256;

// Bounded: Max ignore pattern length (explicit limit, in bytes)
// 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
pub const MAX_IGNORE_PATTERN_LEN: u32 = 256;

// Bounded: Max violations before early exit (explicit limit)
// 2025-12-21-141612-pst: Phase 25 Performance Optimizations
pub const MAX_VIOLATIONS_BEFORE_EXIT: u32 = 1000;

// Bounded: Max summary statistics buffer size (explicit limit, in bytes)
// 2025-12-21-141612-pst: Phase 26 Enhanced JSON Output
pub const MAX_SUMMARY_BUFFER_SIZE: u32 = 8192; // 8 KB

// Exit code enumeration.
// 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
pub const ExitCode = enum(u8) {
    success, // No violations found
    violations_found, // Violations found
    error, // Error occurred
};

// Output format enumeration.
// 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
pub const OutputFormat = enum(u8) {
    text, // Plain text output
    json, // JSON output
};

// CLI configuration structure.
// 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
// 2025-12-21-141612-pst: Phase 25 Performance Optimizations
pub const CLIConfig = struct {
    use_color: bool, // Enable color output
    output_format: OutputFormat, // Output format
    max_line_length: u32, // Max line length (default 100)
    max_function_length: u32, // Max function length (default 70)
    max_violations: u32, // Max violations before early exit (default 1000)
};

// CLI application state.
// 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
// 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
// 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
pub const GrainStyleCLI = struct {
    allocator: std.mem.Allocator,
    devtools_app: grain_workspace.devtools.DevToolsApp,
    config: CLIConfig,
    ignore_patterns: [MAX_IGNORE_PATTERNS][MAX_IGNORE_PATTERN_LEN]u8,
    ignore_patterns_len: u32,

    /// Initialize CLI application.
    // 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
    // 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
    pub fn init(allocator: std.mem.Allocator) GrainStyleCLI {
        // Precondition: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        var cli = GrainStyleCLI{
            .allocator = allocator,
            .devtools_app = grain_workspace.devtools.DevToolsApp.init(allocator),
            .config = CLIConfig{
                .use_color = true,
                .output_format = .text,
                .max_line_length = 100,
                .max_function_length = 70,
                .max_violations = MAX_VIOLATIONS_BEFORE_EXIT,
            },
            .ignore_patterns = undefined,
            .ignore_patterns_len = 0,
        };

        // Initialize ignore patterns
        var i: u32 = 0;
        while (i < MAX_IGNORE_PATTERNS) : (i += 1) {
            @memset(&cli.ignore_patterns[i], 0);
        }

        // Postcondition: CLI must be valid
        std.debug.assert(@intFromPtr(&cli) != 0);

        return cli;
    }

    /// Load configuration from file.
    // 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
    pub fn load_config(
        self: *GrainStyleCLI,
        config_path: []const u8,
    ) bool {
        // Precondition: Config path must be valid
        std.debug.assert(config_path.len > 0);
        std.debug.assert(config_path.len <= MAX_FILE_PATH_LEN);

        var config_content: [MAX_CONFIG_FILE_SIZE]u8 = undefined;
        var content_len: u32 = 0;

        if (!self.read_file_content(config_path, &config_content, &content_len)) {
            return false;
        }

        // Simple config parsing (key=value format)
        var i: u32 = 0;
        while (i < content_len) : (i += 1) {
            if (config_content[i] == '\n' or config_content[i] == '\r') {
                continue;
            }

            var key_start: u32 = i;
            var key_end: u32 = i;
            while (key_end < content_len and config_content[key_end] != '=') : (key_end += 1) {}

            if (key_end >= content_len) {
                break;
            }

            var value_start: u32 = key_end + 1;
            var value_end: u32 = value_start;
            while (value_end < content_len and config_content[value_end] != '\n' and config_content[value_end] != '\r') : (value_end += 1) {}

            const key = config_content[key_start..key_end];
            const value = config_content[value_start..value_end];

            // Parse configuration values
            if (std.mem.eql(u8, key, "use_color")) {
                self.config.use_color = std.mem.eql(u8, value, "true");
            } else if (std.mem.eql(u8, key, "output_format")) {
                if (std.mem.eql(u8, value, "json")) {
                    self.config.output_format = .json;
                } else {
                    self.config.output_format = .text;
                }
            } else if (std.mem.eql(u8, key, "max_line_length")) {
                const parsed = std.fmt.parseInt(u32, value, 10) catch 100;
                self.config.max_line_length = parsed;
            } else if (std.mem.eql(u8, key, "max_function_length")) {
                const parsed = std.fmt.parseInt(u32, value, 10) catch 70;
                self.config.max_function_length = parsed;
            } else if (std.mem.eql(u8, key, "max_violations")) {
                const parsed = std.fmt.parseInt(u32, value, 10) catch MAX_VIOLATIONS_BEFORE_EXIT;
                self.config.max_violations = parsed;
            }

            i = value_end;
        }

        // Postcondition: Config must be valid
        std.debug.assert(self.config.max_line_length > 0);
        std.debug.assert(self.config.max_function_length > 0);

        return true;
    }

    /// Read file content.
    // 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
    pub fn read_file_content(
        self: *GrainStyleCLI,
        file_path: []const u8,
        content: []u8,
        content_len: *u32,
    ) bool {
        // Precondition: File path and buffer must be valid
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(content.len > 0);
        std.debug.assert(content_len != null);

        content_len.* = 0;

        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            _ = err;
            return false;
        };
        defer file.close();

        const file_size = file.getEndPos() catch |err| {
            _ = err;
            return false;
        };

        if (file_size > MAX_FILE_SIZE) {
            return false;
        }

        const size_u32 = @as(u32, @intCast(file_size));
        if (size_u32 > content.len) {
            return false;
        }

        const bytes_read = file.readAll(content[0..size_u32]) catch |err| {
            _ = err;
            return false;
        };

        content_len.* = @as(u32, @intCast(bytes_read));

        // Postcondition: Content length must be valid
        std.debug.assert(content_len.* <= content.len);

        return true;
    }

    /// Lint file and return violation count.
    // 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
    // 2025-12-21-141612-pst: Phase 25 Performance Optimizations
    pub fn lint_file(
        self: *GrainStyleCLI,
        file_path: []const u8,
    ) u32 {
        // Precondition: File path must be valid
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);

        var file_content: [MAX_FILE_SIZE]u8 = undefined;
        var content_len: u32 = 0;

        if (!self.read_file_content(file_path, &file_content, &content_len)) {
            return 0;
        }

        // Performance: Skip empty files early
        if (content_len == 0) {
            return 0;
        }

        const violations = self.devtools_app.lint_grain_style(
            file_path,
            file_content[0..content_len],
        );

        const alloc_violations = self.devtools_app.check_bounded_allocations(
            file_path,
            file_content[0..content_len],
        );

        // Postcondition: Violation count must be valid
        std.debug.assert(violations + alloc_violations <= grain_workspace.devtools.MAX_LINT_VIOLATIONS);

        return violations + alloc_violations;
    }

    /// Format violation message for output.
    // 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
    // 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
    pub fn format_violation_message(
        self: *GrainStyleCLI,
        msg: grain_workspace.devtools.LinterMessage,
        output: []u8,
        output_len: *u32,
    ) bool {
        // Precondition: Output buffer must be valid
        std.debug.assert(output.len > 0);
        std.debug.assert(output_len != null);

        output_len.* = 0;

        if (self.config.output_format == .json) {
            return self.format_violation_message_json(msg, output, output_len);
        }

        const severity_str = switch (msg.severity) {
            .info => "info",
            .warning => "warning",
            .error => "error",
            .critical => "critical",
        };

        const file_path_str = msg.file_path[0..msg.file_path_len];
        const message_str = msg.message[0..msg.message_len];

        var format_str: []const u8 = undefined;
        if (self.config.use_color) {
            const color_code = switch (msg.severity) {
                .info => "\x1b[36m", // Cyan
                .warning => "\x1b[33m", // Yellow
                .error => "\x1b[31m", // Red
                .critical => "\x1b[35m", // Magenta
            };
            const reset_code = "\x1b[0m";
            format_str = "{s}:{d}:{d}: {s}{s}{s}: {s}\n";
            const formatted = std.fmt.bufPrint(
                output,
                format_str,
                .{ file_path_str, msg.line_number, msg.column_number, color_code, severity_str, reset_code, message_str },
            ) catch |err| {
                _ = err;
                return false;
            };
            output_len.* = @as(u32, @intCast(formatted.len));
        } else {
            format_str = "{s}:{d}:{d}: {s}: {s}\n";
            const formatted = std.fmt.bufPrint(
                output,
                format_str,
                .{ file_path_str, msg.line_number, msg.column_number, severity_str, message_str },
            ) catch |err| {
                _ = err;
                return false;
            };
            output_len.* = @as(u32, @intCast(formatted.len));
        }

        // Postcondition: Output length must be valid
        std.debug.assert(output_len.* <= output.len);

        return true;
    }

    /// Format violation message as JSON (single object format).
    // 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
    pub fn format_violation_message_json(
        self: *GrainStyleCLI,
        msg: grain_workspace.devtools.LinterMessage,
        output: []u8,
        output_len: *u32,
    ) bool {
        // Precondition: Output buffer must be valid
        std.debug.assert(output.len > 0);
        std.debug.assert(output_len != null);

        output_len.* = 0;

        const severity_str = switch (msg.severity) {
            .info => "info",
            .warning => "warning",
            .error => "error",
            .critical => "critical",
        };

        const file_path_str = msg.file_path[0..msg.file_path_len];
        const message_str = msg.message[0..msg.message_len];

        const format_str = "{{\"file\":\"{s}\",\"line\":{d},\"column\":{d},\"severity\":\"{s}\",\"message\":\"{s}\"}}\n";
        const formatted = std.fmt.bufPrint(
            output,
            format_str,
            .{ file_path_str, msg.line_number, msg.column_number, severity_str, message_str },
        ) catch |err| {
            _ = err;
            return false;
        };

        output_len.* = @as(u32, @intCast(formatted.len));

        // Postcondition: Output length must be valid
        std.debug.assert(output_len.* <= output.len);

        _ = self; // Suppress unused warning

        return true;
    }

    /// Format violation message as JSON array element.
    // 2025-12-21-141612-pst: Phase 26 Enhanced JSON Output
    pub fn format_violation_json_array_element(
        self: *GrainStyleCLI,
        msg: grain_workspace.devtools.LinterMessage,
        output: []u8,
        output_len: *u32,
        is_first: bool,
    ) bool {
        // Precondition: Output buffer must be valid
        std.debug.assert(output.len > 0);
        std.debug.assert(output_len != null);

        output_len.* = 0;

        const severity_str = switch (msg.severity) {
            .info => "info",
            .warning => "warning",
            .error => "error",
            .critical => "critical",
        };

        const file_path_str = msg.file_path[0..msg.file_path_len];
        const message_str = msg.message[0..msg.message_len];

        const prefix = if (is_first) "" else ",";
        const format_str = "{s}{{\"file\":\"{s}\",\"line\":{d},\"column\":{d},\"severity\":\"{s}\",\"message\":\"{s}\"}}";
        const formatted = std.fmt.bufPrint(
            output,
            format_str,
            .{ prefix, file_path_str, msg.line_number, msg.column_number, severity_str, message_str },
        ) catch |err| {
            _ = err;
            return false;
        };

        output_len.* = @as(u32, @intCast(formatted.len));

        // Postcondition: Output length must be valid
        std.debug.assert(output_len.* <= output.len);

        _ = self; // Suppress unused warning

        return true;
    }

    /// Format summary statistics as JSON.
    // 2025-12-21-141612-pst: Phase 26 Enhanced JSON Output
    pub fn format_summary_json(
        self: *GrainStyleCLI,
        total_violations: u32,
        files_checked: u32,
        files_with_violations: u32,
        output: []u8,
        output_len: *u32,
    ) bool {
        // Precondition: Output buffer must be valid
        std.debug.assert(output.len > 0);
        std.debug.assert(output_len != null);

        output_len.* = 0;

        const format_str = "{{\"summary\":{{\"total_violations\":{d},\"files_checked\":{d},\"files_with_violations\":{d}}}}}\n";
        const formatted = std.fmt.bufPrint(
            output,
            format_str,
            .{ total_violations, files_checked, files_with_violations },
        ) catch |err| {
            _ = err;
            return false;
        };

        output_len.* = @as(u32, @intCast(formatted.len));

        // Postcondition: Output length must be valid
        std.debug.assert(output_len.* <= output.len);

        _ = self; // Suppress unused warning

        return true;
    }

    /// Print all violations for a file.
    // 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
    pub fn print_violations(
        self: *GrainStyleCLI,
        file_path: []const u8,
    ) void {
        // Precondition: File path must be valid
        std.debug.assert(file_path.len > 0);
        std.debug.assert(file_path.len <= MAX_FILE_PATH_LEN);

        var messages: [256]?grain_workspace.devtools.LinterMessage = undefined;
        var messages_len: u32 = 0;
        self.devtools_app.get_linter_messages(file_path, &messages, &messages_len);

        var output_buffer: [MAX_OUTPUT_BUFFER_SIZE]u8 = undefined;
        var i: u32 = 0;
        while (i < messages_len) : (i += 1) {
            if (messages[i]) |msg| {
                var output_len: u32 = 0;
                if (self.format_violation_message(msg, &output_buffer, &output_len)) {
                    const stdout = std.io.getStdOut().writer();
                    _ = stdout.write(output_buffer[0..output_len]) catch {};
                }
            }
        }
    }

    /// Load ignore patterns from .grainignore file.
    // 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
    pub fn load_ignore_patterns(
        self: *GrainStyleCLI,
        ignore_file: []const u8,
    ) bool {
        // Precondition: Ignore file path must be valid
        std.debug.assert(ignore_file.len > 0);
        std.debug.assert(ignore_file.len <= MAX_FILE_PATH_LEN);

        var ignore_content: [MAX_CONFIG_FILE_SIZE]u8 = undefined;
        var content_len: u32 = 0;

        if (!self.read_file_content(ignore_file, &ignore_content, &content_len)) {
            return false;
        }

        self.ignore_patterns_len = 0;
        var line_start: u32 = 0;
        var i: u32 = 0;
        while (i < content_len and self.ignore_patterns_len < MAX_IGNORE_PATTERNS) : (i += 1) {
            if (ignore_content[i] == '\n' or ignore_content[i] == '\r') {
                if (i > line_start) {
                    const pattern_len = i - line_start;
                    if (pattern_len > 0 and pattern_len < MAX_IGNORE_PATTERN_LEN) {
                        @memset(&self.ignore_patterns[self.ignore_patterns_len], 0);
                        @memcpy(
                            self.ignore_patterns[self.ignore_patterns_len][0..pattern_len],
                            ignore_content[line_start..i],
                        );
                        self.ignore_patterns_len += 1;
                    }
                }
                line_start = i + 1;
            }
        }

        // Handle last line if no newline at end
        if (line_start < content_len and self.ignore_patterns_len < MAX_IGNORE_PATTERNS) {
            const pattern_len = content_len - line_start;
            if (pattern_len > 0 and pattern_len < MAX_IGNORE_PATTERN_LEN) {
                @memset(&self.ignore_patterns[self.ignore_patterns_len], 0);
                @memcpy(
                    self.ignore_patterns[self.ignore_patterns_len][0..pattern_len],
                    ignore_content[line_start..content_len],
                );
                self.ignore_patterns_len += 1;
            }
        }

        // Postcondition: Ignore patterns count must be valid
        std.debug.assert(self.ignore_patterns_len <= MAX_IGNORE_PATTERNS);

        return true;
    }

    /// Check if path matches any ignore pattern.
    // 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
    pub fn should_ignore(
        self: *const GrainStyleCLI,
        path: []const u8,
    ) bool {
        // Precondition: Path must be valid
        std.debug.assert(path.len > 0);

        var i: u32 = 0;
        while (i < self.ignore_patterns_len) : (i += 1) {
            const pattern = self.ignore_patterns[i][0..MAX_IGNORE_PATTERN_LEN];
            var pattern_len: u32 = 0;
            while (pattern_len < MAX_IGNORE_PATTERN_LEN and pattern[pattern_len] != 0) : (pattern_len += 1) {}

            if (pattern_len == 0) {
                continue;
            }

            const pattern_str = pattern[0..pattern_len];

            // Simple pattern matching (supports * wildcard)
            if (std.mem.indexOf(u8, pattern_str, "*") != null) {
                // Wildcard matching (simplified)
                if (std.mem.endsWith(u8, path, pattern_str[1..]) or
                    std.mem.startsWith(u8, path, pattern_str[0..pattern_len-1]))
                {
                    return true;
                }
            } else {
                // Exact match or substring match
                if (std.mem.eql(u8, path, pattern_str) or
                    std.mem.indexOf(u8, path, pattern_str) != null)
                {
                    return true;
                }
            }
        }

        return false;
    }

    /// Collect Zig files from directory recursively (count only).
    // 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
    pub fn collect_zig_files(
        self: *GrainStyleCLI,
        dir_path: []const u8,
        files: []?[]const u8,
        files_len: *u32,
    ) bool {
        // Precondition: Directory path and buffer must be valid
        std.debug.assert(dir_path.len > 0);
        std.debug.assert(dir_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(files.len > 0);
        std.debug.assert(files_len != null);

        if (self.should_ignore(dir_path)) {
            return true;
        }

        const dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
            _ = err;
            return false;
        };
        defer dir.close();

        var iterator = dir.iterate();
        while (iterator.next() catch |err| {
            _ = err;
            return false;
        }) |entry| {
            if (files_len.* >= files.len or files_len.* >= MAX_FILES_TO_LINT) {
                break;
            }

            var full_path: [MAX_FILE_PATH_LEN]u8 = undefined;
            var full_path_len: u32 = 0;

            if (dir_path.len + 1 + entry.name.len <= MAX_FILE_PATH_LEN) {
                @memcpy(full_path[0..dir_path.len], dir_path);
                full_path[dir_path.len] = '/';
                @memcpy(full_path[dir_path.len + 1..dir_path.len + 1 + entry.name.len], entry.name);
                full_path_len = @as(u32, @intCast(dir_path.len + 1 + entry.name.len));
            } else {
                continue;
            }

            const full_path_str = full_path[0..full_path_len];

            if (self.should_ignore(full_path_str)) {
                continue;
            }

            switch (entry.kind) {
                .file => {
                    if (std.mem.endsWith(u8, entry.name, ".zig")) {
                        // Count files only (for backward compatibility)
                        files_len.* += 1;
                    }
                },
                .directory => {
                    // Recursively collect files from subdirectory
                    _ = self.collect_zig_files(full_path_str, files, files_len);
                },
                else => {},
            }
        }

        // Postcondition: Files count must be valid
        std.debug.assert(files_len.* <= files.len);

        return true;
    }

    /// Collect Zig file paths from directory recursively.
    // 2025-12-21-144225-pst: Phase 27 Full File Path Collection
    pub fn collect_zig_file_paths(
        self: *GrainStyleCLI,
        dir_path: []const u8,
        file_paths: *std.ArrayList([]const u8),
    ) bool {
        // Precondition: Directory path and ArrayList must be valid
        std.debug.assert(dir_path.len > 0);
        std.debug.assert(dir_path.len <= MAX_FILE_PATH_LEN);
        std.debug.assert(@intFromPtr(file_paths) != 0);

        if (self.should_ignore(dir_path)) {
            return true;
        }

        const dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
            _ = err;
            return false;
        };
        defer dir.close();

        var iterator = dir.iterate();
        while (iterator.next() catch |err| {
            _ = err;
            return false;
        }) |entry| {
            if (file_paths.items.len >= MAX_FILES_TO_LINT) {
                break;
            }

            var full_path: [MAX_FILE_PATH_LEN]u8 = undefined;
            var full_path_len: u32 = 0;

            if (dir_path.len + 1 + entry.name.len <= MAX_FILE_PATH_LEN) {
                @memcpy(full_path[0..dir_path.len], dir_path);
                full_path[dir_path.len] = '/';
                @memcpy(full_path[dir_path.len + 1..dir_path.len + 1 + entry.name.len], entry.name);
                full_path_len = @as(u32, @intCast(dir_path.len + 1 + entry.name.len));
            } else {
                continue;
            }

            const full_path_str = full_path[0..full_path_len];

            if (self.should_ignore(full_path_str)) {
                continue;
            }

            switch (entry.kind) {
                .file => {
                    if (std.mem.endsWith(u8, entry.name, ".zig")) {
                        // Allocate and store file path
                        const path_copy = self.allocator.dupe(u8, full_path_str) catch {
                            return false;
                        };
                        file_paths.append(path_copy) catch {
                            self.allocator.free(path_copy);
                            return false;
                        };
                    }
                },
                .directory => {
                    // Recursively collect files from subdirectory
                    _ = self.collect_zig_file_paths(full_path_str, file_paths);
                },
                else => {},
            }
        }

        // Postcondition: File paths count must be valid
        std.debug.assert(file_paths.items.len <= MAX_FILES_TO_LINT);

        return true;
    }

    /// Parse command-line arguments.
    // 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
    pub fn parse_args(
        self: *GrainStyleCLI,
        args: []const []const u8,
        file_paths: []?[]const u8,
        file_paths_len: *u32,
    ) bool {
        // Precondition: Args and buffers must be valid
        std.debug.assert(args.len > 0);
        std.debug.assert(file_paths.len > 0);
        std.debug.assert(file_paths_len != null);

        file_paths_len.* = 0;
        var i: u32 = 1; // Skip program name
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "--json")) {
                self.config.output_format = .json;
            } else if (std.mem.eql(u8, arg, "--no-color")) {
                self.config.use_color = false;
            } else if (std.mem.eql(u8, arg, "--config") and i + 1 < args.len) {
                i += 1;
                const config_path = args[i];
                _ = self.load_config(config_path);
            } else if (std.mem.eql(u8, arg, "--ignore") and i + 1 < args.len) {
                i += 1;
                const ignore_path = args[i];
                _ = self.load_ignore_patterns(ignore_path);
            } else if (!std.mem.startsWith(u8, arg, "--")) {
                if (file_paths_len.* < file_paths.len) {
                    file_paths[file_paths_len.*] = arg;
                    file_paths_len.* += 1;
                }
            }
        }

        // Postcondition: File paths count must be valid
        std.debug.assert(file_paths_len.* <= file_paths.len);

        return file_paths_len.* > 0;
    }

    /// Check if path is a directory.
    // 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
    pub fn is_directory(
        self: *GrainStyleCLI,
        path: []const u8,
    ) bool {
        // Precondition: Path must be valid
        std.debug.assert(path.len > 0);
        std.debug.assert(path.len <= MAX_FILE_PATH_LEN);

        const dir = std.fs.cwd().openDir(path, .{}) catch |err| {
            _ = err;
            return false;
        };
        dir.close();

        _ = self; // Suppress unused warning

        return true;
    }

    /// Run linting on files/directories and return exit code.
    // 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
    // 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
    // 2025-12-21-083947-pst: Phase 24 Recursive Directory Linting
    // 2025-12-21-141612-pst: Phase 25 Performance Optimizations
    // 2025-12-21-141612-pst: Phase 26 Enhanced JSON Output
    // 2025-12-21-144225-pst: Phase 27 Full File Path Collection
    pub fn run(
        self: *GrainStyleCLI,
        file_paths: []const []const u8,
    ) ExitCode {
        // Precondition: File paths must be valid
        std.debug.assert(file_paths.len > 0);

        var total_violations: u32 = 0;
        var files_checked: u32 = 0;
        var files_with_violations: u32 = 0;
        var json_array_started: bool = false;

        // Phase 26: Start JSON array if JSON output format
        if (self.config.output_format == .json) {
            const stdout = std.io.getStdOut().writer();
            _ = stdout.write("{\"violations\":[") catch {};
            json_array_started = true;
        }

        // Phase 27: Collect all files to lint (from directories and files)
        var all_files = std.ArrayList([]const u8).init(self.allocator);
        defer {
            // Free all allocated file paths
            for (all_files.items) |file_path| {
                self.allocator.free(file_path);
            }
            all_files.deinit();
        }

        var i: u32 = 0;
        while (i < file_paths.len) : (i += 1) {
            const path = file_paths[i];

            if (self.is_directory(path)) {
                // Phase 27: Collect all .zig files from directory
                _ = self.collect_zig_file_paths(path, &all_files);
            } else {
                // Regular file - add to list if it's a .zig file
                if (std.mem.endsWith(u8, path, ".zig") and !self.should_ignore(path)) {
                    const path_copy = self.allocator.dupe(u8, path) catch continue;
                    all_files.append(path_copy) catch {
                        self.allocator.free(path_copy);
                        continue;
                    };
                }
            }
        }

        // Phase 27: Lint all collected files
        var file_i: u32 = 0;
        while (file_i < all_files.items.len) : (file_i += 1) {
            // Phase 25: Early exit if max violations reached
            if (total_violations >= self.config.max_violations) {
                break;
            }

            const path = all_files.items[file_i];
            files_checked += 1;
            const violations = self.lint_file(path);

            if (violations > 0) {
                files_with_violations += 1;
                total_violations += violations;

                if (self.config.output_format == .json) {
                    // Phase 26: Output as JSON array elements
                    var messages: [256]?grain_workspace.devtools.LinterMessage = undefined;
                    var messages_len: u32 = 0;
                    self.devtools_app.get_linter_messages(path, &messages, &messages_len);

                    var msg_i: u32 = 0;
                    while (msg_i < messages_len) : (msg_i += 1) {
                        if (messages[msg_i]) |msg| {
                            var output_buffer: [MAX_OUTPUT_BUFFER_SIZE]u8 = undefined;
                            var output_len: u32 = 0;
                            if (self.format_violation_json_array_element(
                                msg,
                                &output_buffer,
                                &output_len,
                                !json_array_started,
                            )) {
                                const stdout = std.io.getStdOut().writer();
                                _ = stdout.write(output_buffer[0..output_len]) catch {};
                                json_array_started = true;
                            }
                        }
                    }
                } else {
                    // Text output format
                    self.print_violations(path);
                }
            }
        }

        // Phase 26: Close JSON array and output summary
        if (self.config.output_format == .json) {
            const stdout = std.io.getStdOut().writer();
            _ = stdout.write("],") catch {};

            var summary_buffer: [MAX_SUMMARY_BUFFER_SIZE]u8 = undefined;
            var summary_len: u32 = 0;
            if (self.format_summary_json(
                total_violations,
                files_checked,
                files_with_violations,
                &summary_buffer,
                &summary_len,
            )) {
                _ = stdout.write(summary_buffer[0..summary_len]) catch {};
            }
        }

        // Postcondition: Total violations must be valid
        std.debug.assert(total_violations <= grain_workspace.devtools.MAX_LINT_VIOLATIONS * all_files.items.len);
        std.debug.assert(files_checked <= all_files.items.len);
        std.debug.assert(files_with_violations <= files_checked);

        if (total_violations > 0) {
            return .violations_found;
        }

        return .success;
    }
};
