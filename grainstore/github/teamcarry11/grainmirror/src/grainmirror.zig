//! grainmirror: external repository mirroring tool
//!
//! This tool reads grainstore-manifest and clones/updates
//! external repositories into your grainstore without
//! committing them to git.

const std = @import("std");

// hey, what's "std", short for "standard"? great question!
//
// The Zig standard library gives us tools we need without
// any hidden magic. Everything is explicit and clear.
// Does this make sense?

// Re-export our modules for external use.
pub const sync = @import("sync.zig");

// Re-export functions for convenience.
pub const sync_repo = sync.sync_repo;

test "grainmirror module" {
    const testing = std.testing;
    _ = testing;
    
    // This test just ensures all modules compile and link.
}
