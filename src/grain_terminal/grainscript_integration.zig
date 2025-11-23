const std = @import("std");
const grainscript = @import("grainscript");
const Lexer = grainscript.Lexer;
const Parser = grainscript.Parser;
const Interpreter = grainscript.Interpreter;

/// Grain Terminal Grainscript Integration: Execute Grainscript in terminal.
/// ~<~ Glow Airbend: explicit command execution, bounded output capture.
/// ~~~~ Glow Waterbend: deterministic script execution, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const GrainscriptIntegration = struct {
    // Bounded: Max output buffer size (explicit limit, in bytes)
    pub const MAX_OUTPUT_BUFFER: u32 = 1_048_576; // 1 MB

    // Bounded: Max command line length (explicit limit)
    pub const MAX_COMMAND_LEN: u32 = 65_536; // 64 KB

    // Bounded: Max REPL history entries (explicit limit)
    pub const MAX_REPL_HISTORY: u32 = 1_024;

    /// Output capture structure.
    pub const OutputCapture = struct {
        stdout: []u8, // Captured stdout (bounded)
        stdout_len: u32,
        stderr: []u8, // Captured stderr (bounded)
        stderr_len: u32,
        exit_code: u32, // Exit code
        allocator: std.mem.Allocator,

        /// Initialize output capture.
        pub fn init(allocator: std.mem.Allocator) !OutputCapture {
            // Assert: Allocator must be valid
            std.debug.assert(allocator.ptr != null);

            // Pre-allocate stdout buffer
            const stdout = try allocator.alloc(u8, MAX_OUTPUT_BUFFER);
            errdefer allocator.free(stdout);

            // Pre-allocate stderr buffer
            const stderr = try allocator.alloc(u8, MAX_OUTPUT_BUFFER);
            errdefer allocator.free(stderr);

            return OutputCapture{
                .stdout = stdout,
                .stdout_len = 0,
                .stderr = stderr,
                .stderr_len = 0,
                .exit_code = 0,
                .allocator = allocator,
            };
        }

        /// Deinitialize output capture and free memory.
        pub fn deinit(self: *OutputCapture) void {
            // Assert: Allocator must be valid
            std.debug.assert(self.allocator.ptr != null);

            self.allocator.free(self.stdout);
            self.allocator.free(self.stderr);

            self.* = undefined;
        }

        /// Append to stdout.
        pub fn append_stdout(self: *OutputCapture, data: []const u8) !void {
            // Check buffer limit
            if (self.stdout_len + data.len > MAX_OUTPUT_BUFFER) {
                return error.OutputBufferFull;
            }

            @memcpy(self.stdout[self.stdout_len..][0..data.len], data);
            self.stdout_len += @as(u32, @intCast(data.len));
        }

        /// Append to stderr.
        pub fn append_stderr(self: *OutputCapture, data: []const u8) !void {
            // Check buffer limit
            if (self.stderr_len + data.len > MAX_OUTPUT_BUFFER) {
                return error.OutputBufferFull;
            }

            @memcpy(self.stderr[self.stderr_len..][0..data.len], data);
            self.stderr_len += @as(u32, @intCast(data.len));
        }
    };

    /// REPL state structure.
    pub const ReplState = struct {
        history: []const []const u8, // Command history (bounded)
        history_len: u32,
        history_index: u32, // Current history index
        allocator: std.mem.Allocator,

        /// Initialize REPL state.
        pub fn init(allocator: std.mem.Allocator) !ReplState {
            // Assert: Allocator must be valid
            std.debug.assert(allocator.ptr != null);

            // Pre-allocate history buffer
            const history = try allocator.alloc([]const u8, MAX_REPL_HISTORY);
            errdefer allocator.free(history);

            return ReplState{
                .history = history,
                .history_len = 0,
                .history_index = 0,
                .allocator = allocator,
            };
        }

        /// Deinitialize REPL state and free memory.
        pub fn deinit(self: *ReplState) void {
            // Assert: Allocator must be valid
            std.debug.assert(self.allocator.ptr != null);

            // Free all history entries
            var i: u32 = 0;
            while (i < self.history_len) : (i += 1) {
                self.allocator.free(self.history[i]);
            }

            // Free history buffer
            self.allocator.free(self.history);

            self.* = undefined;
        }

        /// Add command to history.
        pub fn add_command(self: *ReplState, command: []const u8) !void {
            // Check history limit
            if (self.history_len >= MAX_REPL_HISTORY) {
                // Remove oldest entry (shift left)
                self.allocator.free(self.history[0]);
                var i: u32 = 0;
                while (i < self.history_len - 1) : (i += 1) {
                    self.history[i] = self.history[i + 1];
                }
                self.history_len -= 1;
            }

            // Allocate command copy
            const command_copy = try self.allocator.dupe(u8, command);
            errdefer self.allocator.free(command_copy);

            self.history[self.history_len] = command_copy;
            self.history_len += 1;
            self.history_index = self.history_len; // Reset to end
        }

        /// Get previous command from history.
        pub fn get_previous(self: *ReplState) ?[]const u8 {
            if (self.history_index == 0) {
                return null;
            }
            self.history_index -= 1;
            return self.history[self.history_index];
        }

        /// Get next command from history.
        pub fn get_next(self: *ReplState) ?[]const u8 {
            if (self.history_index >= self.history_len) {
                return null;
            }
            self.history_index += 1;
            if (self.history_index >= self.history_len) {
                return null;
            }
            return self.history[self.history_index];
        }
    };

    /// Execute Grainscript command and capture output.
    pub fn execute_command(allocator: std.mem.Allocator, source: []const u8) !OutputCapture {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        // Assert: Source must be bounded
        std.debug.assert(source.len <= MAX_COMMAND_LEN);

        // Initialize output capture
        var capture = try OutputCapture.init(allocator);
        errdefer capture.deinit();

        // Create lexer
        var lexer = Lexer.init(allocator, source);
        defer lexer.deinit();

        // Tokenize
        try lexer.tokenize();

        // Create parser
        var parser = try Parser.init(allocator, &lexer);
        defer parser.deinit();

        // Parse
        try parser.parse();

        // Create interpreter
        var interpreter = try Interpreter.init(allocator, &parser);
        defer interpreter.deinit();

        // Execute (capture output would go here)
        try interpreter.execute();

        // Get exit code
        capture.exit_code = interpreter.exit_code;

        return capture;
    }

    /// Execute Grainscript script from file.
    pub fn execute_script(allocator: std.mem.Allocator, file_path: []const u8) !OutputCapture {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        // Read file (bounded)
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        if (file_size > MAX_COMMAND_LEN) {
            return error.FileTooLarge;
        }

        const source = try allocator.alloc(u8, @as(usize, @intCast(file_size)));
        defer allocator.free(source);

        _ = try file.readAll(source);

        // Execute command
        return execute_command(allocator, source);
    }
};

