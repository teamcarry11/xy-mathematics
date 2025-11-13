const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ray_module = b.addModule("ray", .{
        .root_source_file = b.path("src/ray.zig"),
        .target = target,
        .optimize = optimize,
    });

    const grainwrap_module = b.addModule("grainwrap", .{
        .root_source_file = b.path("vendor/grainwrap/src/grainwrap.zig"),
        .target = target,
        .optimize = optimize,
    });

    const grainvalidate_module = b.addModule("grainvalidate", .{
        .root_source_file = b.path("vendor/grainvalidate/src/grainvalidate.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ray",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ray_app.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ray", .module = ray_module },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the Ray envelope printer");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const slicer = b.addExecutable(.{
        .name = "thread_slicer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/thread_slicer.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ray", .module = ray_module },
            },
        }),
    });

    const thread_step = b.step("thread", "Regenerate docs/ray_160.md using the Zig slicer");
    const run_slicer = b.addRunArtifact(slicer);
    thread_step.dependOn(&run_slicer.step);
    run_slicer.step.dependOn(b.getInstallStep());

    const wrap_docs_exe = b.addExecutable(.{
        .name = "wrap_docs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/wrap_docs.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grainwrap", .module = grainwrap_module },
            },
        }),
    });
    const wrap_docs_step = b.step("wrap-docs", "Wrap documentation to 73 columns");
    const run_wrap_docs = b.addRunArtifact(wrap_docs_exe);
    wrap_docs_step.dependOn(&run_wrap_docs.step);

    const kernel_target = std.Target.Query{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    };
    const kernel_resolved = b.resolveTargetQuery(kernel_target);

    const kernel_exe = b.addExecutable(.{
        .name = "grain-rv64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kernel/main.zig"),
            .target = kernel_resolved,
            .optimize = optimize,
        }),
    });
    const kernel_install = b.addInstallArtifact(kernel_exe, .{});
    const kernel_step = b.step("kernel-rv64", "Build Grain RISC-V kernel image");
    kernel_step.dependOn(&kernel_install.step);

    // Basin Kernel module (syscall interface and kernel structures).
    const basin_kernel_module = b.addModule("basin_kernel", .{
        .root_source_file = b.path("src/kernel/basin_kernel.zig"),
        .target = target,
        .optimize = optimize,
    });

    // RISC-V SBI module (platform runtime services).
    // Why: Our own Tiger Style SBI wrapper (inspired by CascadeOS/zig-sbi, MIT licensed).
    const sbi_module = b.addModule("sbi", .{
        .root_source_file = b.path("src/kernel_vm/sbi.zig"),
        .target = target,
        .optimize = optimize,
    });

    // RISC-V VM module for kernel virtualization.
    const kernel_vm_module = b.addModule("kernel_vm", .{
        .root_source_file = b.path("src/kernel_vm/kernel_vm.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sbi", .module = sbi_module },
        },
    });

    // Kernel VM test executable (for testing VM functionality).
    const kernel_vm_test_exe = b.addExecutable(.{
        .name = "kernel_vm_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kernel_vm/test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const kernel_vm_test_install = b.addInstallArtifact(kernel_vm_test_exe, .{});
    const kernel_vm_test_step = b.step("kernel-vm-test", "Test RISC-V VM functionality");
    kernel_vm_test_step.dependOn(&kernel_vm_test_install.step);
    const kernel_vm_test_run = b.addRunArtifact(kernel_vm_test_exe);
    kernel_vm_test_step.dependOn(&kernel_vm_test_run.step);

    const validate_src_exe = b.addExecutable(.{
        .name = "validate_src",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/validate_src.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grainvalidate", .module = grainvalidate_module },
            },
        }),
    });
    const validate_step = b.step("validate", "Validate source files against Grain style");
    const run_validate = b.addRunArtifact(validate_src_exe);
    validate_step.dependOn(&run_validate.step);

    const conductor_exe = b.addExecutable(.{
        .name = "grain_conductor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/grain_conductor.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const conduct_step = b.step("conduct", "Run Grain Conductor command suite");
    const run_conductor = b.addRunArtifact(conductor_exe);
    conduct_step.dependOn(&run_conductor.step);

    const ray_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ray.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const nostr_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/nostr.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const contracts_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/contracts.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const mmt_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/nostr_mmt.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const cdn_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tigerbank_cdn.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const lattice_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/grain_lattice.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const prompts_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/unit/prompts_desc_order.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const dm_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/dm.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const loop_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/grain_loop.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const daemon_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/graindaemon.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const buffer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/grain_buffer.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const loom_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/grain_loom.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const aurora_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/grain_aurora.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const text_renderer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/aurora_text_renderer.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const lsp_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/aurora_lsp.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const editor_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/aurora_editor.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const route_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/grain_route.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const orchestrator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/grain_orchestrator.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const riscv_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/riscv_sys.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const outputs_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/unit/outputs_desc_order.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const graindaemon_cli = b.addExecutable(.{
        .name = "graindaemon",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/graindaemon_cli.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const graindaemon_step = b.step("graindaemon", "Run the Graindaemon CLI");
    const run_graindaemon = b.addRunArtifact(graindaemon_cli);
    graindaemon_step.dependOn(&run_graindaemon.step);

    const aurora_preprocessor = b.addExecutable(.{
        .name = "aurora_preprocessor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/aurora_preprocessor.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const aurora_assets_step = b.step("aurora-assets", "Run Aurora preprocessor stub");
    const run_aurora = b.addRunArtifact(aurora_preprocessor);
    run_aurora.addArg("sample.aurora");
    aurora_assets_step.dependOn(&run_aurora.step);

    const extract_outputs = b.addExecutable(.{
        .name = "extract_outputs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/extract_outputs.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(extract_outputs);
    const extract_step = b.step("extract-outputs", "Count '**Cursor**' markers in export");
    const run_extract = b.addRunArtifact(extract_outputs);
    run_extract.addArg("--help");
    extract_step.dependOn(&run_extract.step);

    // Tiger Style: Print build progress for visibility.
    std.debug.print("[build] Creating tahoe executable...\n", .{});
    
    const tahoe_app = b.addExecutable(.{
        .name = "tahoe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tahoe_app.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
                .{ .name = "sbi", .module = sbi_module },
            },
            // Tiger Style: Zig is strict by default - all safety checks enabled.
            // No need for additional flags - Zig catches all errors at compile time.
        }),
    });
    
    std.debug.print("[build] Adding C wrapper source: src/platform/macos_tahoe/objc_wrapper.c\n", .{});
    // Add C wrapper for objc_msgSend to handle calling convention properly.
    tahoe_app.addCSourceFiles(.{
        .files = &.{"src/platform/macos_tahoe/objc_wrapper.c"},
        .flags = &.{},
    });
    
    std.debug.print("[build] Linking macOS frameworks: AppKit, Foundation, CoreGraphics, QuartzCore\n", .{});
    // Link macOS frameworks: AppKit and Foundation for Cocoa bridge, CoreGraphics for drawing, QuartzCore for CALayer.
    tahoe_app.linkFramework("AppKit");
    tahoe_app.linkFramework("Foundation");
    tahoe_app.linkFramework("CoreGraphics");
    tahoe_app.linkFramework("QuartzCore");
    
    std.debug.print("[build] Installing tahoe artifact...\n", .{});
    b.installArtifact(tahoe_app);
    
    std.debug.print("[build] Creating tahoe build and run steps...\n", .{});
    
    // Separate build step: just compile, don't run.
    const tahoe_build_step = b.step("tahoe-build", "Build the macOS Tahoe Aurora GUI (without running)");
    tahoe_build_step.dependOn(b.getInstallStep());
    
    // Run step: build and then run the app.
    const tahoe_step = b.step("tahoe", "Build and run the macOS Tahoe Aurora GUI");
    const run_tahoe = b.addRunArtifact(tahoe_app);
    tahoe_step.dependOn(&run_tahoe.step);
    run_tahoe.step.dependOn(b.getInstallStep());
    
    std.debug.print("[build] Tahoe build configuration complete.\n", .{});
    std.debug.print("[build] Use 'zig build tahoe-build' to compile without running.\n", .{});
    std.debug.print("[build] Use 'zig build tahoe' to compile and run (will block until app quits).\n", .{});

    const test_step = b.step("test", "Run Ray plan tests");
    const run_ray_tests = b.addRunArtifact(ray_tests);
    test_step.dependOn(&run_ray_tests.step);
    const run_nostr_tests = b.addRunArtifact(nostr_tests);
    test_step.dependOn(&run_nostr_tests.step);
    const run_contract_tests = b.addRunArtifact(contracts_tests);
    test_step.dependOn(&run_contract_tests.step);
    const run_mmt_tests = b.addRunArtifact(mmt_tests);
    test_step.dependOn(&run_mmt_tests.step);
    const run_cdn_tests = b.addRunArtifact(cdn_tests);
    test_step.dependOn(&run_cdn_tests.step);
    const run_lattice_tests = b.addRunArtifact(lattice_tests);
    test_step.dependOn(&run_lattice_tests.step);
    const run_prompts_tests = b.addRunArtifact(prompts_tests);
    test_step.dependOn(&run_prompts_tests.step);
    const run_dm_tests = b.addRunArtifact(dm_tests);
    test_step.dependOn(&run_dm_tests.step);
    const run_loop_tests = b.addRunArtifact(loop_tests);
    test_step.dependOn(&run_loop_tests.step);
    const run_daemon_tests = b.addRunArtifact(daemon_tests);
    test_step.dependOn(&run_daemon_tests.step);
    const run_buffer_tests = b.addRunArtifact(buffer_tests);
    test_step.dependOn(&run_buffer_tests.step);
    const run_loom_tests = b.addRunArtifact(loom_tests);
    test_step.dependOn(&run_loom_tests.step);
    const run_aurora_tests = b.addRunArtifact(aurora_tests);
    test_step.dependOn(&run_aurora_tests.step);
    const run_text_renderer_tests = b.addRunArtifact(text_renderer_tests);
    test_step.dependOn(&run_text_renderer_tests.step);
    const run_lsp_tests = b.addRunArtifact(lsp_tests);
    test_step.dependOn(&run_lsp_tests.step);
    const run_editor_tests = b.addRunArtifact(editor_tests);
    test_step.dependOn(&run_editor_tests.step);
    const run_route_tests = b.addRunArtifact(route_tests);
    test_step.dependOn(&run_route_tests.step);
    const run_orchestrator_tests = b.addRunArtifact(orchestrator_tests);
    test_step.dependOn(&run_orchestrator_tests.step);
    const run_riscv_tests = b.addRunArtifact(riscv_tests);
    test_step.dependOn(&run_riscv_tests.step);
    const run_outputs_tests = b.addRunArtifact(outputs_tests);
    test_step.dependOn(&run_outputs_tests.step);

    const fuzz_004_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/004_fuzz.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const fuzz_004_step = b.step("fuzz-004", "Run 004 fuzz tests for RISC-V VM");
    fuzz_004_step.dependOn(&fuzz_004_tests.step);

    const fuzz_005_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/005_fuzz.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
                .{ .name = "sbi", .module = sbi_module },
            },
        }),
    });
    const fuzz_005_step = b.step("fuzz-005", "Run 005 fuzz tests for SBI + kernel syscall integration");
    fuzz_005_step.dependOn(&fuzz_005_tests.step);

    const fuzz_006_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/006_fuzz.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const fuzz_006_run = b.addRunArtifact(fuzz_006_tests);
    const fuzz_006_step = b.step("fuzz-006", "Run 006 fuzz tests for memory management foundation");
    fuzz_006_step.dependOn(&fuzz_006_run.step);

    const fuzz_003_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/003_fuzz.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ray", .module = ray_module },
            },
        }),
    });
    const run_fuzz_003_tests = b.addRunArtifact(fuzz_003_tests);
    test_step.dependOn(&run_fuzz_003_tests.step);
}
