//! graindevname: developer identity normalization
//!
//! Grain network accepts real identities (GitHub usernames, etc.)
//! rather than forcing artificial naming constraints.
//!
//! This module normalizes various input formats into consistent
//! internal representations while preserving the original identity.

const std = @import("std");

// A grain developer name, normalized from various input formats.
//
// We accept formats like "@kae3g", "kae3g", "@jorangreef", etc.
// and normalize them to a consistent lowercase form without the @.
pub const GrainDevName = struct {
    // The normalized name (lowercase, no @ prefix)
    name: []const u8,
    
    // The original input format for display purposes
    original: []const u8,
};

// Normalize a developer name from user input.
//
// Accepts: "@kae3g", "kae3g", "@jorangreef", "matklad"
// Returns: normalized lowercase name without @ prefix
//
// Why normalize? So we can construct consistent filesystem paths
// and compare names reliably, while still accepting the user's
// preferred format. Does this make sense?
pub fn normalize(
    allocator: std.mem.Allocator,
    input: []const u8,
) !GrainDevName {
    // Remove @ prefix if present
    const without_at = if (input.len > 0 and input[0] == '@')
        input[1..]
    else
        input;
    
    // Convert to lowercase for consistency
    const lowercase = try allocator.alloc(u8, without_at.len);
    for (without_at, 0..) |c, i| {
        lowercase[i] = std.ascii.toLower(c);
    }
    
    return GrainDevName{
        .name = lowercase,
        .original = input,
    };
}

// Check if a developer name is valid.
//
// Valid names contain only alphanumeric characters, hyphens,
// and underscores (GitHub username rules).
pub fn is_valid(name: []const u8) bool {
    if (name.len == 0) return false;
    
    for (name) |c| {
        if (!std.ascii.isAlphanumeric(c) and 
            c != '-' and 
            c != '_') 
        {
            return false;
        }
    }
    
    return true;
}

test "normalize developer name" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    const result = try normalize(allocator, "@kae3g");
    defer allocator.free(result.name);
    
    try testing.expectEqualStrings("kae3g", result.name);
    try testing.expectEqualStrings("@kae3g", result.original);
}

test "normalize without @" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    const result = try normalize(allocator, "jorangreef");
    defer allocator.free(result.name);
    
    try testing.expectEqualStrings("jorangreef", result.name);
}

test "validate developer names" {
    const testing = std.testing;
    
    try testing.expect(is_valid("kae3g"));
    try testing.expect(is_valid("jorangreef"));
    try testing.expect(is_valid("rust-analyzer"));
    try testing.expect(!is_valid(""));
    try testing.expect(!is_valid("invalid@name"));
}

