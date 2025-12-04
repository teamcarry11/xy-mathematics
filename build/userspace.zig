//! Userspace utilities build configuration.
//!
//! Why: Centralize userspace utility executables and modules.
//! Architecture: Userspace stdlib, args, and utility executables.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-133313-pst: Grain OS Agent

const std = @import("std");
const Build = std.Build;
const helpers = @import("helpers.zig");

// Userspace modules structure.
pub const UserspaceModules = struct {
    userspace_stdlib: *Build.Module,
    userspace_args: *Build.Module,
};

// Create userspace modules.
pub fn create_userspace_modules(
    ctx: helpers.BuildContext,
) UserspaceModules {
    const userspace_stdlib_mod = helpers.add_simple_module(
        ctx,
        "userspace_stdlib",
        "src/userspace/stdlib.zig",
    );
    const userspace_args_mod = helpers.add_simple_module(
        ctx,
        "userspace_args",
        "src/userspace/args.zig",
    );
    
    return UserspaceModules{
        .userspace_stdlib = userspace_stdlib_mod,
        .userspace_args = userspace_args_mod,
    };
}

// Get userspace target (RISC-V64).
pub fn get_userspace_target(
    b: *Build,
) std.Build.ResolvedTarget {
    const userspace_target = std.Target.Query{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    };
    return b.resolveTargetQuery(userspace_target);
}

// Create userspace executable helper.
pub fn create_userspace_executable(
    ctx: helpers.BuildContext,
    name: []const u8,
    source: []const u8,
    userspace_modules: UserspaceModules,
    userspace_target: std.Build.ResolvedTarget,
    imports: []const Build.Module.Import,
) *Build.Step.Compile {
    var all_imports = std.ArrayList(Build.Module.Import).init(ctx.b.allocator);
    defer all_imports.deinit();
    
    all_imports.append(.{
        .name = "userspace_stdlib",
        .module = userspace_modules.userspace_stdlib,
    }) catch unreachable;
    all_imports.append(.{
        .name = "userspace_args",
        .module = userspace_modules.userspace_args,
    }) catch unreachable;
    for (imports) |imp| {
        all_imports.append(imp) catch unreachable;
    }
    
    const exe = ctx.b.addExecutable(.{
        .name = name,
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path(source),
            .target = userspace_target,
            .optimize = ctx.optimize,
            .imports = all_imports.items,
        }),
    });
    exe.setLinkerScript(ctx.b.path("linker_scripts/userspace.ld"));
    
    return exe;
}

// Add userspace utility build step.
pub fn add_userspace_utility_step(
    b: *Build,
    name: []const u8,
    description: []const u8,
    exe: *Build.Step.Compile,
) void {
    helpers.add_build_step(b, name, description, exe);
}

// Create all userspace utilities.
pub fn create_all_userspace_utilities(
    ctx: helpers.BuildContext,
    userspace_modules: UserspaceModules,
    userspace_target: std.Build.ResolvedTarget,
) struct {
    riscv_logo: *Build.Step.Compile,
    cat: *Build.Step.Compile,
    echo: *Build.Step.Compile,
    ls: *Build.Step.Compile,
    mkdir: *Build.Step.Compile,
    rm: *Build.Step.Compile,
    cp: *Build.Step.Compile,
    mv: *Build.Step.Compile,
    grep: *Build.Step.Compile,
    sed: *Build.Step.Compile,
    awk: *Build.Step.Compile,
    cc: *Build.Step.Compile,
    ld: *Build.Step.Compile,
    ar: *Build.Step.Compile,
    make: *Build.Step.Compile,
} {
    const riscv_logo_exe = create_userspace_executable(
        ctx,
        "riscv_logo",
        "examples/riscv_logo.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const cat_exe = create_userspace_executable(
        ctx,
        "cat",
        "src/userspace/utils/core/cat.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const echo_exe = create_userspace_executable(
        ctx,
        "echo",
        "src/userspace/utils/core/echo.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const ls_exe = create_userspace_executable(
        ctx,
        "ls",
        "src/userspace/utils/core/ls.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const mkdir_exe = create_userspace_executable(
        ctx,
        "mkdir",
        "src/userspace/utils/core/mkdir.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const rm_exe = create_userspace_executable(
        ctx,
        "rm",
        "src/userspace/utils/core/rm.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const cp_exe = create_userspace_executable(
        ctx,
        "cp",
        "src/userspace/utils/core/cp.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const mv_exe = create_userspace_executable(
        ctx,
        "mv",
        "src/userspace/utils/core/mv.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const grep_exe = create_userspace_executable(
        ctx,
        "grep",
        "src/userspace/utils/text/grep.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const sed_exe = create_userspace_executable(
        ctx,
        "sed",
        "src/userspace/utils/text/sed.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const awk_exe = create_userspace_executable(
        ctx,
        "awk",
        "src/userspace/utils/text/awk.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const cc_exe = create_userspace_executable(
        ctx,
        "cc",
        "src/userspace/build-tools/cc.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const ld_exe = create_userspace_executable(
        ctx,
        "ld",
        "src/userspace/build-tools/ld.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const ar_exe = create_userspace_executable(
        ctx,
        "ar",
        "src/userspace/build-tools/ar.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    const make_exe = create_userspace_executable(
        ctx,
        "make",
        "src/userspace/build-tools/make.zig",
        userspace_modules,
        userspace_target,
        &.{},
    );
    
    return .{
        .riscv_logo = riscv_logo_exe,
        .cat = cat_exe,
        .echo = echo_exe,
        .ls = ls_exe,
        .mkdir = mkdir_exe,
        .rm = rm_exe,
        .cp = cp_exe,
        .mv = mv_exe,
        .grep = grep_exe,
        .sed = sed_exe,
        .awk = awk_exe,
        .cc = cc_exe,
        .ld = ld_exe,
        .ar = ar_exe,
        .make = make_exe,
    };
}

// Add build-essential step (all utilities).
pub fn add_build_essential_step(
    b: *Build,
    utilities: struct {
        cat: *Build.Step.Compile,
        echo: *Build.Step.Compile,
        ls: *Build.Step.Compile,
        mkdir: *Build.Step.Compile,
        rm: *Build.Step.Compile,
        cp: *Build.Step.Compile,
        mv: *Build.Step.Compile,
        grep: *Build.Step.Compile,
        sed: *Build.Step.Compile,
        awk: *Build.Step.Compile,
        cc: *Build.Step.Compile,
        ld: *Build.Step.Compile,
        ar: *Build.Step.Compile,
        make: *Build.Step.Compile,
    },
) void {
    const step = b.step("build-essential", "Build all build-essential utilities");
    step.dependOn(&b.addInstallArtifact(utilities.cat, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.echo, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.ls, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.mkdir, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.rm, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.cp, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.mv, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.grep, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.sed, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.awk, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.cc, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.ld, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.ar, .{}).step);
    step.dependOn(&b.addInstallArtifact(utilities.make, .{}).step);
}

