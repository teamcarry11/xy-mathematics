const std = @import("std");

/// GrainVault: simple, explicit holder for API secrets needed to script
/// Cursor CLI and Claude Code sessions. The actual secret material is
/// expected to live in the external `{teamtreasure02}/grainvault`
/// repository, mirrored in via `grainmirror`. This stub reads from
/// environment variables so we avoid bundling secrets in-source.
pub const Vault = struct {
    cursor_cli_key: []const u8,
    claude_code_key: []const u8,

    pub fn initFromEnv(allocator: std.mem.Allocator) !Vault {
        const cursor_key = try dupEnv(allocator, "CURSOR_API_TOKEN");
        errdefer allocator.free(cursor_key);
        const claude_key = try dupEnv(allocator, "CLAUDE_CODE_API_TOKEN");
        errdefer allocator.free(claude_key);

        return .{
            .cursor_cli_key = cursor_key,
            .claude_code_key = claude_key,
        };
    }

    pub fn deinit(self: *Vault, allocator: std.mem.Allocator) void {
        allocator.free(self.cursor_cli_key);
        allocator.free(self.claude_code_key);
        self.* = undefined;
    }

    pub fn cursorCommandArgs(self: Vault, extra_args: []const []const u8, allocator: std.mem.Allocator) ![]const []const u8 {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();

        try list.append("cursor");
        try list.append("--api-key");
        try list.append(self.cursor_cli_key);
        for (extra_args) |arg| try list.append(arg);

        return list.toOwnedSlice();
    }

    pub fn claudeCommandArgs(self: Vault, extra_args: []const []const u8, allocator: std.mem.Allocator) ![]const []const u8 {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();

        try list.append("claude");
        try list.append("--api-key");
        try list.append(self.claude_code_key);
        for (extra_args) |arg| try list.append(arg);

        return list.toOwnedSlice();
    }
};

fn dupEnv(allocator: std.mem.Allocator, key: []const u8) ![]const u8 {
    const value = std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return error.MissingSecret,
        else => return err,
    };
    if (value.len == 0) return error.MissingSecret;
    return value;
}

pub const MissingSecret = error{MissingSecret};
