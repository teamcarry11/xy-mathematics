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
    const run_route_tests = b.addRunArtifact(route_tests);
    test_step.dependOn(&run_route_tests.step);
    const run_orchestrator_tests = b.addRunArtifact(orchestrator_tests);
    test_step.dependOn(&run_orchestrator_tests.step);
    const run_riscv_tests = b.addRunArtifact(riscv_tests);
    test_step.dependOn(&run_riscv_tests.step);
    const run_outputs_tests = b.addRunArtifact(outputs_tests);
    test_step.dependOn(&run_outputs_tests.step);
}
