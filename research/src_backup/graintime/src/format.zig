//! format: grainbranch name formatting
//!
//! How do we turn temporal data into a grainbranch name? This
//! module handles the formatting with precision and clarity.

const std = @import("std");
const types = @import("types.zig");

// Format a grainbranch name from astronomical data.
//
// Takes a GrainBranch struct and produces the standard naming
// pattern used throughout grain network.
//
// Example:
//   12025-11-02--1515--pdt--moon-shatabhisha--asc-pisc00--sun-09h--kae3g
//
// The format is explicit and readable. Each component is
// separated clearly so humans can parse it visually.
pub fn format_branch(
    allocator: std.mem.Allocator,
    branch: types.GrainBranch,
) ![]u8 {
    // Abbreviate nakshatra to fit 73-char graincard width
    const nakshatra = types.abbreviate_nakshatra(branch.moon_nakshatra);
    
    return std.fmt.allocPrint(
        allocator,
        "{d:0>5}-{d:0>2}-{d:0>2}--{d:0>2}{d:0>2}--{s}--moon-{s}--asc-{s}{d:0>2}--sun-{d:0>2}h--{s}",
        .{
            branch.year,
            branch.month,
            branch.day,
            branch.hour,
            branch.minute,
            branch.timezone,
            nakshatra,
            branch.asc_sign,
            branch.asc_degrees,
            branch.sun_house,
            branch.author,
        },
    );
}

// Convert month number to lowercase abbreviated name.
//
// Why lowercase? Grain style values visual calm and
// consistency. Lowercase creates a gentle aesthetic.
pub fn month_name(month: u8) []const u8 {
    return switch (month) {
        1 => "jan",
        2 => "feb",
        3 => "mar",
        4 => "apr",
        5 => "may",
        6 => "jun",
        7 => "jul",
        8 => "aug",
        9 => "sep",
        10 => "oct",
        11 => "nov",
        12 => "dec",
        else => "unk",
    };
}

test "format grainbranch" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    const branch = types.GrainBranch{
        .year = 12025,
        .month = 11,
        .day = 2,
        .hour = 15,
        .minute = 15,
        .timezone = "pdt",
        .moon_nakshatra = "shatabhisha",
        .asc_sign = "pisc",
        .asc_degrees = 0,
        .sun_house = 9,
        .author = "kae3g",
    };
    
    const result = try format_branch(allocator, branch);
    defer allocator.free(result);
    
    const expected =
        "12025-11-02--1515--pdt--moon-shatabhisha--asc-pisc00--sun-09h--kae3g";
    try testing.expectEqualStrings(expected, result);
}

test "month names" {
    const testing = std.testing;
    
    try testing.expectEqualStrings("jan", month_name(1));
    try testing.expectEqualStrings("nov", month_name(11));
    try testing.expectEqualStrings("dec", month_name(12));
}

