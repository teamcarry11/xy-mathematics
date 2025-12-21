//! Grain Style CLI: Standalone command-line tool for Grain Style linting.
//!
//! Why: Provide standalone CLI tool for linting Zig code for Grain Style compliance.
//! Architecture: CLI interface using DevTools linting functions.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
//! 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
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
pub const CLIConfig = struct {
    use_color: bool, // Enable color output
    output_format: OutputFormat, // Output format
    max_line_length: u32, // Max line length (default 100)
    max_function_length: u32, // Max function length (default 70)
};

// CLI application state.
// 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
// 2025-12-21-083130-pst: Phase 23 Enhanced CLI Output and Configuration
pub const GrainStyleCLI = struct {
    allocator: std.mem.Allocator,
    devtools_app: grain_workspace.devtools.DevToolsApp,
    config: CLIConfig,

    /// Initialize CLI application.
    // 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
    pub fn init(allocator: std.mem.Allocator) GrainStyleCLI {
        // Precondition: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        var cli = GrainStyleCLI{
            .allocator = allocator,
            .devtools_app = grain_workspace.devtools.DevToolsApp.init(allocator),
        };

        // Postcondition: CLI must be valid
        std.debug.assert(@intFromPtr(&cli) != 0);

        return cli;
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

        const severity_str = switch (msg.severity) {
            .info => "info",
            .warning => "warning",
            .error => "error",
            .critical => "critical",
        };

        const file_path_str = msg.file_path[0..msg.file_path_len];
        const message_str = msg.message[0..msg.message_len];

        const format_str = "{s}:{d}:{d}: {s}: {s}\n";
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

    /// Run linting on files and return exit code.
    // 2025-12-20-200932-pst: Phase 22 Standalone CLI Tool
    pub fn run(
        self: *GrainStyleCLI,
        file_paths: []const []const u8,
    ) ExitCode {
        // Precondition: File paths must be valid
        std.debug.assert(file_paths.len > 0);

        var total_violations: u32 = 0;
        var i: u32 = 0;
        while (i < file_paths.len) : (i += 1) {
            const violations = self.lint_file(file_paths[i]);
            if (violations > 0) {
                self.print_violations(file_paths[i]);
            }
            total_violations += violations;
        }

        // Postcondition: Total violations must be valid
        std.debug.assert(total_violations <= grain_workspace.devtools.MAX_LINT_VIOLATIONS * file_paths.len);

        if (total_violations > 0) {
            return .violations_found;
        }

        return .success;
    }
};
