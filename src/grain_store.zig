const std = @import("std");
const foundations = @import("grain-foundations");

const GrainDevName = foundations.GrainDevName;

const ManifestEntry = struct {
    platform: []const u8,
    org: []const u8,
    repo: []const u8,
};

const Manifest = struct {
    entries: []ManifestEntry,
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

    pub fn sync_manifest(
        self: GrainStore,
        allocator: std.mem.Allocator,
        manifest_path: []const u8,
    ) !void {
        const cwd = std.fs.cwd();
        var file = try cwd.openFile(manifest_path, .{});
        defer file.close();

        const contents =
            try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(contents);

        var parsed = try std.json.parseFromSlice(
            Manifest,
            allocator,
            contents,
            .{ .duplicate_strings = true },
        );
        defer parsed.deinit();

        const manifest = parsed.value;
        for (manifest.entries) |entry| {
            const dir = try self.repo_path(
                entry.platform,
                entry.org,
                entry.repo,
            );
            defer allocator.free(dir);
            try cwd.makePath(dir);
        }
    }
};
