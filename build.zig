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

    const zigimg_module = b.addModule("zigimg", .{
        .root_source_file = b.path("grainstore/github/zigimg/zigimg/zigimg.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Grain TLS implementation from grainstore (forked from ianic/tls.zig)
    const grain_tls_impl_module = b.addModule("grain_tls_impl", .{
        .root_source_file = b.path("grainstore/github/kae3g/grain-tls/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // TLS module (Grain TLS) - Simplified wrapper around grain_tls_impl
    const tls_module = b.addModule("tls", .{
        .root_source_file = b.path("src/grain_tls/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "grain_tls_impl", .module = grain_tls_impl_module },
        },
    });

    const graincard_exe = b.addExecutable(.{
        .name = "graincard",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/graincard.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigimg", .module = zigimg_module },
            },
        }),
    });
    b.installArtifact(graincard_exe);

    const graincard_run = b.addRunArtifact(graincard_exe);
    const graincard_step = b.step("graincard", "Run the Graincard Generator");
    graincard_step.dependOn(&graincard_run.step);
    if (b.args) |args| {
        graincard_run.addArgs(args);
    }

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
            .code_model = .medium,
        }),
    });
    kernel_exe.setLinkerScript(b.path("src/kernel/linker.ld"));
    kernel_exe.addAssemblyFile(b.path("src/kernel/entry.S"));
    const kernel_install = b.addInstallArtifact(kernel_exe, .{});
    const kernel_step = b.step("kernel-rv64", "Build Grain RISC-V kernel image");
    kernel_step.dependOn(&kernel_install.step);

    // ELF Parser module (for tests that need direct access).
    // ELF Parser module (for kernel and tests).
    const elf_parser_module = b.addModule("elf_parser", .{
        .root_source_file = b.path("src/kernel/elf_parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Basin Kernel module (syscall interface and kernel structures).
    // Note: basin_kernel.zig imports elf_parser.zig as a file (same directory).
    // Tests can import elf_parser as a module separately.
    const basin_kernel_module = b.addModule("basin_kernel", .{
        .root_source_file = b.path("src/kernel/basin_kernel.zig"),
        .target = target,
        .optimize = optimize,
    });

    // RISC-V SBI module (platform runtime services).
    // Why: Our own Grain Style SBI wrapper (inspired by CascadeOS/zig-sbi, MIT licensed).
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
            .{ .name = "basin_kernel", .module = basin_kernel_module },
        },
    });

    // Grainscript module
    // Grainscript module (used by grainscript tests).
    const grainscript_module = b.addModule("grainscript", .{
        .root_source_file = b.path("src/grainscript/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // grainscript_module is used by grain_terminal_module and grainscript tests

    // Grain Buffer module (for grain_terminal) - reuse if exists
    const grain_buffer_module = b.addModule("grain_buffer_terminal", .{
        .root_source_file = b.path("src/grain_buffer.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Events module for platform events (needed by window module)
    const events_module = b.addModule("events", .{
        .root_source_file = b.path("src/platform/events.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Window module (macos_tahoe, for grain_terminal) - use different name to avoid conflict
    const window_module_for_terminal = b.addModule("macos_window_terminal", .{
        .root_source_file = b.path("src/platform/macos_tahoe/window.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "events", .module = events_module },
        },
    });

    // Grain Terminal module
    const grain_terminal_module = b.addModule("grain_terminal", .{
        .root_source_file = b.path("src/grain_terminal/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "grain_buffer", .module = grain_buffer_module },
            .{ .name = "macos_window", .module = window_module_for_terminal },
            .{ .name = "grainscript", .module = grainscript_module },
        },
    });

    // Grain Skate module
    const grain_skate_module = b.addModule("grain_skate", .{
        .root_source_file = b.path("src/grain_skate/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "macos_window", .module = window_module_for_terminal },
            .{ .name = "events", .module = events_module },
        },
    });

    // Grain Field module
    const grain_field_module = b.addModule("grain_field", .{
        .root_source_file = b.path("src/grain_field/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Grain Silo module
    const grain_silo_module = b.addModule("grain_silo", .{
        .root_source_file = b.path("src/grain_silo/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Grain OS module
    const grain_os_module = b.addModule("grain_os", .{
        .root_source_file = b.path("src/grain_os/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "basin_kernel", .module = basin_kernel_module },
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

    // JIT Benchmark executable
    const benchmark_jit_exe = b.addExecutable(.{
        .name = "benchmark_jit",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kernel_vm/benchmark_jit.zig"),
            .target = target,
            .optimize = .ReleaseFast, // Benchmark should be optimized
            .imports = &.{
                .{ .name = "sbi", .module = sbi_module },
            },
        }),
    });
    const benchmark_jit_run = b.addRunArtifact(benchmark_jit_exe);
    const benchmark_jit_step = b.step("benchmark-jit", "Run JIT vs Interpreter benchmark");
    benchmark_jit_step.dependOn(&benchmark_jit_run.step);

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

    const ai_provider_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/aurora_ai_provider.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const glm46_provider_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/aurora_glm46_provider.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const ai_transforms_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/aurora_ai_transforms.zig"),
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

    // Grain Style: Print build progress for visibility.
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
            // Grain Style: Zig is strict by default - all safety checks enabled.
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
    const run_ai_provider_tests = b.addRunArtifact(ai_provider_tests);
    test_step.dependOn(&run_ai_provider_tests.step);
    const run_glm46_provider_tests = b.addRunArtifact(glm46_provider_tests);
    test_step.dependOn(&run_glm46_provider_tests.step);
    const run_ai_transforms_tests = b.addRunArtifact(ai_transforms_tests);
    test_step.dependOn(&run_ai_transforms_tests.step);
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

    const fuzz_007_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/007_fuzz.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const fuzz_007_run = b.addRunArtifact(fuzz_007_tests);
    const fuzz_007_step = b.step("fuzz-007", "Run 007 fuzz tests for file system foundation");
    fuzz_007_step.dependOn(&fuzz_007_run.step);

    const fuzz_006_simple_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/006_simple_at_commit.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const fuzz_006_simple_run = b.addRunArtifact(fuzz_006_simple_tests);
    const fuzz_006_simple_step = b.step("fuzz-006-simple", "Run simple 006 test at commit 0d618a3");
    fuzz_006_simple_step.dependOn(&fuzz_006_simple_run.step);

    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/011_integration_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const integration_run = b.addRunArtifact(integration_tests);
    const integration_step = b.step("integration-test", "Run integration tests for VM-kernel layer");
    integration_step.dependOn(&integration_run.step);

    // RISC-V64 userspace target (for compiling userspace programs).
    const userspace_target = std.Target.Query{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    };
    const userspace_resolved = b.resolveTargetQuery(userspace_target);

    // Userspace stdlib module (for userspace programs - must use userspace target).
    const userspace_stdlib_module = b.addModule("userspace_stdlib", .{
        .root_source_file = b.path("src/userspace/stdlib.zig"),
        .target = userspace_resolved,
        .optimize = optimize,
    });

    // Userspace args module (for argument parsing in utilities).
    const userspace_args_module = b.addModule("userspace_args", .{
        .root_source_file = b.path("src/userspace/utils/args.zig"),
        .target = userspace_resolved,
        .optimize = optimize,
    });

    // Hello World userspace executable (RISC-V64).
    const hello_world_exe = b.addExecutable(.{
        .name = "hello_world",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/hello_world.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
            },
        }),
    });
    hello_world_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const hello_world_install = b.addInstallArtifact(hello_world_exe, .{});
    const hello_world_step = b.step("hello-world", "Build Hello World userspace program for RISC-V64");
    hello_world_step.dependOn(&hello_world_install.step);

    // Framebuffer Demo userspace executable (RISC-V64).
    const fb_demo_exe = b.addExecutable(.{
        .name = "fb_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/fb_demo.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    fb_demo_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const fb_demo_install = b.addInstallArtifact(fb_demo_exe, .{});
    const fb_demo_step = b.step("fb-demo", "Build Framebuffer Demo userspace program for RISC-V64");
    fb_demo_step.dependOn(&fb_demo_install.step);

    const hello_world_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/012_hello_world_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const hello_world_tests_run = b.addRunArtifact(hello_world_tests);
    const hello_world_tests_step = b.step("hello-world-test", "Test Hello World program in VM");
    hello_world_tests_step.dependOn(&hello_world_tests_run.step);
    // Make hello-world-test depend on hello-world being built first.
    hello_world_tests_step.dependOn(&hello_world_install.step);

    // Framebuffer Demo tests.
    const fb_demo_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/013_fb_demo_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const fb_demo_tests_run = b.addRunArtifact(fb_demo_tests);
    const fb_demo_tests_step = b.step("fb-demo-test", "Test Framebuffer Demo program in VM");
    fb_demo_tests_step.dependOn(&fb_demo_tests_run.step);
    fb_demo_tests_step.dependOn(&fb_demo_install.step);

    // Kernel and VM tests
    // Framebuffer module for framebuffer tests
    const framebuffer_module = b.addModule("framebuffer", .{
        .root_source_file = b.path("src/kernel/framebuffer.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const framebuffer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/framebuffer_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
                .{ .name = "framebuffer", .module = framebuffer_module },
            },
        }),
    });
    const framebuffer_tests_run = b.addRunArtifact(framebuffer_tests);
    test_step.dependOn(&framebuffer_tests_run.step);

    const framebuffer_syscall_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/framebuffer_syscall_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
                .{ .name = "framebuffer", .module = framebuffer_module },
            },
        }),
    });
    const framebuffer_syscall_tests_run = b.addRunArtifact(framebuffer_syscall_tests);
    test_step.dependOn(&framebuffer_syscall_tests_run.step);

    const kernel_integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/014_kernel_integration_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
                .{ .name = "framebuffer", .module = framebuffer_module },
            },
        }),
    });
    const kernel_integration_tests_run = b.addRunArtifact(kernel_integration_tests);
    test_step.dependOn(&kernel_integration_tests_run.step);

    const dirty_region_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/015_dirty_region_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "framebuffer", .module = framebuffer_module },
            },
        }),
    });
    const dirty_region_tests_run = b.addRunArtifact(dirty_region_tests);
    test_step.dependOn(&dirty_region_tests_run.step);

    const error_handling_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/016_error_handling_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const error_handling_tests_run = b.addRunArtifact(error_handling_tests);
    test_step.dependOn(&error_handling_tests_run.step);

    const performance_monitoring_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/017_performance_monitoring_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const performance_monitoring_tests_run = b.addRunArtifact(performance_monitoring_tests);
    test_step.dependOn(&performance_monitoring_tests_run.step);

    const state_persistence_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/018_state_persistence_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const state_persistence_tests_run = b.addRunArtifact(state_persistence_tests);
    test_step.dependOn(&state_persistence_tests_run.step);

    const timer_driver_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/020_timer_driver_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const timer_driver_tests_run = b.addRunArtifact(timer_driver_tests);
    test_step.dependOn(&timer_driver_tests_run.step);

    const interrupt_controller_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/021_interrupt_controller_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const interrupt_controller_tests_run = b.addRunArtifact(interrupt_controller_tests);
    test_step.dependOn(&interrupt_controller_tests_run.step);

    const process_scheduler_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/022_process_scheduler_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const process_scheduler_tests_run = b.addRunArtifact(process_scheduler_tests);
    test_step.dependOn(&process_scheduler_tests_run.step);

    const ipc_channel_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/023_ipc_channel_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const ipc_channel_tests_run = b.addRunArtifact(ipc_channel_tests);
    test_step.dependOn(&ipc_channel_tests_run.step);

    const process_elf_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/024_process_elf_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const process_elf_tests_run = b.addRunArtifact(process_elf_tests);
    test_step.dependOn(&process_elf_tests_run.step);

    const storage_filesystem_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/025_storage_filesystem_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const storage_filesystem_tests_run = b.addRunArtifact(storage_filesystem_tests);
    test_step.dependOn(&storage_filesystem_tests_run.step);

    const keyboard_mouse_driver_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/026_keyboard_mouse_driver_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const keyboard_mouse_driver_tests_run = b.addRunArtifact(keyboard_mouse_driver_tests);
    test_step.dependOn(&keyboard_mouse_driver_tests_run.step);

    // Memory module for memory allocator tests
    const memory_module = b.addModule("memory", .{
        .root_source_file = b.path("src/kernel/memory.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Window module for window tests (defined before use in fuzz_003_tests)
    const window_module = b.addModule("window", .{
        .root_source_file = b.path("src/platform/macos_tahoe/window.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "events", .module = events_module },
        },
    });
    
    const memory_allocator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/027_memory_allocator_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
                .{ .name = "memory", .module = memory_module },
            },
        }),
    });
    const memory_allocator_tests_run = b.addRunArtifact(memory_allocator_tests);
    test_step.dependOn(&memory_allocator_tests_run.step);

    // Boot module for boot sequence tests (defined before use, after basin_kernel)
    // Note: boot.zig is imported by basin_kernel.zig, so we can't create a separate module
    // Instead, we'll use relative imports in the test
    const boot_sequence_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/028_boot_sequence_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const boot_sequence_tests_run = b.addRunArtifact(boot_sequence_tests);
    test_step.dependOn(&boot_sequence_tests_run.step);

    const trap_handler_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/029_trap_handler_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const trap_handler_tests_run = b.addRunArtifact(trap_handler_tests);
    test_step.dependOn(&trap_handler_tests_run.step);

    const process_execution_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/041_process_execution_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const process_execution_tests_run = b.addRunArtifact(process_execution_tests);
    test_step.dependOn(&process_execution_tests_run.step);

    const scheduler_integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/042_scheduler_integration_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const scheduler_integration_tests_run = b.addRunArtifact(scheduler_integration_tests);
    test_step.dependOn(&scheduler_integration_tests_run.step);

    const program_segment_loading_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/048_program_segment_loading_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
                .{ .name = "elf_parser", .module = elf_parser_module },
            },
        }),
    });
    const program_segment_loading_tests_run = b.addRunArtifact(program_segment_loading_tests);
    test_step.dependOn(&program_segment_loading_tests_run.step);

    const resource_cleanup_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/049_resource_cleanup_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const resource_cleanup_tests_run = b.addRunArtifact(resource_cleanup_tests);
    test_step.dependOn(&resource_cleanup_tests_run.step);

    const channel_send_recv_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/050_channel_send_recv_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const channel_send_recv_tests_run = b.addRunArtifact(channel_send_recv_tests);
    test_step.dependOn(&channel_send_recv_tests_run.step);

    const comprehensive_userspace_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/051_comprehensive_userspace_execution_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const comprehensive_userspace_tests_run = b.addRunArtifact(comprehensive_userspace_tests);
    test_step.dependOn(&comprehensive_userspace_tests_run.step);

    const terminal_kernel_integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/047_terminal_kernel_integration_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const terminal_kernel_integration_tests_run = b.addRunArtifact(terminal_kernel_integration_tests);
    test_step.dependOn(&terminal_kernel_integration_tests_run.step);

    // Grain Terminal tests
    const grain_terminal_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/045_grain_terminal_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_terminal", .module = grain_terminal_module },
            },
        }),
    });
    const grain_terminal_tests_run = b.addRunArtifact(grain_terminal_tests);
    test_step.dependOn(&grain_terminal_tests_run.step);

    const grain_terminal_ui_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/046_grain_terminal_ui_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_terminal", .module = grain_terminal_module },
                .{ .name = "grain_buffer", .module = grain_buffer_module },
                .{ .name = "macos_window", .module = window_module_for_terminal },
            },
        }),
    });
    const grain_terminal_ui_tests_run = b.addRunArtifact(grain_terminal_ui_tests);
    test_step.dependOn(&grain_terminal_ui_tests_run.step);

    const grain_terminal_advanced_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/047_grain_terminal_advanced_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_terminal", .module = grain_terminal_module },
            },
        }),
    });
    const grain_terminal_advanced_tests_run = b.addRunArtifact(grain_terminal_advanced_tests);
    test_step.dependOn(&grain_terminal_advanced_tests_run.step);

    const grain_skate_core_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/048_grain_skate_core_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_skate", .module = grain_skate_module },
            },
        }),
    });
    const grain_skate_core_tests_run = b.addRunArtifact(grain_skate_core_tests);
    test_step.dependOn(&grain_skate_core_tests_run.step);

    const grain_skate_social_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/051_grain_skate_social_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_skate", .module = grain_skate_module },
            },
        }),
    });
    const grain_skate_social_tests_run = b.addRunArtifact(grain_skate_social_tests);
    test_step.dependOn(&grain_skate_social_tests_run.step);

    const grain_skate_graph_viz_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/054_grain_skate_graph_viz_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_skate", .module = grain_skate_module },
            },
        }),
    });
    const grain_skate_graph_viz_tests_run = b.addRunArtifact(grain_skate_graph_viz_tests);
    test_step.dependOn(&grain_skate_graph_viz_tests_run.step);

    const grain_skate_modal_editor_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/058_grain_skate_modal_editor_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_skate", .module = grain_skate_module },
                .{ .name = "events", .module = events_module },
            },
        }),
    });
    const grain_skate_modal_editor_tests_run = b.addRunArtifact(grain_skate_modal_editor_tests);
    test_step.dependOn(&grain_skate_modal_editor_tests_run.step);

    const grain_skate_app_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/055_grain_skate_app_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_skate", .module = grain_skate_module },
            },
        }),
    });
    const grain_skate_app_tests_run = b.addRunArtifact(grain_skate_app_tests);
    test_step.dependOn(&grain_skate_app_tests_run.step);

    const grain_skate_graph_renderer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/056_grain_skate_graph_renderer_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_skate", .module = grain_skate_module },
            },
        }),
    });
    const grain_skate_graph_renderer_tests_run = b.addRunArtifact(grain_skate_graph_renderer_tests);
    test_step.dependOn(&grain_skate_graph_renderer_tests_run.step);

    const grain_skate_window_graph_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/057_grain_skate_window_graph_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_skate", .module = grain_skate_module },
            },
        }),
    });
    const grain_skate_window_graph_tests_run = b.addRunArtifact(grain_skate_window_graph_tests);
    test_step.dependOn(&grain_skate_window_graph_tests_run.step);

    const grain_field_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/049_grain_field_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_field", .module = grain_field_module },
            },
        }),
    });
    const grain_field_tests_run = b.addRunArtifact(grain_field_tests);
    test_step.dependOn(&grain_field_tests_run.step);

    const grain_silo_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/050_grain_silo_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_silo", .module = grain_silo_module },
            },
        }),
    });
    const grain_silo_tests_run = b.addRunArtifact(grain_silo_tests);
    test_step.dependOn(&grain_silo_tests_run.step);

    const grain_os_compositor_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/052_grain_os_compositor_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_tiling_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/053_grain_os_tiling_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_compositor_tests_run = b.addRunArtifact(grain_os_compositor_tests);
    test_step.dependOn(&grain_os_compositor_tests_run.step);
    const grain_os_tiling_tests_run = b.addRunArtifact(grain_os_tiling_tests);
    test_step.dependOn(&grain_os_tiling_tests_run.step);
    const grain_os_layout_generator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/056_grain_os_layout_generator_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_layout_generator_tests_run = b.addRunArtifact(grain_os_layout_generator_tests);
    test_step.dependOn(&grain_os_layout_generator_tests_run.step);
    const grain_os_workspace_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/057_grain_os_workspace_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_workspace_tests_run = b.addRunArtifact(grain_os_workspace_tests);
    test_step.dependOn(&grain_os_workspace_tests_run.step);
    const kernel_boot_jit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/058_kernel_boot_jit_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
                .{ .name = "basin_kernel", .module = basin_kernel_module },
            },
        }),
    });
    const kernel_boot_jit_tests_run = b.addRunArtifact(kernel_boot_jit_tests);
    test_step.dependOn(&kernel_boot_jit_tests_run.step);
    const jit_performance_timing_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/059_jit_performance_timing_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const jit_performance_timing_tests_run = b.addRunArtifact(jit_performance_timing_tests);
    test_step.dependOn(&jit_performance_timing_tests_run.step);
    const jit_hot_path_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/060_jit_hot_path_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const jit_hot_path_tests_run = b.addRunArtifact(jit_hot_path_tests);
    test_step.dependOn(&jit_hot_path_tests_run.step);
    const jit_code_size_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/061_jit_code_size_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const jit_code_size_tests_run = b.addRunArtifact(jit_code_size_tests);
    test_step.dependOn(&jit_code_size_tests_run.step);
    const vm_memory_stats_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/062_vm_memory_stats_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const vm_memory_stats_tests_run = b.addRunArtifact(vm_memory_stats_tests);
    test_step.dependOn(&vm_memory_stats_tests_run.step);
    const vm_instruction_stats_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/063_vm_instruction_stats_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const vm_instruction_stats_tests_run = b.addRunArtifact(vm_instruction_stats_tests);
    test_step.dependOn(&vm_instruction_stats_tests_run.step);
    const vm_syscall_stats_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/064_vm_syscall_stats_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const vm_syscall_stats_tests_run = b.addRunArtifact(vm_syscall_stats_tests);
    test_step.dependOn(&vm_syscall_stats_tests_run.step);
    const vm_execution_flow_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/065_vm_execution_flow_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const vm_execution_flow_tests_run = b.addRunArtifact(vm_execution_flow_tests);
    test_step.dependOn(&vm_execution_flow_tests_run.step);
    const vm_stats_aggregator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/066_vm_stats_aggregator_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const vm_stats_aggregator_tests_run = b.addRunArtifact(vm_stats_aggregator_tests);
    test_step.dependOn(&vm_stats_aggregator_tests_run.step);
    const vm_branch_stats_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/067_vm_branch_stats_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const vm_branch_stats_tests_run = b.addRunArtifact(vm_branch_stats_tests);
    test_step.dependOn(&vm_branch_stats_tests_run.step);

    const vm_register_stats_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/068_vm_register_stats_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const vm_register_stats_tests_run = b.addRunArtifact(vm_register_stats_tests);
    test_step.dependOn(&vm_register_stats_tests_run.step);

    const vm_instruction_perf_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/069_vm_instruction_perf_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kernel_vm", .module = kernel_vm_module },
            },
        }),
    });
    const vm_instruction_perf_tests_run = b.addRunArtifact(vm_instruction_perf_tests);
    test_step.dependOn(&vm_instruction_perf_tests_run.step);

    const grain_os_layout_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/053_grain_os_layout_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_layout_tests_run = b.addRunArtifact(grain_os_layout_tests);
    test_step.dependOn(&grain_os_layout_tests_run.step);

    const grain_os_framebuffer_renderer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/054_grain_os_framebuffer_renderer_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_framebuffer_renderer_tests_run = b.addRunArtifact(grain_os_framebuffer_renderer_tests);
    test_step.dependOn(&grain_os_framebuffer_renderer_tests_run.step);

    const grain_os_input_handler_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/055_grain_os_input_handler_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_input_handler_tests_run = b.addRunArtifact(grain_os_input_handler_tests);
    test_step.dependOn(&grain_os_input_handler_tests_run.step);

    const grain_os_input_routing_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/056_grain_os_input_routing_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_input_routing_tests_run = b.addRunArtifact(grain_os_input_routing_tests);
    test_step.dependOn(&grain_os_input_routing_tests_run.step);

    const grain_os_window_decorations_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/058_grain_os_window_decorations_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_decorations_tests_run = b.addRunArtifact(grain_os_window_decorations_tests);
    test_step.dependOn(&grain_os_window_decorations_tests_run.step);

    const grain_os_keyboard_shortcuts_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/059_grain_os_keyboard_shortcuts_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_keyboard_shortcuts_tests_run = b.addRunArtifact(grain_os_keyboard_shortcuts_tests);
    test_step.dependOn(&grain_os_keyboard_shortcuts_tests_run.step);

    const grain_os_runtime_config_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/060_grain_os_runtime_config_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_runtime_config_tests_run = b.addRunArtifact(grain_os_runtime_config_tests);
    test_step.dependOn(&grain_os_runtime_config_tests_run.step);

    const grain_os_desktop_shell_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/061_grain_os_desktop_shell_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_desktop_shell_tests_run = b.addRunArtifact(grain_os_desktop_shell_tests);
    test_step.dependOn(&grain_os_desktop_shell_tests_run.step);

    const grain_os_application_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/062_grain_os_application_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_application_tests_run = b.addRunArtifact(grain_os_application_tests);
    test_step.dependOn(&grain_os_application_tests_run.step);

    const grain_os_launcher_integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/063_grain_os_launcher_integration_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_launcher_integration_tests_run = b.addRunArtifact(grain_os_launcher_integration_tests);
    test_step.dependOn(&grain_os_launcher_integration_tests_run.step);

    const grain_os_window_resize_drag_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/064_grain_os_window_resize_drag_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_resize_drag_tests_run = b.addRunArtifact(grain_os_window_resize_drag_tests);
    test_step.dependOn(&grain_os_window_resize_drag_tests_run.step);

    const grain_os_window_snapping_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/065_grain_os_window_snapping_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_snapping_tests_run = b.addRunArtifact(grain_os_window_snapping_tests);
    test_step.dependOn(&grain_os_window_snapping_tests_run.step);

    const grain_os_window_switching_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/066_grain_os_window_switching_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_switching_tests_run = b.addRunArtifact(grain_os_window_switching_tests);
    test_step.dependOn(&grain_os_window_switching_tests_run.step);

    const grain_os_window_state_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/067_grain_os_window_state_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_state_tests_run = b.addRunArtifact(grain_os_window_state_tests);
    test_step.dependOn(&grain_os_window_state_tests_run.step);

    const grain_os_window_preview_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/068_grain_os_window_preview_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_preview_tests_run = b.addRunArtifact(grain_os_window_preview_tests);
    test_step.dependOn(&grain_os_window_preview_tests_run.step);

    const grain_os_window_visual_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/069_grain_os_window_visual_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_visual_tests_run = b.addRunArtifact(grain_os_window_visual_tests);
    test_step.dependOn(&grain_os_window_visual_tests_run.step);

    const grain_os_window_stacking_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/070_grain_os_window_stacking_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_stacking_tests_run = b.addRunArtifact(grain_os_window_stacking_tests);
    test_step.dependOn(&grain_os_window_stacking_tests_run.step);

    const grain_os_window_opacity_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/071_grain_os_window_opacity_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_opacity_tests_run = b.addRunArtifact(grain_os_window_opacity_tests);
    test_step.dependOn(&grain_os_window_opacity_tests_run.step);

    const grain_os_window_animation_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/072_grain_os_window_animation_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_animation_tests_run = b.addRunArtifact(grain_os_window_animation_tests);
    test_step.dependOn(&grain_os_window_animation_tests_run.step);

    const grain_os_window_constraints_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/074_grain_os_window_constraints_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_constraints_tests_run = b.addRunArtifact(grain_os_window_constraints_tests);
    test_step.dependOn(&grain_os_window_constraints_tests_run.step);

    const grain_os_window_grouping_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/075_grain_os_window_grouping_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_grouping_tests_run = b.addRunArtifact(grain_os_window_grouping_tests);
    test_step.dependOn(&grain_os_window_grouping_tests_run.step);

    const grain_os_window_focus_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/076_grain_os_window_focus_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "grain_os", .module = grain_os_module },
            },
        }),
    });
    const grain_os_window_focus_tests_run = b.addRunArtifact(grain_os_window_focus_tests);
    test_step.dependOn(&grain_os_window_focus_tests_run.step);

    // RISC-V Logo Display Program
    const riscv_logo_exe = b.addExecutable(.{
        .name = "riscv_logo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/riscv_logo.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
            },
        }),
    });
    riscv_logo_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const riscv_logo_install = b.addInstallArtifact(riscv_logo_exe, .{});
    const riscv_logo_step = b.step("riscv-logo", "Build RISC-V logo display program for RISC-V64");
    riscv_logo_step.dependOn(&riscv_logo_install.step);

    // Build-essential utilities: cat
    const cat_exe = b.addExecutable(.{
        .name = "cat",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/core/cat.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    cat_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const cat_install = b.addInstallArtifact(cat_exe, .{});
    const cat_step = b.step("cat", "Build cat utility for RISC-V64");
    cat_step.dependOn(&cat_install.step);

    // Build-essential utilities: echo
    const echo_exe = b.addExecutable(.{
        .name = "echo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/core/echo.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    echo_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const echo_install = b.addInstallArtifact(echo_exe, .{});
    const echo_step = b.step("echo", "Build echo utility for RISC-V64");
    echo_step.dependOn(&echo_install.step);

    // Build-essential utilities: ls
    const ls_exe = b.addExecutable(.{
        .name = "ls",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/core/ls.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
            },
        }),
    });
    ls_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const ls_install = b.addInstallArtifact(ls_exe, .{});
    const ls_step = b.step("ls", "Build ls utility for RISC-V64");
    ls_step.dependOn(&ls_install.step);

    // Build-essential utilities: mkdir
    const mkdir_exe = b.addExecutable(.{
        .name = "mkdir",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/core/mkdir.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    mkdir_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const mkdir_install = b.addInstallArtifact(mkdir_exe, .{});
    const mkdir_step = b.step("mkdir", "Build mkdir utility for RISC-V64");
    mkdir_step.dependOn(&mkdir_install.step);

    // Build-essential utilities: rm
    const rm_exe = b.addExecutable(.{
        .name = "rm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/core/rm.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    rm_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const rm_install = b.addInstallArtifact(rm_exe, .{});
    const rm_step = b.step("rm", "Build rm utility for RISC-V64");
    rm_step.dependOn(&rm_install.step);

    // Build-essential utilities: cp
    const cp_exe = b.addExecutable(.{
        .name = "cp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/core/cp.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    cp_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const cp_install = b.addInstallArtifact(cp_exe, .{});
    const cp_step = b.step("cp", "Build cp utility for RISC-V64");
    cp_step.dependOn(&cp_install.step);

    // Build-essential utilities: mv
    const mv_exe = b.addExecutable(.{
        .name = "mv",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/core/mv.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    mv_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const mv_install = b.addInstallArtifact(mv_exe, .{});
    const mv_step = b.step("mv", "Build mv utility for RISC-V64");
    mv_step.dependOn(&mv_install.step);

    // Build-essential utilities: grep
    const grep_exe = b.addExecutable(.{
        .name = "grep",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/text/grep.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
            },
        }),
    });
    grep_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const grep_install = b.addInstallArtifact(grep_exe, .{});
    const grep_step = b.step("grep", "Build grep utility for RISC-V64");
    grep_step.dependOn(&grep_install.step);

    // Build-essential utilities: sed
    const sed_exe = b.addExecutable(.{
        .name = "sed",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/text/sed.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    sed_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const sed_install = b.addInstallArtifact(sed_exe, .{});
    const sed_step = b.step("sed", "Build sed utility for RISC-V64");
    sed_step.dependOn(&sed_install.step);

    // Build-essential utilities: awk
    const awk_exe = b.addExecutable(.{
        .name = "awk",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/utils/text/awk.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    awk_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const awk_install = b.addInstallArtifact(awk_exe, .{});
    const awk_step = b.step("awk", "Build awk utility for RISC-V64");
    awk_step.dependOn(&awk_install.step);

    // Build-essential utilities: cc (C compiler wrapper)
    const cc_exe = b.addExecutable(.{
        .name = "cc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/build-tools/cc.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    cc_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const cc_install = b.addInstallArtifact(cc_exe, .{});
    const cc_step = b.step("cc", "Build cc utility for RISC-V64");
    cc_step.dependOn(&cc_install.step);

    // Build-essential utilities: ld (linker wrapper)
    const ld_exe = b.addExecutable(.{
        .name = "ld",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/build-tools/ld.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    ld_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const ld_install = b.addInstallArtifact(ld_exe, .{});
    const ld_step = b.step("ld", "Build ld utility for RISC-V64");
    ld_step.dependOn(&ld_install.step);

    // Build-essential utilities: ar (archive utility)
    const ar_exe = b.addExecutable(.{
        .name = "ar",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/build-tools/ar.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    ar_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const ar_install = b.addInstallArtifact(ar_exe, .{});
    const ar_step = b.step("ar", "Build ar utility for RISC-V64");
    ar_step.dependOn(&ar_install.step);

    // Build-essential utilities: make (build automation)
    const make_exe = b.addExecutable(.{
        .name = "make",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/build-tools/make.zig"),
            .target = userspace_resolved,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "userspace_stdlib", .module = userspace_stdlib_module },
                .{ .name = "userspace_args", .module = userspace_args_module },
            },
        }),
    });
    make_exe.setLinkerScript(b.path("linker_scripts/userspace.ld"));
    const make_install = b.addInstallArtifact(make_exe, .{});
    const make_step = b.step("make", "Build make utility for RISC-V64");
    make_step.dependOn(&make_install.step);

    // Build-essential utilities: build all
    const build_essential_step = b.step("build-essential", "Build all build-essential utilities");
    build_essential_step.dependOn(&cat_install.step);
    build_essential_step.dependOn(&echo_install.step);
    build_essential_step.dependOn(&ls_install.step);
    build_essential_step.dependOn(&mkdir_install.step);
    build_essential_step.dependOn(&rm_install.step);
    build_essential_step.dependOn(&cp_install.step);
    build_essential_step.dependOn(&mv_install.step);
    build_essential_step.dependOn(&grep_install.step);
    build_essential_step.dependOn(&sed_install.step);
    build_essential_step.dependOn(&awk_install.step);
    build_essential_step.dependOn(&cc_install.step);
    build_essential_step.dependOn(&ld_install.step);
    build_essential_step.dependOn(&ar_install.step);
    build_essential_step.dependOn(&make_install.step);

    // Grainscape Browser (native browser for Grain OS)
    const grainscape_exe = b.addExecutable(.{
        .name = "grainscape",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/grainscape/main.zig"),
            .target = target, // Host target for now
            .optimize = optimize,
        }),
    });
    const grainscape_install = b.addInstallArtifact(grainscape_exe, .{});
    const grainscape_step = b.step("grainscape", "Build and run Grainscape browser");
    const run_grainscape = b.addRunArtifact(grainscape_exe);
    grainscape_step.dependOn(&run_grainscape.step);
    run_grainscape.step.dependOn(&grainscape_install.step);

    // Grainscape TLS Demo (test TLS connectivity)
    const grainscape_tls_demo_exe = b.addExecutable(.{
        .name = "grainscape-tls-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/userspace/grainscape/tls_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "tls", .module = tls_module },
            },
        }),
    });
    const grainscape_tls_demo_install = b.addInstallArtifact(grainscape_tls_demo_exe, .{});
    const grainscape_tls_demo_step = b.step("grainscape-tls-demo", "Build and run Grainscape TLS demo");
    const run_grainscape_tls_demo = b.addRunArtifact(grainscape_tls_demo_exe);
    grainscape_tls_demo_step.dependOn(&run_grainscape_tls_demo.step);
    run_grainscape_tls_demo.step.dependOn(&grainscape_tls_demo_install.step);



    const fuzz_003_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/003_fuzz.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ray", .module = ray_module },
                .{ .name = "window", .module = window_module },
            },
        }),
    });
    const run_fuzz_003_tests = b.addRunArtifact(fuzz_003_tests);
    test_step.dependOn(&run_fuzz_003_tests.step);
}
