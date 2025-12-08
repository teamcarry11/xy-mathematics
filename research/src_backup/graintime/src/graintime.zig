//! graintime: temporal awareness for grain network
//!
//! What is graintime? It's how we mark moments in our journey.
//!
//! Every grainbranch gets a timestamp that captures not just
//! clock time, but astronomical context: moon nakshatra,
//! ascendant position, sun house. This connects our work to
//! larger cycles beyond the machine.

const std = @import("std");

// hey, what's "std", short for "standard"? great question!
//
// The Zig standard library gives us tools we need without
// any hidden magic. Everything is explicit and clear.
// Does this make sense?

// Re-export our modules for external use.
//
// Why re-export? This pattern creates a clean public API.
// Users import "graintime" and get everything they need,
// but internally we keep concerns separated into modules.
pub const types = @import("types.zig");
pub const format = @import("format.zig");

// Re-export commonly used types for convenience.
pub const GrainBranch = types.GrainBranch;
pub const format_branch = format.format_branch;
pub const month_name = format.month_name;

// Constants for quick reference.
pub const nakshatras = types.nakshatras;
pub const zodiac_signs = types.zodiac_signs;

test "graintime module" {
    const testing = std.testing;
    _ = testing;
    
    // This test just ensures all modules compile and link.
    // Individual functionality is tested in their respective
    // module files.
}

