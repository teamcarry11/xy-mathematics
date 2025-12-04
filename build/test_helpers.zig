//! Test helper functions for build configuration.
//!
//! Why: Reduce repetition in test configuration by extracting common patterns.
//! Architecture: Helper functions for creating and running tests.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-104301-pst: Grain OS Agent

const std = @import("std");
const Build = std.Build;
const helpers = @import("helpers.zig");

// Add a test and add it to test step.
pub fn add_test_to_step(
    ctx: helpers.BuildContext,
    test_step: *Build.Step,
    root_source_file: []const u8,
    imports: []const Build.Module.Import,
) void {
    std.debug.assert(root_source_file.len > 0);
    
    const test_compile = helpers.add_test(ctx, root_source_file, imports);
    const run = ctx.b.addRunArtifact(test_compile);
    test_step.dependOn(&run.step);
}

// Add a simple test (no imports) to test step.
pub fn add_simple_test_to_step(
    ctx: helpers.BuildContext,
    test_step: *Build.Step,
    root_source_file: []const u8,
) void {
    add_test_to_step(ctx, test_step, root_source_file, &.{});
}

