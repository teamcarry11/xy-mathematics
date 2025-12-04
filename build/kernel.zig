//! Kernel and VM build configuration.
//!
//! Why: Centralize kernel and VM module definitions and executables.
//! Architecture: Kernel modules, VM modules, kernel executables, VM tests.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-04-104301-pst: Grain OS Agent

const std = @import("std");
const Build = std.Build;
const helpers = @import("helpers.zig");

// Kernel and VM modules structure.
pub const KernelModules = struct {
    elf_parser: *Build.Module,
    basin_kernel: *Build.Module,
    sbi: *Build.Module,
    kernel_vm: *Build.Module,
};

// Create kernel and VM modules.
pub fn create_kernel_modules(
    ctx: helpers.BuildContext,
) KernelModules {
    const elf_parser_mod = helpers.add_simple_module(
        ctx,
        "elf_parser",
        "src/kernel/elf_parser.zig",
    );
    const basin_kernel_mod = helpers.add_simple_module(
        ctx,
        "basin_kernel",
        "src/kernel/basin_kernel.zig",
    );
    const sbi_mod = helpers.add_simple_module(
        ctx,
        "sbi",
        "src/kernel_vm/sbi.zig",
    );
    const kernel_vm_mod = helpers.add_module(
        ctx,
        "kernel_vm",
        "src/kernel_vm/kernel_vm.zig",
        &.{
            .{ .name = "sbi", .module = sbi_mod },
            .{ .name = "basin_kernel", .module = basin_kernel_mod },
        },
    );
    
    return KernelModules{
        .elf_parser = elf_parser_mod,
        .basin_kernel = basin_kernel_mod,
        .sbi = sbi_mod,
        .kernel_vm = kernel_vm_mod,
    };
}

// Create kernel executable (RISC-V64).
pub fn create_kernel_executable(
    ctx: helpers.BuildContext,
    _kernel_modules: KernelModules,
) *Build.Step.Compile {
    _ = _kernel_modules;
    const kernel_target = std.Target.Query{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    };
    const kernel_resolved = ctx.b.resolveTargetQuery(kernel_target);
    
    const kernel_exe = ctx.b.addExecutable(.{
        .name = "grain-rv64",
        .root_module = ctx.b.createModule(.{
            .root_source_file = ctx.b.path("src/kernel/main.zig"),
            .target = kernel_resolved,
            .optimize = ctx.optimize,
            .code_model = .medium,
        }),
    });
    kernel_exe.setLinkerScript(ctx.b.path("src/kernel/linker.ld"));
    kernel_exe.addAssemblyFile(ctx.b.path("src/kernel/entry.S"));
    
    return kernel_exe;
}

// Create kernel build step.
pub fn add_kernel_build_step(
    b: *Build,
    kernel_exe: *Build.Step.Compile,
) void {
    helpers.add_build_step(
        b,
        "kernel-rv64",
        "Build Grain RISC-V kernel image",
        kernel_exe,
    );
}

// Create kernel VM test executable.
pub fn create_kernel_vm_test_executable(
    ctx: helpers.BuildContext,
    kernel_modules: KernelModules,
) *Build.Step.Compile {
    return helpers.add_executable(
        ctx,
        "kernel_vm_test",
        "src/kernel_vm/test.zig",
        &.{
            .{ .name = "kernel_vm", .module = kernel_modules.kernel_vm },
            .{ .name = "basin_kernel", .module = kernel_modules.basin_kernel },
        },
    );
}

// Create kernel VM test step.
pub fn add_kernel_vm_test_step(
    b: *Build,
    kernel_vm_test_exe: *Build.Step.Compile,
) void {
    const install = b.addInstallArtifact(kernel_vm_test_exe, .{});
    const step = b.step("kernel-vm-test", "Test RISC-V VM functionality");
    step.dependOn(&install.step);
    const run = b.addRunArtifact(kernel_vm_test_exe);
    step.dependOn(&run.step);
}

// Create JIT benchmark executable.
pub fn create_benchmark_jit_executable(
    ctx: helpers.BuildContext,
    kernel_modules: KernelModules,
) *Build.Step.Compile {
    return helpers.add_executable(
        ctx,
        "benchmark_jit",
        "src/kernel_vm/benchmark_jit.zig",
        &.{
            .{ .name = "kernel_vm", .module = kernel_modules.kernel_vm },
            .{ .name = "basin_kernel", .module = kernel_modules.basin_kernel },
        },
    );
}

// Create JIT benchmark step.
pub fn add_benchmark_jit_step(
    b: *Build,
    benchmark_jit_exe: *Build.Step.Compile,
) void {
    helpers.add_run_step(
        b,
        "benchmark-jit",
        "Run JIT vs Interpreter benchmark",
        benchmark_jit_exe,
    );
}

