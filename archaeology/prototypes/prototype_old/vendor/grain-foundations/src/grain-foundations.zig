//! grain-foundations: core types and utilities for grain network
//!
//! This module provides the foundational building blocks used
//! across all grain network tools: workspace structure, developer
//! identity, and path conventions.

const std = @import("std");

// hey, what's "std", short for "standard"? great question!
//
// The Zig standard library gives us tools we need without
// any hidden magic. Everything is explicit and clear.
// Does this make sense?

// Re-export our modules for external use.
//
// Why re-export? This pattern creates a clean public API.
// Users import "grain-foundations" and get everything they need,
// but internally we keep concerns separated into modules.
pub const graindevname = @import("graindevname.zig");
pub const grainspace = @import("grainspace.zig");

// Re-export commonly used types for convenience.
pub const GrainDevName = graindevname.GrainDevName;
pub const GrainSpace = grainspace.GrainSpace;

test "grain-foundations module" {
    const testing = std.testing;
    _ = testing;
    
    // This test just ensures all modules compile and link.
    // Individual functionality is tested in their respective
    // module files.
}

