//! cli: command line interface for grainwrap
//!
//! How do users interact with grainwrap? This module provides
//! a simple CLI for validating and wrapping zig code.

const std = @import("std");
const grainwrap = @import("grainwrap");

// TODO: Implement CLI interface
// This will handle:
// - `grainwrap validate <file>` - check for violations
// - `grainwrap wrap <file>` - wrap code to fit constraints
// - `grainwrap check <dir>` - validate all files in directory

pub fn main() !void {
    const stdout = std.io.stdOut().writer();

    try stdout.print(
        \\grainwrap - precise code wrapping for grain network
        \\
        \\Usage:
        \\  grainwrap validate <file>
        \\  grainwrap wrap <file> [--output <file>]
        \\  grainwrap check <directory>
        \\
        \\Commands:
        \\  validate    Check code for line length violations
        \\  wrap        Wrap code to fit 73-char limit
        \\  check       Validate all files in directory
        \\
        \\Options:
        \\  --output    Output file for wrap command
        \\  --help      Show this help
        \\
        \\Examples:
        \\  grainwrap validate src/main.zig
        \\  grainwrap wrap src/main.zig --output src/main.wrapped.zig
        \\  grainwrap check src/
        \\
        \\
    , .{});

    // TODO: Parse arguments and implement commands
}

