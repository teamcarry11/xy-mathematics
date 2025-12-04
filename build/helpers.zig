//! Build helper functions for common patterns.
//!
//! Why: Reduce repetition in build configuration by extracting common patterns.
//! Architecture: Helper functions for creating modules, executables, and tests.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-104301-pst: Grain OS Agent

const std = @import("std");
const Build = std.Build;

// Build context with common options.
pub const BuildContext = struct {
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

// Initialize build context from standard options.
pub fn init_build_context(b: *Build) BuildContext {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    return BuildContext{
        .b = b,
        .target = target,
        .optimize = optimize,
    };
}

// Create a module with standard options.
pub fn add_module(
    ctx: BuildContext,
    name: []const u8,
    root_source_file: []const u8,
    imports: []const Build.Module.Import,
) *Build.Module {
    std.debug.assert(name.len > 0);
    std.debug.assert(root_source_file.len > 0);
    
    return ctx.b.addModule(name, .{
        .root_source_file = ctx.b.path(root_source_file),
        .target = ctx.target,
        .optimize = ctx.optimize,
        .imports = imports,
    });
}

// Create a simple module (no imports).
pub fn add_simple_module(
    ctx: BuildContext,
    name: []const u8,
    root_source_file: []const u8,
) *Build.Module {
    return add_module(ctx, name, root_source_file, &.{});
}

// Create an executable with standard options.
pub fn add_executable(
    ctx: BuildContext,
    name: []const u8,
    root_source_file: []const u8,
    imports: []const Build.Module.Import,
) *Build.Step.Compile {
    std.debug.assert(name.len > 0);
    std.debug.assert(root_source_file.len > 0);
    
    return ctx.b.addExecutable(.{
        .name = name,
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path(root_source_file),
            .target = ctx.target,
            .optimize = ctx.optimize,
            .imports = imports,
        }),
    });
}

// Create a test with standard options.
pub fn add_test(
    ctx: BuildContext,
    root_source_file: []const u8,
    imports: []const Build.Module.Import,
) *Build.Step.Compile {
    std.debug.assert(root_source_file.len > 0);
    
    return ctx.b.addTest(.{
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path(root_source_file),
            .target = ctx.target,
            .optimize = ctx.optimize,
            .imports = imports,
        }),
    });
}

// Create a userspace executable (RISC-V64 target).
pub fn add_userspace_executable(
    ctx: BuildContext,
    name: []const u8,
    root_source_file: []const u8,
    userspace_stdlib: *Build.Module,
    userspace_args: ?*Build.Module,
    imports: []const Build.Module.Import,
) *Build.Step.Compile {
    std.debug.assert(name.len > 0);
    std.debug.assert(root_source_file.len > 0);
    
    const userspace_target = std.Target.Query{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    };
    const userspace_resolved = ctx.b.resolveTargetQuery(userspace_target);
    
    var all_imports = std.ArrayList(Build.Module.Import).init(ctx.b.allocator);
    defer all_imports.deinit();
    
    all_imports.append(.{ .name = "userspace_stdlib", .module = userspace_stdlib }) catch unreachable;
    if (userspace_args) |args_mod| {
        all_imports.append(.{ .name = "userspace_args", .module = args_mod }) catch unreachable;
    }
    for (imports) |imp| {
        all_imports.append(imp) catch unreachable;
    }
    
    const exe = ctx.b.addExecutable(.{
        .name = name,
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path(root_source_file),
            .target = userspace_resolved,
            .optimize = ctx.optimize,
            .imports = all_imports.items,
        }),
    });
    
    exe.setLinkerScript(ctx.b.path("linker_scripts/userspace.ld"));
    return exe;
}

// Create a build step with install artifact.
pub fn add_build_step(
    b: *Build,
    name: []const u8,
    description: []const u8,
    exe: *Build.Step.Compile,
) *Build.Step {
    std.debug.assert(name.len > 0);
    std.debug.assert(description.len > 0);
    
    const install = b.addInstallArtifact(exe, .{});
    const step = b.step(name, description);
    step.dependOn(&install.step);
    return step;
}

// Create a run step with executable.
pub fn add_run_step(
    b: *Build,
    name: []const u8,
    description: []const u8,
    exe: *Build.Step.Compile,
) *Build.Step {
    std.debug.assert(name.len > 0);
    std.debug.assert(description.len > 0);
    
    const install = b.addInstallArtifact(exe, .{});
    const run = b.addRunArtifact(exe);
    const step = b.step(name, description);
    step.dependOn(&run.step);
    run.step.dependOn(&install.step);
    
    if (b.args) |args| {
        run.addArgs(args);
    }
    
    return step;
}

