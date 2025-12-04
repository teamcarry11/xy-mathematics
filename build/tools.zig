//! Tools and utility executables build configuration.
//!
//! Why: Centralize tool executable definitions (graincard, wrap_docs, etc.).
//! Architecture: Tool executables with run steps.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-104301-pst: Grain OS Agent

const std = @import("std");
const Build = std.Build;
const helpers = @import("helpers.zig");
const modules = @import("modules.zig");

// Create graincard executable and step.
pub fn add_graincard(
    ctx: helpers.BuildContext,
    shared_modules: modules.SharedModules,
) void {
    const exe = helpers.add_executable(
        ctx,
        "graincard",
        "src/graincard.zig",
        &.{.{ .name = "zigimg", .module = shared_modules.zigimg }},
    );
    ctx.b.installArtifact(exe);
    const run = ctx.b.addRunArtifact(exe);
    const step = ctx.b.step("graincard", "Run the Graincard Generator");
    step.dependOn(&run.step);
    if (ctx.b.args) |args| {
        run.addArgs(args);
    }
}

// Create ray executable and step.
pub fn add_ray(
    ctx: helpers.BuildContext,
    shared_modules: modules.SharedModules,
) void {
    const exe = helpers.add_executable(
        ctx,
        "ray",
        "src/ray_app.zig",
        &.{.{ .name = "ray", .module = shared_modules.ray }},
    );
    ctx.b.installArtifact(exe);
    const run = ctx.b.addRunArtifact(exe);
    const step = ctx.b.step("run", "Run the Ray envelope printer");
    step.dependOn(&run.step);
    run.step.dependOn(ctx.b.getInstallStep());
    if (ctx.b.args) |args| {
        run.addArgs(args);
    }
}

// Create thread_slicer executable and step.
pub fn add_thread_slicer(
    ctx: helpers.BuildContext,
    shared_modules: modules.SharedModules,
) void {
    const exe = helpers.add_executable(
        ctx,
        "thread_slicer",
        "tools/thread_slicer.zig",
        &.{.{ .name = "ray", .module = shared_modules.ray }},
    );
    const step = ctx.b.step("thread", "Regenerate docs/ray_160.md using the Zig slicer");
    const run = ctx.b.addRunArtifact(exe);
    step.dependOn(&run.step);
    run.step.dependOn(ctx.b.getInstallStep());
}

// Create wrap_docs executable and step.
pub fn add_wrap_docs(
    ctx: helpers.BuildContext,
    shared_modules: modules.SharedModules,
) void {
    const exe = helpers.add_executable(
        ctx,
        "wrap_docs",
        "tools/wrap_docs.zig",
        &.{.{ .name = "grainwrap", .module = shared_modules.grainwrap }},
    );
    const step = ctx.b.step("wrap-docs", "Wrap documentation to 73 columns");
    const run = ctx.b.addRunArtifact(exe);
    step.dependOn(&run.step);
}

// Create validate executable and step.
pub fn add_validate(
    ctx: helpers.BuildContext,
    shared_modules: modules.SharedModules,
) void {
    const exe = helpers.add_executable(
        ctx,
        "validate_src",
        "tools/validate_src.zig",
        &.{.{ .name = "grainvalidate", .module = shared_modules.grainvalidate }},
    );
    helpers.add_run_step(
        ctx.b,
        "validate",
        "Validate source files against Grain style",
        exe,
    );
}

// Create conductor executable and step.
pub fn add_conductor(
    ctx: helpers.BuildContext,
) void {
    const exe = helpers.add_executable(
        ctx,
        "conductor",
        "tools/conductor.zig",
        &.{},
    );
    helpers.add_run_step(
        ctx.b,
        "conduct",
        "Run Grain Conductor command suite",
        exe,
    );
}

// Create graindaemon executable and step.
pub fn add_graindaemon(
    ctx: helpers.BuildContext,
) void {
    const exe = helpers.add_executable(
        ctx,
        "graindaemon",
        "tools/graindaemon_cli.zig",
        &.{},
    );
    const step = ctx.b.step("graindaemon", "Run the Graindaemon CLI");
    const run = ctx.b.addRunArtifact(exe);
    step.dependOn(&run.step);
}

// Create aurora_preprocessor executable and step.
pub fn add_aurora_preprocessor(
    ctx: helpers.BuildContext,
) void {
    const exe = helpers.add_executable(
        ctx,
        "aurora_preprocessor",
        "tools/aurora_preprocessor.zig",
        &.{},
    );
    const step = ctx.b.step("aurora-assets", "Run Aurora preprocessor stub");
    const run = ctx.b.addRunArtifact(exe);
    run.addArg("sample.aurora");
    step.dependOn(&run.step);
}

// Create extract_outputs executable and step.
pub fn add_extract_outputs(
    ctx: helpers.BuildContext,
) void {
    const exe = helpers.add_executable(
        ctx,
        "extract_outputs",
        "tools/extract_outputs.zig",
        &.{},
    );
    ctx.b.installArtifact(exe);
    const step = ctx.b.step("extract-outputs", "Count '**Cursor**' markers in export");
    const run = ctx.b.addRunArtifact(exe);
    run.addArg("--help");
    step.dependOn(&run.step);
}

