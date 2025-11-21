//! cli: command line interface for graintime
//!
//! This tool helps you create grainbranch names interactively
//! or from command line arguments.

const std = @import("std");
const graintime = @import("graintime.zig");

// Command line options for graintime generation.
//
// We use full word names internally for clarity, but support
// short options on the command line for convenience.
const Options = struct {
    interactive: bool = false, // -i or --interactive
    year: ?u16 = null, // -y or --year
    month: ?u8 = null, // -m or --month
    day: ?u8 = null, // -d or --day
    hour: ?u8 = null, // -h or --hour
    minute: ?u8 = null, // --minute (no short form)
    timezone: ?[]const u8 = null, // -t or --timezone
    moon_nakshatra: ?[]const u8 = null, // -n or --nakshatra
    asc_sign: ?[]const u8 = null, // -s or --sign
    asc_degrees: ?u8 = null, // --degrees (no short form)
    sun_house: ?u8 = null, // --house (no short form)
    author: ?[]const u8 = null, // -a or --author
};

// Parse command line arguments into options.
//
// Supports both short flags (-i) and long flags (--interactive).
// Returns null if help was requested or parsing failed.
fn parse_args(
    allocator: std.mem.Allocator,
) !?Options {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    
    var opts = Options{};
    
    // Skip program name
    _ = args.skip();
    
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-i") or
            std.mem.eql(u8, arg, "--interactive"))
        {
            opts.interactive = true;
        } else if (std.mem.eql(u8, arg, "-a") or
            std.mem.eql(u8, arg, "--author"))
        {
            opts.author = args.next();
        } else if (std.mem.eql(u8, arg, "--help") or
            std.mem.eql(u8, arg, "-h"))
        {
            try print_usage();
            return null;
        }
        // TODO: Add parsing for all other options
    }
    
    return opts;
}

// Print usage information.
fn print_usage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\graintime - temporal awareness for grain network
        \\
        \\Usage:
        \\  graintime [options]
        \\  graintime --interactive
        \\
        \\Options:
        \\  -i, --interactive    Interactive mode (prompts for values)
        \\  -a, --author NAME    Author name (default: current user)
        \\  -y, --year YEAR      Year in holocene calendar
        \\  -m, --month MONTH    Month (1-12)
        \\  -d, --day DAY        Day of month (1-31)
        \\      --hour HOUR      Hour (0-23)
        \\      --minute MIN     Minute (0-59)
        \\  -t, --timezone TZ    Timezone (pdt, utc, etc.)
        \\  -n, --nakshatra NAME Moon nakshatra
        \\  -s, --sign SIGN      Ascendant sign (4 chars)
        \\      --degrees DEG    Ascendant degrees (0-29)
        \\      --house HOUSE    Sun house (1-12)
        \\      --help           Show this help
        \\
        \\Examples:
        \\  graintime --interactive
        \\  graintime -a kae3g -y 12025 -m 11 -d 2 --hour 15 --minute 15
        \\
        \\
    , .{});
}

// Run interactive mode, prompting for each value.
fn run_interactive(
    allocator: std.mem.Allocator,
) !graintime.GrainBranch {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    
    var buf: [256]u8 = undefined;
    
    try stdout.print("Welcome to graintime! Let's create a grainbranch.\n\n", .{});
    
    // Year
    try stdout.print("Year (holocene calendar, e.g. 12025): ", .{});
    const year_line = try stdin.readUntilDelimiterOrEof(&buf, '\n');
    const year = try std.fmt.parseInt(u16, std.mem.trim(u8, year_line.?, &std.ascii.whitespace), 10);
    
    // Month
    try stdout.print("Month (1-12): ", .{});
    const month_line = try stdin.readUntilDelimiterOrEof(&buf, '\n');
    const month = try std.fmt.parseInt(u8, std.mem.trim(u8, month_line.?, &std.ascii.whitespace), 10);
    
    // TODO: Prompt for all other fields
    
    return graintime.GrainBranch{
        .year = year,
        .month = month,
        .day = 2, // TODO: prompt
        .hour = 15, // TODO: prompt
        .minute = 15, // TODO: prompt
        .timezone = "pdt", // TODO: prompt
        .moon_nakshatra = "shatabhisha", // TODO: prompt
        .asc_sign = "pisc", // TODO: prompt
        .asc_degrees = 0, // TODO: prompt
        .sun_house = 9, // TODO: prompt
        .author = "kae3g", // TODO: prompt
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const opts = try parse_args(allocator) orelse return;
    
    const branch = if (opts.interactive)
        try run_interactive(allocator)
    else
        // TODO: Build from command line options
        graintime.GrainBranch{
            .year = opts.year orelse 12025,
            .month = opts.month orelse 11,
            .day = opts.day orelse 2,
            .hour = opts.hour orelse 15,
            .minute = opts.minute orelse 15,
            .timezone = opts.timezone orelse "pdt",
            .moon_nakshatra = opts.moon_nakshatra orelse "shatabhisha",
            .asc_sign = opts.asc_sign orelse "pisc",
            .asc_degrees = opts.asc_degrees orelse 0,
            .sun_house = opts.sun_house orelse 9,
            .author = opts.author orelse "kae3g",
        };
    
    const name = try graintime.format_branch(allocator, branch);
    defer allocator.free(name);
    
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{name});
}

