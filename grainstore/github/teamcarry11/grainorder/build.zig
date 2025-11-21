const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // grainorder library
    _ = b.addModule("grainorder", .{
        .root_source_file = b.path("src/grainorder.zig"),
        .target = target,
        .optimize = optimize,
    });

    // demo executable (temporarily disabled - API issue with Zig 0.15.2)
    // const demo_root_mod = b.createModule(.{
    //     .root_source_file = b.path("src/demo.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // demo_root_mod.addImport("grainorder", grainorder);
    // const demo = b.addExecutable(.{
    //     .name = "grainorder-demo",
    //     .root_module = demo_root_mod,
    // });
    //
    // b.installArtifact(demo);
    //
    // const run_demo = b.addRunArtifact(demo);
    // run_demo.step.dependOn(b.getInstallStep());
    //
    // const run_step = b.step("run", "Run the demo");
    // run_step.dependOn(&run_demo.step);

    // tests
    const test_root_mod = b.createModule(.{
        .root_source_file = b.path("src/grainorder.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tests = b.addTest(.{
        .root_module = test_root_mod,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

