//! Test organization and helper functions.
//!
//! Why: Centralize test configuration patterns and reduce repetition.
//! Architecture: Helper functions for adding tests with common patterns.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-135819-pst: Grain OS Agent

const std = @import("std");
const Build = std.Build;
const helpers = @import("helpers.zig");

// Add a test with standard configuration.
pub fn add_test(
    ctx: helpers.BuildContext,
    test_step: *Build.Step,
    source_file: []const u8,
    imports: []const Build.Module.Import,
) void {
    std.debug.assert(source_file.len > 0);
    
    const test_exe = ctx.b.addTest(.{
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path(source_file),
            .target = ctx.target,
            .optimize = ctx.optimize,
            .imports = imports,
        }),
    });
    
    const test_run = ctx.b.addRunArtifact(test_exe);
    test_step.dependOn(&test_run.step);
}

// Add a test with a specific name (for named test steps).
pub fn add_named_test(
    ctx: helpers.BuildContext,
    test_step: *Build.Step,
    name: []const u8,
    source_file: []const u8,
    imports: []const Build.Module.Import,
) void {
    std.debug.assert(name.len > 0);
    std.debug.assert(source_file.len > 0);
    
    const test_exe = ctx.b.addTest(.{
        .name = name,
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path(source_file),
            .target = ctx.target,
            .optimize = ctx.optimize,
            .imports = imports,
        }),
    });
    
    const test_run = ctx.b.addRunArtifact(test_exe);
    test_step.dependOn(&test_run.step);
}

// Add a test with install step (for tests that need artifacts).
pub fn add_test_with_install(
    ctx: helpers.BuildContext,
    test_step: *Build.Step,
    source_file: []const u8,
    imports: []const Build.Module.Import,
) void {
    std.debug.assert(source_file.len > 0);
    
    const test_exe = ctx.b.addTest(.{
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path(source_file),
            .target = ctx.target,
            .optimize = ctx.optimize,
            .imports = imports,
        }),
    });
    
    const install = ctx.b.addInstallArtifact(test_exe, .{});
    const test_run = ctx.b.addRunArtifact(test_exe);
    test_step.dependOn(&test_run.step);
    test_step.dependOn(&install.step);
}

