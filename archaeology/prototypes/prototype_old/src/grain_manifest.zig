const GrainStore = @import("grain_store.zig");

/// Static manifest entries for grainstore scaffolding.
/// Future versions can serialize / deserialize these for network casting.
pub const entries = [_]GrainStore.ManifestEntry{
    .{ .platform = "github", .org = "tigerbeetle", .repo = "tigerbeetle" },
    .{ .platform = "codeberg", .org = "river", .repo = "river" },
    .{ .platform = "github", .org = "matklad", .repo = "config" },
};


