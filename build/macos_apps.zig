//! macOS application executables build configuration.
//!
//! Why: Centralize macOS app definitions (tahoe, grain_skate) with framework linking.
//! Architecture: macOS executables with Cocoa framework linking.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-104301-pst: Grain OS Agent

const std = @import("std");
const Build = std.Build;
const helpers = @import("helpers.zig");
const kernel = @import("kernel.zig");

// Create tahoe macOS executable with frameworks.
pub fn create_tahoe_executable(
    ctx: helpers.BuildContext,
    kernel_modules: kernel.KernelModules,
) *Build.Step.Compile {
    std.debug.print("[build] Creating tahoe executable...\n", .{});
    
    const exe = ctx.b.addExecutable(.{
        .name = "tahoe",
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path("src/tahoe_app.zig"),
            .target = ctx.target,
            .optimize = ctx.optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_modules.kernel_vm },
                .{ .name = "basin_kernel", .module = kernel_modules.basin_kernel },
                .{ .name = "sbi", .module = kernel_modules.sbi },
            },
        }),
    });
    
    std.debug.print("[build] Adding C wrapper source: src/platform/macos_tahoe/objc_wrapper.c\n", .{});
    exe.addCSourceFiles(.{
        .files = &.{"src/platform/macos_tahoe/objc_wrapper.c"},
        .flags = &.{},
    });
    
    std.debug.print("[build] Linking macOS frameworks: AppKit, Foundation, CoreGraphics, QuartzCore\n", .{});
    exe.linkFramework("AppKit");
    exe.linkFramework("Foundation");
    exe.linkFramework("CoreGraphics");
    exe.linkFramework("QuartzCore");
    
    std.debug.print("[build] Installing tahoe artifact...\n", .{});
    ctx.b.installArtifact(exe);
    
    return exe;
}

// Create tahoe build and run steps.
pub fn add_tahoe_steps(
    b: *Build,
    tahoe_exe: *Build.Step.Compile,
) void {
    std.debug.print("[build] Creating tahoe build and run steps...\n", .{});
    
    const build_step = b.step("tahoe-build", "Build the macOS Tahoe Aurora GUI (without running)");
    build_step.dependOn(b.getInstallStep());
    
    const run_step = b.step("tahoe", "Build and run the macOS Tahoe Aurora GUI");
    const run = b.addRunArtifact(tahoe_exe);
    run_step.dependOn(&run.step);
    
    std.debug.print("[build] Tahoe build configuration complete.\n", .{});
    std.debug.print("[build] Use 'zig build tahoe-build' to compile without running.\n", .{});
    std.debug.print("[build] Use 'zig build tahoe' to compile and run (will block until app quits).\n", .{});
}

// Create grain_skate macOS executable with frameworks.
pub fn create_grain_skate_executable(
    ctx: helpers.BuildContext,
    grain_skate_module: *Build.Module,
    events_module: *Build.Module,
) *Build.Step.Compile {
    std.debug.print("[build] Creating grain_skate executable...\n", .{});
    
    const exe = ctx.b.addExecutable(.{
        .name = "grain_skate",
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path("src/grain_skate_main.zig"),
            .target = ctx.target,
            .optimize = ctx.optimize,
            .imports = &.{
                .{ .name = "grain_skate", .module = grain_skate_module },
                .{ .name = "events", .module = events_module },
            },
        }),
    });
    
    std.debug.print("[build] Adding C wrapper source: src/platform/macos_tahoe/objc_wrapper.c\n", .{});
    exe.addCSourceFiles(.{
        .files = &.{"src/platform/macos_tahoe/objc_wrapper.c"},
        .flags = &.{},
    });
    
    std.debug.print("[build] Linking macOS frameworks: AppKit, Foundation, CoreGraphics, QuartzCore\n", .{});
    exe.linkFramework("AppKit");
    exe.linkFramework("Foundation");
    exe.linkFramework("CoreGraphics");
    exe.linkFramework("QuartzCore");
    
    std.debug.print("[build] Installing grain_skate artifact...\n", .{});
    ctx.b.installArtifact(exe);
    
    return exe;
}

// Create grain_skate build and run steps.
pub fn add_grain_skate_steps(
    b: *Build,
    grain_skate_exe: *Build.Step.Compile,
) void {
    std.debug.print("[build] Creating grain_skate build and run steps...\n", .{});
    
    const build_step = b.step("grain-skate-build", "Build the macOS Grain Skate application (without running)");
    build_step.dependOn(b.getInstallStep());
    
    const run_step = b.step("grain-skate", "Build and run the macOS Grain Skate application");
    const run = b.addRunArtifact(grain_skate_exe);
    run_step.dependOn(&run.step);
}

