const std = @import("std");
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;

/// Magit-style VCS integration: virtual files with readonly metadata and editable hunks.
/// ~<~ Glow Airbend: readonly spans protect VCS metadata, hunks remain editable.
/// ~~~~ Glow Waterbend: VCS state flows from `jj` commands into virtual files.
pub const VcsClient = struct {
    allocator: std.mem.Allocator,
    repo_path: []const u8,
    
    // Bounded: Max 1000 virtual files
    pub const MAX_VIRTUAL_FILES: u32 = 1000;
    virtual_files: std.ArrayList(VirtualFile) = undefined,
    
    // Bounded: Max 100 pending `jj` commands
    pub const MAX_PENDING_COMMANDS: u32 = 100;
    pending_commands: std.ArrayList(PendingCommand) = undefined,
    
    pub const VirtualFile = struct {
        path: []const u8, // e.g., ".jj/status.jj"
        buffer: GrainBuffer,
        readonly_ranges: []const ReadonlyRange,
    };
    
    pub const ReadonlyRange = struct {
        start: u32,
        end: u32,
        type: ReadonlyType,
    };
    
    pub const ReadonlyType = enum {
        commit_hash,
        parent_info,
        file_path,
        diff_header,
    };
    
    pub const PendingCommand = struct {
        command: []const u8, // e.g., "jj status"
        args: []const []const u8,
        callback: ?*const fn (output: []const u8) void = null,
    };
    
    pub fn init(allocator: std.mem.Allocator, repo_path: []const u8) VcsClient {
        // Assert: Repo path must be non-empty
        std.debug.assert(repo_path.len > 0);
        std.debug.assert(repo_path.len <= 4096); // Bounded path length
        
        return VcsClient{
            .allocator = allocator,
            .repo_path = repo_path,
            .virtual_files = std.ArrayList(VirtualFile).init(allocator),
            .pending_commands = std.ArrayList(PendingCommand).init(allocator),
        };
    }
    
    pub fn deinit(self: *VcsClient) void {
        // Free virtual file paths and buffers
        for (self.virtual_files.items) |*vf| {
            self.allocator.free(vf.path);
            vf.buffer.deinit();
            self.allocator.free(vf.readonly_ranges);
        }
        self.virtual_files.deinit();
        
        // Free pending command strings
        for (self.pending_commands.items) |*cmd| {
            self.allocator.free(cmd.command);
            for (cmd.args) |arg| {
                self.allocator.free(arg);
            }
            self.allocator.free(cmd.args);
        }
        self.pending_commands.deinit();
        
        self.* = undefined;
    }
    
    /// Generate `.jj/status.jj` virtual file with readonly metadata and editable hunks.
    pub fn generate_status_file(self: *VcsClient) !void {
        // Assert: Bounded virtual files
        std.debug.assert(self.virtual_files.items.len < MAX_VIRTUAL_FILES);
        
        // Run `jj status` command
        const status_output = try self.run_jj_command(&.{ "status" });
        defer self.allocator.free(status_output);
        
        // Parse status output and create virtual file
        const status_path = ".jj/status.jj";
        var buffer = try GrainBuffer.fromSlice(self.allocator, status_output);
        errdefer buffer.deinit();
        
        // Identify readonly ranges (commit hashes, file paths, headers)
        var readonly_ranges = std.ArrayList(ReadonlyRange).init(self.allocator);
        errdefer readonly_ranges.deinit();
        
        try self.parse_status_output(status_output, &readonly_ranges);
        
        // Mark readonly ranges in buffer
        for (readonly_ranges.items) |range| {
            try buffer.markReadOnly(range.start, range.end);
        }
        
        // Create virtual file
        const path_copy = try self.allocator.dupe(u8, status_path);
        errdefer self.allocator.free(path_copy);
        
        const readonly_slice = try readonly_ranges.toOwnedSlice();
        errdefer self.allocator.free(readonly_slice);
        
        try self.virtual_files.append(VirtualFile{
            .path = path_copy,
            .buffer = buffer,
            .readonly_ranges = readonly_slice,
        });
        
        // Assert: Virtual file added successfully
        std.debug.assert(self.virtual_files.items.len <= MAX_VIRTUAL_FILES);
    }
    
    /// Parse `jj status` output and identify readonly ranges.
    fn parse_status_output(
        self: *VcsClient,
        output: []const u8,
        ranges: *std.ArrayList(ReadonlyRange),
    ) !void {
        _ = self;
        
        // Assert: Output must be non-empty
        std.debug.assert(output.len > 0);
        std.debug.assert(output.len <= 10 * 1024 * 1024); // Bounded output size (10MB)
        
        var i: u32 = 0;
        var line_start: u32 = 0;
        var in_hunk = false;
        
        while (i < output.len) {
            const ch = output[i];
            
            // Line breaks
            if (ch == '\n') {
                const line = output[line_start..i];
                
                // Check for readonly patterns
                if (std.mem.startsWith(u8, line, "Working copy changes:")) {
                    // Header line: readonly
                    try ranges.append(ReadonlyRange{
                        .start = line_start,
                        .end = i,
                        .type = .diff_header,
                    });
                } else if (std.mem.startsWith(u8, line, "Commit:")) {
                    // Commit line: hash is readonly
                    if (std.mem.indexOf(u8, line, " ")) |space_pos| {
                        try ranges.append(ReadonlyRange{
                            .start = @intCast(line_start + space_pos + 1),
                            .end = i,
                            .type = .commit_hash,
                        });
                    }
                } else if (std.mem.startsWith(u8, line, "Parent:")) {
                    // Parent line: info is readonly
                    if (std.mem.indexOf(u8, line, " ")) |space_pos| {
                        try ranges.append(ReadonlyRange{
                            .start = @intCast(line_start + space_pos + 1),
                            .end = i,
                            .type = .parent_info,
                        });
                    }
                } else if (std.mem.startsWith(u8, line, "  ")) {
                    // File path line: path is readonly
                    const path_end = std.mem.indexOfScalar(u8, line, ':') orelse line.len;
                    try ranges.append(ReadonlyRange{
                        .start = line_start + 2, // Skip "  "
                        .end = @intCast(line_start + 2 + path_end),
                        .type = .file_path,
                    });
                } else if (std.mem.startsWith(u8, line, "@@")) {
                    // Hunk header: readonly
                    in_hunk = true;
                    try ranges.append(ReadonlyRange{
                        .start = line_start,
                        .end = i,
                        .type = .diff_header,
                    });
                } else if (in_hunk and (ch == '+' or ch == '-' or ch == ' ')) {
                    // Hunk content: editable (not readonly)
                    in_hunk = false;
                }
                
                line_start = i + 1;
            }
            
            i += 1;
        }
        
        // Assert: Ranges must be valid
        for (ranges.items) |range| {
            std.debug.assert(range.start < range.end);
            std.debug.assert(range.end <= output.len);
        }
    }
    
    /// Generate `.jj/commit/*.diff` virtual file with readonly commit info and editable diff.
    pub fn generate_commit_diff(self: *VcsClient, commit_hash: []const u8) !void {
        // Assert: Commit hash must be valid
        std.debug.assert(commit_hash.len > 0);
        std.debug.assert(commit_hash.len <= 64); // Bounded hash length
        
        // Assert: Bounded virtual files
        std.debug.assert(self.virtual_files.items.len < MAX_VIRTUAL_FILES);
        
        // Run `jj diff` command
        const diff_output = try self.run_jj_command(&.{ "diff", "-r", commit_hash });
        defer self.allocator.free(diff_output);
        
        // Parse diff output and create virtual file
        const diff_path = try std.fmt.allocPrint(
            self.allocator,
            ".jj/commit/{s}.diff",
            .{commit_hash},
        );
        defer self.allocator.free(diff_path);
        
        var buffer = try GrainBuffer.fromSlice(self.allocator, diff_output);
        errdefer buffer.deinit();
        
        // Identify readonly ranges (commit info, diff headers)
        var readonly_ranges = std.ArrayList(ReadonlyRange).init(self.allocator);
        errdefer readonly_ranges.deinit();
        
        try self.parse_diff_output(diff_output, &readonly_ranges);
        
        // Mark readonly ranges in buffer
        for (readonly_ranges.items) |range| {
            try buffer.markReadOnly(range.start, range.end);
        }
        
        // Create virtual file
        const path_copy = try self.allocator.dupe(u8, diff_path);
        errdefer self.allocator.free(path_copy);
        
        const readonly_slice = try readonly_ranges.toOwnedSlice();
        errdefer self.allocator.free(readonly_slice);
        
        try self.virtual_files.append(VirtualFile{
            .path = path_copy,
            .buffer = buffer,
            .readonly_ranges = readonly_slice,
        });
        
        // Assert: Virtual file added successfully
        std.debug.assert(self.virtual_files.items.len <= MAX_VIRTUAL_FILES);
    }
    
    /// Parse `jj diff` output and identify readonly ranges.
    fn parse_diff_output(
        self: *VcsClient,
        output: []const u8,
        ranges: *std.ArrayList(ReadonlyRange),
    ) !void {
        _ = self;
        
        // Assert: Output must be non-empty
        std.debug.assert(output.len > 0);
        std.debug.assert(output.len <= 10 * 1024 * 1024); // Bounded output size (10MB)
        
        var i: u32 = 0;
        var line_start: u32 = 0;
        
        while (i < output.len) {
            const ch = output[i];
            
            // Line breaks
            if (ch == '\n') {
                const line = output[line_start..i];
                
                // Check for readonly patterns
                if (std.mem.startsWith(u8, line, "diff --git") or
                    std.mem.startsWith(u8, line, "index ") or
                    std.mem.startsWith(u8, line, "---") or
                    std.mem.startsWith(u8, line, "+++") or
                    std.mem.startsWith(u8, line, "@@"))
                {
                    // Diff header: readonly
                    try ranges.append(ReadonlyRange{
                        .start = line_start,
                        .end = i,
                        .type = .diff_header,
                    });
                }
                // Hunk content (lines starting with +, -, or space) is editable
                
                line_start = i + 1;
            }
            
            i += 1;
        }
        
        // Assert: Ranges must be valid
        for (ranges.items) |range| {
            std.debug.assert(range.start < range.end);
            std.debug.assert(range.end <= output.len);
        }
    }
    
    /// Run a `jj` command and return output.
    fn run_jj_command(self: *VcsClient, args: []const []const u8) ![]const u8 {
        // Assert: Args must be valid
        std.debug.assert(args.len > 0);
        std.debug.assert(args.len <= 32); // Bounded args count
        
        // Build command: `jj <args...>`
        var cmd_args = std.ArrayList([]const u8).init(self.allocator);
        defer cmd_args.deinit();
        
        try cmd_args.append("jj");
        for (args) |arg| {
            try cmd_args.append(arg);
        }
        
        // Spawn process
        var child = std.process.Child.init(cmd_args.items, self.allocator);
        child.cwd = self.repo_path;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        try child.spawn();
        
        // Read stdout
        const stdout = child.stdout orelse return error.NoStdout;
        var output = std.ArrayList(u8).init(self.allocator);
        errdefer output.deinit();
        
        var buf: [4096]u8 = undefined;
        while (true) {
            const bytes_read_u64 = try stdout.read(&buf);
            if (bytes_read_u64 == 0) break;
            
            // Assert: Bytes read fits in u32
            std.debug.assert(bytes_read_u64 <= std.math.maxInt(u32));
            const bytes_read = @intCast(bytes_read_u64);
            
            // Assert: Output size bounded
            std.debug.assert(output.items.len + bytes_read <= 10 * 1024 * 1024); // Max 10MB
            
            try output.appendSlice(buf[0..bytes_read]);
        }
        
        // Wait for process
        const term = try child.wait();
        
        // Assert: Command must succeed (or handle error gracefully)
        if (term != .Exited or term.Exited != 0) {
            return error.JjCommandFailed;
        }
        
        return try output.toOwnedSlice();
    }
    
    /// Watch for edits to virtual files and invoke `jj` commands.
    pub fn watch_edits(self: *VcsClient) !void {
        // Assert: Must have virtual files
        std.debug.assert(self.virtual_files.items.len > 0);
        
        // Check each virtual file for edits
        for (self.virtual_files.items) |*vf| {
            const text = vf.buffer.textSlice();
            
            // Detect if file was edited (simplified: check if buffer changed)
            // TODO: Implement proper edit detection with timestamps or hash
            
            // If `.jj/status.jj` was edited, run `jj commit` or `jj restore`
            if (std.mem.eql(u8, vf.path, ".jj/status.jj")) {
                // Parse edited hunks and invoke appropriate `jj` commands
                try self.process_status_edits(vf);
            }
        }
    }
    
    /// Process edits to `.jj/status.jj` and invoke `jj` commands.
    fn process_status_edits(self: *VcsClient, vf: *VirtualFile) !void {
        // Assert: Virtual file must be status file
        std.debug.assert(std.mem.eql(u8, vf.path, ".jj/status.jj"));
        
        const text = vf.buffer.textSlice();
        
        // Parse edited hunks (lines that are editable, not readonly)
        var edited_hunks = std.ArrayList(EditedHunk).init(self.allocator);
        defer edited_hunks.deinit();
        
        var i: u32 = 0;
        var line_start: u32 = 0;
        var in_editable_range = false;
        var hunk_start: u32 = 0;
        
        while (i < text.len) {
            const ch = text[i];
            
            if (ch == '\n') {
                const line = text[line_start..i];
                const line_start_u32 = line_start;
                const line_end_u32 = i;
                
                // Check if line is editable (not in readonly range)
                var is_readonly = false;
                for (vf.readonly_ranges) |range| {
                    if (line_start_u32 >= range.start and line_end_u32 <= range.end) {
                        is_readonly = true;
                        break;
                    }
                }
                
                if (!is_readonly and !in_editable_range) {
                    // Start of editable hunk
                    in_editable_range = true;
                    hunk_start = line_start_u32;
                } else if (is_readonly and in_editable_range) {
                    // End of editable hunk
                    in_editable_range = false;
                    try edited_hunks.append(EditedHunk{
                        .start = hunk_start,
                        .end = line_start_u32,
                    });
                }
                
                line_start = i + 1;
            }
            
            i += 1;
        }
        
        // If hunks were edited, invoke `jj` commands
        if (edited_hunks.items.len > 0) {
            // Assert: Bounded pending commands
            std.debug.assert(self.pending_commands.items.len < MAX_PENDING_COMMANDS);
            
            // Queue `jj commit` or `jj restore` command
            const cmd_str = try self.allocator.dupe(u8, "jj commit");
            errdefer self.allocator.free(cmd_str);
            
            try self.pending_commands.append(PendingCommand{
                .command = cmd_str,
                .args = &.{},
                .callback = null,
            });
        }
    }
    
    pub const EditedHunk = struct {
        start: u32,
        end: u32,
    };
    
    /// Get virtual file by path.
    pub fn get_virtual_file(self: *VcsClient, path: []const u8) ?*VirtualFile {
        // Assert: Path must be valid
        std.debug.assert(path.len > 0);
        std.debug.assert(path.len <= 4096); // Bounded path length
        
        for (self.virtual_files.items) |*vf| {
            if (std.mem.eql(u8, vf.path, path)) {
                return vf;
            }
        }
        
        return null;
    }
};

test "vcs client lifecycle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    // Test: Client initialized
    std.debug.assert(client.virtual_files.items.len == 0);
    std.debug.assert(client.pending_commands.items.len == 0);
}

test "vcs parse status output" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const repo_path = ".";
    var client = VcsClient.init(arena.allocator(), repo_path);
    defer client.deinit();
    
    const status_output = 
        \\Working copy changes:
        \\  modified: src/main.zig
        \\Commit: abc123def456
        \\Parent: xyz789
    ;
    
    var ranges = std.ArrayList(VcsClient.ReadonlyRange).init(arena.allocator());
    defer ranges.deinit();
    
    try client.parse_status_output(status_output, &ranges);
    
    // Assert: Should find readonly ranges
    std.debug.assert(ranges.items.len > 0);
}

