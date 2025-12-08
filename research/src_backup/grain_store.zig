const std = @import("std");
const foundations = @import("grain-foundations");

const GrainDevName = foundations.GrainDevName;

pub const ManifestEntry = struct {
    platform: []const u8,
    org: []const u8,
    repo: []const u8,
};

pub const GrainStore = struct {
    allocator: std.mem.Allocator,
    devname: GrainDevName,
    base_dir: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        dev_input: []const u8,
    ) !GrainStore {
        const name = try foundations.graindevname.normalize(
            allocator,
            dev_input,
        );

        return .{
            .allocator = allocator,
            .devname = name,
            .base_dir = "grainstore",
        };
    }

    pub fn deinit(self: *GrainStore) void {
        self.allocator.free(self.devname.name);
    }

    pub fn ensure_platforms(
        self: GrainStore,
        platforms: []const []const u8,
    ) !void {
        const cwd = std.fs.cwd();
        try cwd.makePath(self.base_dir);

        for (platforms) |platform| {
            const path = try std.fmt.allocPrint(
                self.allocator,
                "{s}/{s}",
                .{ self.base_dir, platform },
            );
            defer self.allocator.free(path);
            try cwd.makePath(path);
        }
    }

    pub fn repo_path(
        self: GrainStore,
        platform: []const u8,
        org: []const u8,
        repo: []const u8,
    ) ![]u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}/{s}/{s}",
            .{ self.base_dir, platform, org, repo },
        );
    }

    pub fn sync_manifest_entries(
        self: GrainStore,
        entries: []const ManifestEntry,
    ) !void {
        const cwd = std.fs.cwd();
        for (entries) |entry| {
            const dir = try self.repo_path(
                entry.platform,
                entry.org,
                entry.repo,
            );
            defer self.allocator.free(dir);
            try cwd.makePath(dir);
        }
    }
};

test "grainstore sync manifest entries" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const allocator = std.testing.allocator;

    const original = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(original);
    defer std.os.chdir(original) catch {};
    try std.os.chdir(tmp.dir.path.?);

    var store = try GrainStore.init(allocator, "@test");
    defer store.deinit();

    const base_dir = try allocator.dupe(u8, "grainstore");
    defer allocator.free(base_dir);
    store.base_dir = base_dir;

    const platforms = [_][]const u8{ "codeberg", "github", "gitab" };
    try store.ensure_platforms(&platforms);

    const manifest_entries = @import("grain_manifest.zig").entries;
    try store.sync_manifest_entries(manifest_entries[0..]);

    for (manifest_entries) |entry| {
        const path = try std.fmt.allocPrint(
            allocator,
            "grainstore/{s}/{s}/{s}",
            .{ entry.platform, entry.org, entry.repo },
        );
        defer allocator.free(path);
        try tmp.dir.access(path, .{});
    }
}
