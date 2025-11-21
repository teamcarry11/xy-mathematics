//! grainspace: workspace structure and operations
//!
//! A grainspace is a developer's workspace following grain network
//! conventions. This module defines the structure and provides
//! operations for working with grainspaces.

const std = @import("std");
const graindevname = @import("graindevname.zig");

// A grain workspace with standard structure.
//
// Convention: ~/devname/graindevname/
// Example: ~/kae3g/grainkae3g/
//
// The grainstore lives inside: ~/kae3g/grainkae3g/grainstore/
pub const GrainSpace = struct {
    // The developer's normalized name
    devname: graindevname.GrainDevName,
    
    // Base path to the grainspace
    base_path: []const u8, // "~/kae3g/grainkae3g"
    
    // Path to the grainstore directory
    grainstore_path: []const u8, // "~/kae3g/grainkae3g/grainstore"
};

// Construct a grainspace from a developer name.
//
// This builds the conventional paths but does NOT check if they
// exist. Use ensure_grainstore() to create missing directories.
pub fn from_devname(
    allocator: std.mem.Allocator,
    devname: graindevname.GrainDevName,
) !GrainSpace {
    // Build base path: ~/devname/graindevname/
    const base = try std.fmt.allocPrint(
        allocator,
        "~/{s}/grain{s}",
        .{ devname.name, devname.name },
    );
    
    // Build grainstore path
    const grainstore = try std.fmt.allocPrint(
        allocator,
        "{s}/grainstore",
        .{base},
    );
    
    return GrainSpace{
        .devname = devname,
        .base_path = base,
        .grainstore_path = grainstore,
    };
}

// Expand ~ to actual home directory path.
//
// Why? The shell expands ~, but when we construct paths in code,
// we need to do it ourselves. Does this make sense?
pub fn expand_home(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]const u8 {
    if (path.len == 0 or path[0] != '~') {
        return try allocator.dupe(u8, path);
    }
    
    const home = std.process.getEnvVarOwned(
        allocator,
        "HOME",
    ) catch {
        return error.HomeNotSet;
    };
    defer allocator.free(home);
    
    return try std.fmt.allocPrint(
        allocator,
        "{s}{s}",
        .{ home, path[1..] },
    );
}

// Check if grainstore directory exists.
pub fn grainstore_exists(space: GrainSpace) !bool {
    const allocator = std.heap.page_allocator;
    const expanded = try expand_home(allocator, space.grainstore_path);
    defer allocator.free(expanded);
    
    std.fs.cwd().access(expanded, .{}) catch {
        return false;
    };
    
    return true;
}

// Ensure grainstore directory exists, creating it if needed.
pub fn ensure_grainstore(space: GrainSpace) !void {
    const allocator = std.heap.page_allocator;
    const expanded = try expand_home(allocator, space.grainstore_path);
    defer allocator.free(expanded);
    
    std.fs.cwd().makePath(expanded) catch |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    };
}

test "grainspace from devname" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    const devname = try graindevname.normalize(allocator, "@kae3g");
    defer allocator.free(devname.name);
    
    const space = try from_devname(allocator, devname);
    defer allocator.free(space.base_path);
    defer allocator.free(space.grainstore_path);
    
    try testing.expectEqualStrings(
        "~/kae3g/grainkae3g",
        space.base_path
    );
    try testing.expectEqualStrings(
        "~/kae3g/grainkae3g/grainstore",
        space.grainstore_path
    );
}

