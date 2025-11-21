//! cli: command line interface for grainmirror
//!
//! This tool synchronizes external repositories into your
//! grainstore based on the manifest specification.

const std = @import("std");
const grainmirror = @import("grainmirror.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("grainmirror (work in progress)\n\n", .{});
    try stdout.print("This tool reads grainstore-manifest and clones/updates\n", .{});
    try stdout.print("external repositories into your grainstore.\n\n", .{});
    try stdout.print("Pattern: grainstore/{{platform}}/{{org}}/{{repo}}\n", .{});
    try stdout.print("Example: grainstore/github/tigerbeetle/tigerbeetle\n\n", .{});
    try stdout.print("Usage:\n", .{});
    try stdout.print("  grainmirror sync    # Sync all repos from manifest\n", .{});
    try stdout.print("  grainmirror status  # Show mirror status\n\n", .{});
    
    _ = allocator;
}

