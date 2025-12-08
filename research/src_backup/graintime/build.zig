const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the graintime module
    const graintime_mod = b.addModule("graintime", .{
        .root_source_file = b.path("src/graintime.zig"),
    });

    // Create test root module
    const test_root_mod = b.createModule(.{
        .root_source_file = b.path("src/graintime.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create test executable
    const tests = b.addTest(.{
        .root_module = test_root_mod,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run graintime tests");
    test_step.dependOn(&run_tests.step);

    _ = graintime_mod;
}

